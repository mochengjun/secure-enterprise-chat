// 聊天接口负载测试
// 测试房间管理、消息发送、消息查询等接口

import { check, sleep, group } from 'k6';
import http from 'k6/http';
import { Counter, Rate, Trend, Gauge } from 'k6/metrics';
import { randomIntBetween } from 'https://jslib.k6.io/k6-utils/1.4.0/index.js';
import { env, thresholds, getLoadProfile, testData } from '../config.js';
import {
  getHeaders,
  generateUser,
  registerUser,
  loginUser,
  generateMessage,
  think,
  parseJson,
  apiCall,
  apiErrors,
  messagesSent,
  messagesReceived,
} from '../lib/helpers.js';

// 自定义指标
const roomsCreated = new Counter('rooms_created');
const roomsJoined = new Counter('rooms_joined');
const messageSendDuration = new Trend('message_send_duration');
const messageQueryDuration = new Trend('message_query_duration');
const activeRooms = new Gauge('active_rooms');
const membersPerRoom = new Gauge('members_per_room');

// 测试选项
export const options = {
  stages: getLoadProfile('load').stages,
  thresholds: {
    ...thresholds,
    'message_send_duration': ['p(95)<200', 'p(99)<500'],
    'message_query_duration': ['p(95)<300', 'p(99)<600'],
    'rooms_created': ['count>0'],
    'http_req_duration{endpoint:chat}': ['p(95)<300'],
  },
  tags: {
    testType: 'chat',
    environment: __ENV.TARGET_ENV || 'local',
  },
};

// 测试数据
const testRooms = [];

// 初始化
export function setup() {
  console.log('Setting up chat load test...');
  
  const users = [];
  const rooms = [];
  const numUsers = Math.min(testData.virtualUsers, 50);
  
  // 创建测试用户并登录
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
  
  console.log(`Created ${users.length} test users`);
  
  // 创建测试房间
  if (users.length > 0) {
    const numRooms = Math.ceil(users.length / 5); // 每5个用户一个房间
    
    for (let i = 0; i < numRooms; i++) {
      const creator = users[i % users.length];
      const room = createRoom(creator.token, `LoadTest Room ${i}`);
      
      if (room) {
        rooms.push(room);
        
        // 添加一些成员
        const membersToAdd = users.slice(i * 5, (i + 1) * 5);
        for (const member of membersToAdd) {
          if (member.token !== creator.token) {
            joinRoom(member.token, room.id);
            sleep(0.05);
          }
        }
      }
      
      sleep(0.1);
    }
    
    console.log(`Created ${rooms.length} test rooms`);
  }
  
  return { users, rooms };
}

// 创建房间辅助函数
function createRoom(token, name) {
  const payload = JSON.stringify({
    name: name,
    type: 'group',
    description: 'Load test room',
    settings: {
      auto_delete_hours: 72,
      max_members: 100,
    },
  });
  
  const response = http.post(
    `${env.baseUrl}/api/v1/chat/rooms`,
    payload,
    { headers: getHeaders(token), tags: { endpoint: 'chat' } }
  );
  
  if (response.status === 200 || response.status === 201) {
    const body = parseJson(response);
    if (body && body.data) {
      roomsCreated.add(1);
      return body.data;
    }
  }
  
  return null;
}

// 加入房间辅助函数
function joinRoom(token, roomId) {
  const response = http.post(
    `${env.baseUrl}/api/v1/chat/rooms/${roomId}/join`,
    null,
    { headers: getHeaders(token), tags: { endpoint: 'chat' } }
  );
  
  if (response.status === 200) {
    roomsJoined.add(1);
    return true;
  }
  
  return false;
}

// 主测试函数
export default function(data) {
  const { users, rooms } = data;
  
  if (users.length === 0 || rooms.length === 0) {
    console.log('No test data available');
    return;
  }
  
  const userIndex = __VU % users.length;
  const user = users[userIndex];
  const room = rooms[randomIntBetween(0, rooms.length - 1)];
  
  // 随机选择场景
  const scenario = randomIntBetween(1, 100);
  
  if (scenario <= 40) {
    // 40% - 发送消息
    testSendMessage(user, room);
  } else if (scenario <= 70) {
    // 30% - 查询消息
    testQueryMessages(user, room);
  } else if (scenario <= 85) {
    // 15% - 房间操作
    testRoomOperations(user);
  } else if (scenario <= 95) {
    // 10% - 成员管理
    testMemberOperations(user, room);
  } else {
    // 5% - 消息操作 (编辑/删除)
    testMessageOperations(user, room);
  }
  
  think(0.5, 2);
}

// 发送消息测试
function testSendMessage(user, room) {
  group('Send Message', function() {
    const content = generateMessage(10, 500);
    const payload = JSON.stringify({
      content: content,
      type: 'text',
      metadata: {
        client_id: `k6-${Date.now()}`,
      },
    });
    
    const start = Date.now();
    const response = http.post(
      `${env.baseUrl}/api/v1/chat/rooms/${room.id}/messages`,
      payload,
      { headers: getHeaders(user.token), tags: { endpoint: 'chat' } }
    );
    messageSendDuration.add(Date.now() - start);
    
    const success = check(response, {
      'message sent status 200 or 201': (r) => r.status === 200 || r.status === 201,
      'message sent time < 200ms': (r) => r.timings.duration < 200,
      'message has id': (r) => {
        const body = parseJson(r);
        return body && body.data && body.data.id;
      },
    });
    
    if (success) {
      messagesSent.add(1);
    } else {
      apiErrors.add(1);
    }
  });
}

