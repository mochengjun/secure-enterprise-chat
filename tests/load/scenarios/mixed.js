// 混合场景负载测试
// 模拟真实用户行为，包含多种操作的组合场景

import { check, sleep, group } from 'k6';
import http from 'k6/http';
import ws from 'k6/ws';
import { Counter, Rate, Trend, Gauge } from 'k6/metrics';
import { randomIntBetween, randomString } from 'https://jslib.k6.io/k6-utils/1.4.0/index.js';
import { env, thresholds, getLoadProfile, testData } from '../config.js';
import {
  getHeaders,
  generateUser,
  registerUser,
  loginUser,
  generateMessage,
  generateFileData,
  think,
  parseJson,
  apiCall,
  apiErrors,
  messagesSent,
  messagesReceived,
  wsConnections,
} from '../lib/helpers.js';

// 自定义指标
const userJourneyDuration = new Trend('user_journey_duration');
const userJourneySuccess = new Rate('user_journey_success');
const scenarioExecutions = new Counter('scenario_executions');
const fileUploadDuration = new Trend('file_upload_duration');
const searchDuration = new Trend('search_duration');

// 测试选项
export const options = {
  scenarios: {
    // 场景1: 普通用户 - 大部分是消息读写
    normal_users: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '2m', target: 30 },
        { duration: '5m', target: 30 },
        { duration: '2m', target: 0 },
      ],
      exec: 'normalUserJourney',
      tags: { scenario: 'normal' },
    },
    
    // 场景2: 活跃用户 - 频繁发消息和文件
    active_users: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '2m', target: 15 },
        { duration: '5m', target: 15 },
        { duration: '2m', target: 0 },
      ],
      exec: 'activeUserJourney',
      tags: { scenario: 'active' },
    },
    
    // 场景3: 管理员 - 用户和房间管理
    admin_users: {
      executor: 'constant-vus',
      vus: 5,
      duration: '9m',
      exec: 'adminUserJourney',
      tags: { scenario: 'admin' },
    },
    
    // 场景4: 新用户 - 注册和初始化
    new_users: {
      executor: 'constant-arrival-rate',
      rate: 2,
      timeUnit: '1m',
      duration: '9m',
      preAllocatedVUs: 10,
      exec: 'newUserJourney',
      tags: { scenario: 'new' },
    },
  },
  thresholds: {
    ...thresholds,
    'user_journey_success': ['rate>0.90'],
    'user_journey_duration': ['p(95)<30000'],
    'iteration_duration{scenario:normal}': ['p(95)<20000'],
    'iteration_duration{scenario:active}': ['p(95)<25000'],
  },
  tags: {
    testType: 'mixed',
    environment: __ENV.TARGET_ENV || 'local',
  },
};

// 测试数据
let setupData = null;

// 初始化
export function setup() {
  console.log('Setting up mixed scenario load test...');
  
  const normalUsers = [];
  const activeUsers = [];
  const adminUsers = [];
  const rooms = [];
  
  // 创建普通用户
  for (let i = 0; i < 30; i++) {
    const user = generateUser(i);
    registerUser(user);
    const result = loginUser(user.username, user.password);
    if (result.success) {
      normalUsers.push({ ...user, token: result.token });
    }
    sleep(0.05);
  }
  
  // 创建活跃用户
  for (let i = 30; i < 45; i++) {
    const user = generateUser(i);
    registerUser(user);
    const result = loginUser(user.username, user.password);
    if (result.success) {
      activeUsers.push({ ...user, token: result.token });
    }
    sleep(0.05);
  }
  
  // 创建管理员用户 (假设有管理员注册接口或预置)
  for (let i = 45; i < 50; i++) {
    const user = generateUser(i);
    registerUser(user);
    const result = loginUser(user.username, user.password);
    if (result.success) {
      adminUsers.push({ ...user, token: result.token });
    }
    sleep(0.05);
  }
  
  // 创建测试房间
  if (normalUsers.length > 0) {
    for (let i = 0; i < 10; i++) {
      const creator = normalUsers[i % normalUsers.length];
      const response = http.post(
        `${env.baseUrl}/api/v1/chat/rooms`,
        JSON.stringify({
          name: `Mixed Test Room ${i}`,
          type: 'group',
        }),
        { headers: getHeaders(creator.token) }
      );
      
      if (response.status === 200 || response.status === 201) {
        const body = parseJson(response);
        if (body && body.data) {
          rooms.push(body.data);
        }
      }
      sleep(0.1);
    }
  }
  
  console.log(`Setup complete: ${normalUsers.length} normal, ${activeUsers.length} active, ${adminUsers.length} admin users, ${rooms.length} rooms`);
  
  return { normalUsers, activeUsers, adminUsers, rooms };
}

