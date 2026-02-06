// WebSocket 压力测试
// 测试实时消息、连接稳定性、并发连接数等

import { check, sleep, group } from 'k6';
import ws from 'k6/ws';
import { Counter, Rate, Trend, Gauge } from 'k6/metrics';
import { randomIntBetween, randomString } from 'https://jslib.k6.io/k6-utils/1.4.0/index.js';
import { env, thresholds, getLoadProfile, testData } from '../config.js';
import {
  generateUser,
  registerUser,
  loginUser,
  generateMessage,
  parseJson,
  wsConnections,
  wsReconnects,
  messagesSent,
  messagesReceived,
} from '../lib/helpers.js';

// 自定义指标
const wsConnectDuration = new Trend('ws_connect_duration');
const wsMessageLatency = new Trend('ws_message_latency');
const wsConnectionErrors = new Counter('ws_connection_errors');
const wsPingLatency = new Trend('ws_ping_latency');
const wsMessagesInFlight = new Gauge('ws_messages_in_flight');
const wsSessionDuration = new Trend('ws_session_duration');

// 测试选项
export const options = {
  stages: getLoadProfile('stress').stages,
  thresholds: {
    ...thresholds,
    'ws_connect_duration': ['p(95)<500', 'p(99)<1000'],
    'ws_message_latency': ['p(95)<100', 'p(99)<200'],
    'ws_connection_errors': ['count<10'],
    'ws_session_duration': ['avg>30000'],
  },
  tags: {
    testType: 'websocket',
    environment: __ENV.TARGET_ENV || 'local',
  },
};

// 初始化
export function setup() {
  console.log('Setting up WebSocket load test...');
  
  const users = [];
  const numUsers = Math.min(testData.virtualUsers, 100);
  
  // 创建测试用户
  for (let i = 0; i < numUsers; i++) {
    const user = generateUser(i);
    registerUser(user);
    
    const loginResult = loginUser(user.username, user.password);
    if (loginResult.success) {
      users.push({
        ...user,
        token: loginResult.token,
      });
    }
    
    sleep(0.1);
  }
  
  console.log(`Created ${users.length} test users for WebSocket test`);
  return { users };
}

// 主测试函数
export default function(data) {
  const { users } = data;
  
  if (users.length === 0) {
    console.log('No users available');
    return;
  }
  
  const userIndex = __VU % users.length;
  const user = users[userIndex];
  
  // WebSocket 连接测试
  testWebSocketConnection(user);
}

// WebSocket 连接测试
function testWebSocketConnection(user) {
  const wsUrl = `${env.wsUrl}/api/v1/ws?token=${user.token}`;
  const sessionStart = Date.now();
  let messagesInFlight = 0;
  const pendingMessages = new Map();
  
  const response = ws.connect(wsUrl, {
    headers: {
      'Origin': env.baseUrl,
    },
  }, function(socket) {
    wsConnections.add(1);
    
    // 连接成功
    socket.on('open', function() {
      const connectTime = Date.now() - sessionStart;
      wsConnectDuration.add(connectTime);
      
      console.log(`WebSocket connected in ${connectTime}ms`);
      
      // 发送认证消息
      socket.send(JSON.stringify({
        type: 'auth',
        data: {
          token: user.token,
        },
      }));
    });
    
    // 接收消息
    socket.on('message', function(message) {
      try {
        const data = JSON.parse(message);
        
        switch (data.type) {
          case 'auth_success':
            console.log('WebSocket authenticated');
            // 开始发送测试消息
            startMessageFlow(socket, pendingMessages);
            break;
            
          case 'message':
            handleIncomingMessage(data, pendingMessages);
            messagesReceived.add(1);
            break;
            
          case 'ack':
            handleMessageAck(data, pendingMessages);
            break;
            
          case 'pong':
            handlePong(data);
            break;
            
          case 'error':
            console.log(`WebSocket error: ${data.error}`);
            wsConnectionErrors.add(1);
            break;
            
          default:
            // 其他消息类型
            break;
        }
      } catch (e) {
        console.log(`Failed to parse message: ${e.message}`);
      }
    });
    
    // 连接关闭
    socket.on('close', function() {
      wsConnections.add(-1);
      wsSessionDuration.add(Date.now() - sessionStart);
    });
    
    // 连接错误
    socket.on('error', function(e) {
      wsConnectionErrors.add(1);
      console.log(`WebSocket error: ${e.error()}`);
    });
    
    // 定时发送 ping
    socket.setInterval(function() {
      sendPing(socket);
    }, 10000);
    
    // 定时发送消息
    socket.setInterval(function() {
      sendTestMessage(socket, pendingMessages);
    }, randomIntBetween(1000, 3000));
    
    // 保持连接一段时间
    socket.setTimeout(function() {
      console.log('Closing WebSocket connection');
      socket.close();
    }, randomIntBetween(30000, 60000));
  });
  
  check(response, {
    'WebSocket connection established': (r) => r && r.status === 101,
  });
}

// 开始消息流
function startMessageFlow(socket, pendingMessages) {
  // 订阅消息通道
  socket.send(JSON.stringify({
    type: 'subscribe',
    data: {
      channels: ['messages', 'presence', 'typing'],
    },
  }));
  
  // 加入测试房间
  socket.send(JSON.stringify({
    type: 'join_room',
    data: {
      room_id: 'load-test-room',
    },
  }));
}

// 发送测试消息
function sendTestMessage(socket, pendingMessages) {
  const messageId = `msg-${Date.now()}-${randomString(8)}`;
  const content = generateMessage(10, 200);
  
  const message = {
    type: 'message',
    data: {
      id: messageId,
      room_id: 'load-test-room',
      content: content,
      timestamp: Date.now(),
    },
  };
  
  // 记录发送时间用于计算延迟
  pendingMessages.set(messageId, Date.now());
  wsMessagesInFlight.add(1);
  
  socket.send(JSON.stringify(message));
  messagesSent.add(1);
}

// 处理接收消息
function handleIncomingMessage(data, pendingMessages) {
  if (data.data && data.data.id) {
    const sentTime = pendingMessages.get(data.data.id);
    if (sentTime) {
      const latency = Date.now() - sentTime;
      wsMessageLatency.add(latency);
      pendingMessages.delete(data.data.id);
      wsMessagesInFlight.add(-1);
    }
  }
}

// 处理消息确认
function handleMessageAck(data, pendingMessages) {
  if (data.data && data.data.message_id) {
    const sentTime = pendingMessages.get(data.data.message_id);
    if (sentTime) {
      const latency = Date.now() - sentTime;
      wsMessageLatency.add(latency);
      pendingMessages.delete(data.data.message_id);
      wsMessagesInFlight.add(-1);
    }
  }
}

// 发送 ping
function sendPing(socket) {
  const pingTime = Date.now();
  socket.send(JSON.stringify({
    type: 'ping',
    data: {
      timestamp: pingTime,
    },
  }));
}

// 处理 pong
function handlePong(data) {
  if (data.data && data.data.timestamp) {
    const latency = Date.now() - data.data.timestamp;
    wsPingLatency.add(latency);
  }
}

// 清理
export function teardown(data) {
  console.log('WebSocket load test completed');
}