// 查询消息测试
function testQueryMessages(user, room) {
  group('Query Messages', function() {
    const start = Date.now();
    
    // 获取最新消息
    const response = http.get(
      `${env.baseUrl}/api/v1/chat/rooms/${room.id}/messages?limit=50`,
      { headers: getHeaders(user.token), tags: { endpoint: 'chat' } }
    );
    messageQueryDuration.add(Date.now() - start);
    
    const success = check(response, {
      'query status 200': (r) => r.status === 200,
      'query time < 300ms': (r) => r.timings.duration < 300,
      'query returns array': (r) => {
        const body = parseJson(r);
        return body && body.data && Array.isArray(body.data.messages);
      },
    });
    
    if (success) {
      const body = parseJson(response);
      if (body && body.data && body.data.messages) {
        messagesReceived.add(body.data.messages.length);
      }
    }
    
    // 分页测试
    sleep(0.5);
    const pageResponse = http.get(
      `${env.baseUrl}/api/v1/chat/rooms/${room.id}/messages?limit=20&offset=20`,
      { headers: getHeaders(user.token), tags: { endpoint: 'chat' } }
    );
    
    check(pageResponse, {
      'pagination status 200': (r) => r.status === 200,
    });
  });
}

// 房间操作测试
function testRoomOperations(user) {
  group('Room Operations', function() {
    // 获取房间列表
    const listResponse = http.get(
      `${env.baseUrl}/api/v1/chat/rooms`,
      { headers: getHeaders(user.token), tags: { endpoint: 'chat' } }
    );
    
    check(listResponse, {
      'room list status 200': (r) => r.status === 200,
      'room list time < 300ms': (r) => r.timings.duration < 300,
    });
    
    const body = parseJson(listResponse);
    if (body && body.data && body.data.rooms && body.data.rooms.length > 0) {
      activeRooms.add(body.data.rooms.length);
      
      // 获取单个房间详情
      const roomId = body.data.rooms[0].id;
      sleep(0.3);
      
      const detailResponse = http.get(
        `${env.baseUrl}/api/v1/chat/rooms/${roomId}`,
        { headers: getHeaders(user.token), tags: { endpoint: 'chat' } }
      );
      
      check(detailResponse, {
        'room detail status 200': (r) => r.status === 200,
        'room detail has data': (r) => {
          const detailBody = parseJson(r);
          return detailBody && detailBody.data && detailBody.data.id;
        },
      });
    }
    
    // 创建新房间
    sleep(0.5);
    const newRoom = createRoom(user.token, `Dynamic Room ${Date.now()}`);
    
    if (newRoom) {
      // 更新房间设置
      sleep(0.3);
      const updatePayload = JSON.stringify({
        name: `Updated ${newRoom.name}`,
        description: 'Updated description',
      });
      
      const updateResponse = http.put(
        `${env.baseUrl}/api/v1/chat/rooms/${newRoom.id}`,
        updatePayload,
        { headers: getHeaders(user.token), tags: { endpoint: 'chat' } }
      );
      
      check(updateResponse, {
        'room update status 200': (r) => r.status === 200,
      });
    }
  });
}

// 成员操作测试
function testMemberOperations(user, room) {
  group('Member Operations', function() {
    // 获取成员列表
    const response = http.get(
      `${env.baseUrl}/api/v1/chat/rooms/${room.id}/members`,
      { headers: getHeaders(user.token), tags: { endpoint: 'chat' } }
    );
    
    check(response, {
      'member list status 200': (r) => r.status === 200,
      'member list time < 200ms': (r) => r.timings.duration < 200,
    });
    
    const body = parseJson(response);
    if (body && body.data && body.data.members) {
      membersPerRoom.add(body.data.members.length);
    }
    
    // 获取在线成员
    sleep(0.3);
    const onlineResponse = http.get(
      `${env.baseUrl}/api/v1/chat/rooms/${room.id}/members/online`,
      { headers: getHeaders(user.token), tags: { endpoint: 'chat' } }
    );
    
    check(onlineResponse, {
      'online members status 200 or 404': (r) => r.status === 200 || r.status === 404,
    });
  });
}

// 消息操作测试
function testMessageOperations(user, room) {
  group('Message Operations', function() {
    // 先发送一条消息
    const content = generateMessage(10, 100);
    const sendPayload = JSON.stringify({
      content: content,
      type: 'text',
    });
    
    const sendResponse = http.post(
      `${env.baseUrl}/api/v1/chat/rooms/${room.id}/messages`,
      sendPayload,
      { headers: getHeaders(user.token), tags: { endpoint: 'chat' } }
    );
    
    if (sendResponse.status !== 200 && sendResponse.status !== 201) {
      return;
    }
    
    const body = parseJson(sendResponse);
    if (!body || !body.data || !body.data.id) {
      return;
    }
    
    const messageId = body.data.id;
    
    // 编辑消息
    sleep(0.5);
    const editPayload = JSON.stringify({
      content: `Edited: ${content}`,
    });
    
    const editResponse = http.put(
      `${env.baseUrl}/api/v1/chat/rooms/${room.id}/messages/${messageId}`,
      editPayload,
      { headers: getHeaders(user.token), tags: { endpoint: 'chat' } }
    );
    
    check(editResponse, {
      'edit message status 200': (r) => r.status === 200,
    });
    
    // 删除消息
    sleep(0.5);
    const deleteResponse = http.del(
      `${env.baseUrl}/api/v1/chat/rooms/${room.id}/messages/${messageId}`,
      null,
      { headers: getHeaders(user.token), tags: { endpoint: 'chat' } }
    );
    
    check(deleteResponse, {
      'delete message status 200 or 204': (r) => r.status === 200 || r.status === 204,
    });
  });
}

// 清理
export function teardown(data) {
  console.log('Chat load test completed');
  console.log(`Users: ${data.users.length}, Rooms: ${data.rooms.length}`);
}