// 普通用户旅程
export function normalUserJourney() {
  const data = setupData || setup();
  const { normalUsers, rooms } = data;
  
  if (normalUsers.length === 0) return;
  
  const userIndex = __VU % normalUsers.length;
  const user = normalUsers[userIndex];
  const journeyStart = Date.now();
  let success = true;
  
  scenarioExecutions.add(1);
  
  group('Normal User Journey', function() {
    // 1. 登录 (模拟会话开始)
    group('Session Start', function() {
      const loginResult = loginUser(user.username, user.password);
      if (!loginResult.success) {
        success = false;
        return;
      }
      user.token = loginResult.token;
    });
    
    if (!success) return;
    
    // 2. 获取房间列表
    think(1, 2);
    group('Browse Rooms', function() {
      const response = apiCall('GET', '/api/v1/chat/rooms', null, user.token);
      check(response, {
        'rooms loaded': (r) => r.status === 200,
      });
    });
    
    // 3. 进入房间查看消息
    if (rooms.length > 0) {
      const room = rooms[randomIntBetween(0, rooms.length - 1)];
      
      think(1, 3);
      group('Read Messages', function() {
        const response = apiCall('GET', `/api/v1/chat/rooms/${room.id}/messages?limit=30`, null, user.token);
        const loaded = check(response, {
          'messages loaded': (r) => r.status === 200,
        });
        
        if (loaded) {
          const body = parseJson(response);
          if (body && body.data && body.data.messages) {
            messagesReceived.add(body.data.messages.length);
          }
        }
      });
      
      // 4. 发送消息 (30% 概率)
      if (randomIntBetween(1, 100) <= 30) {
        think(2, 5);
        group('Send Message', function() {
          const response = http.post(
            `${env.baseUrl}/api/v1/chat/rooms/${room.id}/messages`,
            JSON.stringify({
              content: generateMessage(10, 200),
              type: 'text',
            }),
            { headers: getHeaders(user.token) }
          );
          
          if (response.status === 200 || response.status === 201) {
            messagesSent.add(1);
          }
        });
      }
    }
    
    // 5. 搜索消息 (20% 概率)
    if (randomIntBetween(1, 100) <= 20) {
      think(1, 2);
      group('Search', function() {
        const start = Date.now();
        const response = apiCall('GET', '/api/v1/chat/search?q=test&limit=20', null, user.token);
        searchDuration.add(Date.now() - start);
        
        check(response, {
          'search completed': (r) => r.status === 200 || r.status === 404,
        });
      });
    }
    
    // 6. 查看用户资料
    think(1, 2);
    group('View Profile', function() {
      apiCall('GET', '/api/v1/users/me', null, user.token);
    });
  });
  
  userJourneyDuration.add(Date.now() - journeyStart);
  userJourneySuccess.add(success);
}

// 活跃用户旅程
export function activeUserJourney() {
  const data = setupData || setup();
  const { activeUsers, rooms } = data;
  
  if (activeUsers.length === 0) return;
  
  const userIndex = __VU % activeUsers.length;
  const user = activeUsers[userIndex];
  const journeyStart = Date.now();
  let success = true;
  
  scenarioExecutions.add(1);
  
  group('Active User Journey', function() {
    // 1. 快速登录
    const loginResult = loginUser(user.username, user.password);
    if (!loginResult.success) {
      success = false;
      return;
    }
    user.token = loginResult.token;
    
    // 2. 在多个房间发送消息
    const numRooms = Math.min(3, rooms.length);
    for (let i = 0; i < numRooms; i++) {
      const room = rooms[randomIntBetween(0, rooms.length - 1)];
      
      think(0.5, 1);
      group(`Room ${i + 1} Activity`, function() {
        // 发送多条消息
        const numMessages = randomIntBetween(2, 5);
        for (let j = 0; j < numMessages; j++) {
          const response = http.post(
            `${env.baseUrl}/api/v1/chat/rooms/${room.id}/messages`,
            JSON.stringify({
              content: generateMessage(10, 500),
              type: 'text',
            }),
            { headers: getHeaders(user.token) }
          );
          
          if (response.status === 200 || response.status === 201) {
            messagesSent.add(1);
          }
          
          sleep(randomIntBetween(500, 1500) / 1000);
        }
      });
    }
    
    // 3. 上传文件 (50% 概率)
    if (randomIntBetween(1, 100) <= 50 && rooms.length > 0) {
      const room = rooms[0];
      
      think(0.5, 1);
      group('File Upload', function() {
        const start = Date.now();
        const fileData = generateFileData(randomIntBetween(1024, 50 * 1024));
        
        const response = http.post(
          `${env.baseUrl}/api/v1/media/upload`,
          {
            file: http.file(fileData, 'test.txt', 'text/plain'),
            room_id: room.id,
          },
          { 
            headers: {
              'Authorization': `Bearer ${user.token}`,
            },
          }
        );
        
        fileUploadDuration.add(Date.now() - start);
        
        check(response, {
          'file uploaded': (r) => r.status === 200 || r.status === 201,
        });
      });
    }
    
    // 4. 获取通知
    think(0.5, 1);
    group('Check Notifications', function() {
      apiCall('GET', '/api/v1/notifications?unread=true', null, user.token);
    });
  });
  
  userJourneyDuration.add(Date.now() - journeyStart);
  userJourneySuccess.add(success);
}

// 管理员用户旅程
export function adminUserJourney() {
  const data = setupData || setup();
  const { adminUsers, normalUsers, rooms } = data;
  
  if (adminUsers.length === 0) return;
  
  const userIndex = __VU % adminUsers.length;
  const admin = adminUsers[userIndex];
  const journeyStart = Date.now();
  let success = true;
  
  scenarioExecutions.add(1);
  
  group('Admin User Journey', function() {
    // 1. 管理员登录
    const loginResult = loginUser(admin.username, admin.password);
    if (!loginResult.success) {
      success = false;
      return;
    }
    admin.token = loginResult.token;
    
    // 2. 获取用户列表
    think(1, 2);
    group('List Users', function() {
      const response = apiCall('GET', '/api/v1/admin/users?page=1&limit=20', null, admin.token);
      check(response, {
        'users listed': (r) => r.status === 200 || r.status === 403,
      });
    });
    
    // 3. 获取房间列表
    think(1, 2);
    group('List Rooms', function() {
      const response = apiCall('GET', '/api/v1/admin/rooms?page=1&limit=20', null, admin.token);
      check(response, {
        'rooms listed': (r) => r.status === 200 || r.status === 403,
      });
    });
    
    // 4. 查看系统统计
    think(1, 2);
    group('View Stats', function() {
      apiCall('GET', '/api/v1/admin/stats', null, admin.token);
    });
    
    // 5. 查看审计日志
    think(1, 2);
    group('View Audit Logs', function() {
      const response = apiCall('GET', '/api/v1/admin/audit-logs?limit=50', null, admin.token);
      check(response, {
        'audit logs loaded': (r) => r.status === 200 || r.status === 403,
      });
    });
    
    // 6. 检查用户详情 (随机选择一个用户)
    if (normalUsers.length > 0) {
      think(1, 2);
      group('View User Detail', function() {
        const targetUser = normalUsers[randomIntBetween(0, normalUsers.length - 1)];
        apiCall('GET', `/api/v1/admin/users/${targetUser.username}`, null, admin.token);
      });
    }
  });
  
  userJourneyDuration.add(Date.now() - journeyStart);
  userJourneySuccess.add(success);
  
  think(5, 10);
}

// 新用户旅程
export function newUserJourney() {
  const journeyStart = Date.now();
  let success = true;
  
  scenarioExecutions.add(1);
  
  group('New User Journey', function() {
    // 1. 注册新用户
    const newUser = generateUser(Date.now());
    
    group('Registration', function() {
      const response = http.post(
        `${env.baseUrl}/api/v1/auth/register`,
        JSON.stringify(newUser),
        { headers: getHeaders() }
      );
      
      if (response.status !== 200 && response.status !== 201) {
        success = false;
        return;
      }
    });
    
    if (!success) return;
    
    // 2. 首次登录
    think(1, 2);
    let token = null;
    group('First Login', function() {
      const result = loginUser(newUser.username, newUser.password);
      if (!result.success) {
        success = false;
        return;
      }
      token = result.token;
    });
    
    if (!success || !token) return;
    
    // 3. 完善个人资料
    think(1, 2);
    group('Update Profile', function() {
      const response = http.put(
        `${env.baseUrl}/api/v1/users/me`,
        JSON.stringify({
          nickname: `New User ${randomString(6)}`,
          bio: 'Hello, I am a new user!',
        }),
        { headers: getHeaders(token) }
      );
      
      check(response, {
        'profile updated': (r) => r.status === 200,
      });
    });
    
    // 4. 浏览公开房间
    think(1, 2);
    group('Browse Public Rooms', function() {
      const response = apiCall('GET', '/api/v1/chat/rooms/public', null, token);
      check(response, {
        'public rooms loaded': (r) => r.status === 200 || r.status === 404,
      });
    });
    
    // 5. 创建第一个房间
    think(1, 2);
    group('Create First Room', function() {
      const response = http.post(
        `${env.baseUrl}/api/v1/chat/rooms`,
        JSON.stringify({
          name: `New User Room ${randomString(6)}`,
          type: 'private',
        }),
        { headers: getHeaders(token) }
      );
      
      check(response, {
        'room created': (r) => r.status === 200 || r.status === 201,
      });
    });
    
    // 6. 发送第一条消息
    think(1, 2);
    group('First Message', function() {
      const roomsResponse = apiCall('GET', '/api/v1/chat/rooms', null, token);
      const body = parseJson(roomsResponse);
      
      if (body && body.data && body.data.rooms && body.data.rooms.length > 0) {
        const room = body.data.rooms[0];
        
        const response = http.post(
          `${env.baseUrl}/api/v1/chat/rooms/${room.id}/messages`,
          JSON.stringify({
            content: 'Hello! This is my first message!',
            type: 'text',
          }),
          { headers: getHeaders(token) }
        );
        
        if (response.status === 200 || response.status === 201) {
          messagesSent.add(1);
        }
      }
    });
  });
  
  userJourneyDuration.add(Date.now() - journeyStart);
  userJourneySuccess.add(success);
}

// 清理
export function teardown(data) {
  console.log('Mixed scenario load test completed');
  console.log(`Normal: ${data.normalUsers.length}, Active: ${data.activeUsers.length}, Admin: ${data.adminUsers.length}`);
}
