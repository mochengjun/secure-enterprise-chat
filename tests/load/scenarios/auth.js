// 认证接口负载测试
// 测试登录、注册、令牌刷新、登出等接口

import { check, sleep, group } from 'k6';
import http from 'k6/http';
import { Counter, Rate, Trend } from 'k6/metrics';
import { randomIntBetween } from 'https://jslib.k6.io/k6-utils/1.4.0/index.js';
import { env, thresholds, getLoadProfile, testData } from '../config.js';
import { 
  getHeaders, 
  generateUser, 
  registerUser, 
  loginUser, 
  think,
  parseJson,
  apiCall,
  authSuccessRate,
  authDuration,
  apiErrors,
} from '../lib/helpers.js';

// 自定义指标
const loginAttempts = new Counter('login_attempts');
const loginSuccessful = new Counter('login_successful');
const registrationAttempts = new Counter('registration_attempts');
const registrationSuccessful = new Counter('registration_successful');
const tokenRefreshAttempts = new Counter('token_refresh_attempts');
const tokenRefreshSuccessful = new Counter('token_refresh_successful');
const logoutAttempts = new Counter('logout_attempts');
const mfaAttempts = new Counter('mfa_attempts');

// 测试选项
export const options = {
  stages: getLoadProfile('load').stages,
  thresholds: {
    ...thresholds,
    'auth_success_rate': ['rate>0.95'],
    'login_successful': ['count>0'],
    'http_req_duration{endpoint:auth}': ['p(95)<300', 'p(99)<500'],
  },
  tags: {
    testType: 'auth',
    environment: __ENV.TARGET_ENV || 'local',
  },
};

// 测试数据存储
const testUsers = [];
const activeTokens = new Map();

// 初始化 - 创建测试用户
export function setup() {
  console.log('Setting up auth load test...');
  console.log(`Target environment: ${env.baseUrl}`);
  
  const users = [];
  const numUsers = Math.min(testData.virtualUsers, 100);
  
  // 预创建一批测试用户
  for (let i = 0; i < numUsers; i++) {
    const user = generateUser(i);
    const result = registerUser(user);
    
    if (result.success) {
      users.push({
        ...user,
        registered: true,
      });
      console.log(`Created test user: ${user.username}`);
    } else {
      // 可能用户已存在,尝试直接使用
      users.push({
        ...user,
        registered: false,
      });
    }
    
    // 避免请求过快
    sleep(0.1);
  }
  
  return { users };
}

// 主测试函数
export default function(data) {
  const users = data.users;
  const userIndex = __VU % users.length;
  const user = users[userIndex];
  
  // 随机选择测试场景
  const scenario = randomIntBetween(1, 100);
  
  if (scenario <= 50) {
    // 50% - 登录流程
    testLogin(user);
  } else if (scenario <= 70) {
    // 20% - 注册新用户
    testRegistration();
  } else if (scenario <= 85) {
    // 15% - 令牌刷新
    testTokenRefresh(user);
  } else if (scenario <= 95) {
    // 10% - 登出
    testLogout(user);
  } else {
    // 5% - MFA 流程
    testMFA(user);
  }
  
  // 模拟用户思考时间
  think(1, 3);
}

// 登录测试
function testLogin(user) {
  group('Login Flow', function() {
    loginAttempts.add(1);
    
    const result = loginUser(user.username, user.password);
    
    const success = check(result.response, {
      'login response status 200': (r) => r.status === 200,
      'login response time < 300ms': (r) => r.timings.duration < 300,
      'login returns access token': (r) => {
        const body = parseJson(r);
        return body && body.data && body.data.access_token;
      },
      'login returns refresh token': (r) => {
        const body = parseJson(r);
        return body && body.data && body.data.refresh_token;
      },
    });
    
    if (success && result.success) {
      loginSuccessful.add(1);
      activeTokens.set(user.username, result.token);
      
      // 验证获取用户信息
      sleep(0.5);
      testGetProfile(result.token);
    }
  });
}

// 获取用户资料
function testGetProfile(token) {
  group('Get Profile', function() {
    const response = apiCall('GET', '/api/v1/users/me', null, token, { endpoint: 'auth' });
    
    check(response, {
      'profile status 200': (r) => r.status === 200,
      'profile has user data': (r) => {
        const body = parseJson(r);
        return body && body.data && body.data.id;
      },
    });
  });
}

// 注册测试
function testRegistration() {
  group('Registration Flow', function() {
    registrationAttempts.add(1);
    
    const newUser = generateUser(Date.now());
    const result = registerUser(newUser);
    
    const success = check(result.response, {
      'registration status 200 or 201': (r) => r.status === 200 || r.status === 201,
      'registration response time < 500ms': (r) => r.timings.duration < 500,
      'registration returns user data': (r) => {
        const body = parseJson(r);
        return body && body.data && body.data.user;
      },
    });
    
    if (success) {
      registrationSuccessful.add(1);
    }
  });
}

// 令牌刷新测试
function testTokenRefresh(user) {
  group('Token Refresh Flow', function() {
    // 先登录获取令牌
    const loginResult = loginUser(user.username, user.password);
    
    if (!loginResult.success) {
      return;
    }
    
    const body = parseJson(loginResult.response);
    if (!body || !body.data || !body.data.refresh_token) {
      return;
    }
    
    sleep(1);
    tokenRefreshAttempts.add(1);
    
    // 刷新令牌
    const refreshPayload = JSON.stringify({
      refresh_token: body.data.refresh_token,
    });
    
    const response = http.post(
      `${env.baseUrl}/api/v1/auth/refresh`,
      refreshPayload,
      { headers: getHeaders(), tags: { endpoint: 'auth' } }
    );
    
    const success = check(response, {
      'refresh status 200': (r) => r.status === 200,
      'refresh response time < 200ms': (r) => r.timings.duration < 200,
      'refresh returns new access token': (r) => {
        const respBody = parseJson(r);
        return respBody && respBody.data && respBody.data.access_token;
      },
    });
    
    if (success) {
      tokenRefreshSuccessful.add(1);
    }
  });
}

// 登出测试
function testLogout(user) {
  group('Logout Flow', function() {
    // 先登录
    const loginResult = loginUser(user.username, user.password);
    
    if (!loginResult.success) {
      return;
    }
    
    sleep(0.5);
    logoutAttempts.add(1);
    
    // 登出
    const response = http.post(
      `${env.baseUrl}/api/v1/auth/logout`,
      null,
      { 
        headers: getHeaders(loginResult.token),
        tags: { endpoint: 'auth' },
      }
    );
    
    check(response, {
      'logout status 200': (r) => r.status === 200,
      'logout response time < 200ms': (r) => r.timings.duration < 200,
    });
    
    // 验证令牌已失效
    sleep(0.5);
    const profileResponse = apiCall('GET', '/api/v1/users/me', null, loginResult.token, { endpoint: 'auth' });
    
    check(profileResponse, {
      'token invalidated after logout': (r) => r.status === 401,
    });
  });
}

// MFA 测试 (模拟)
function testMFA(user) {
  group('MFA Flow', function() {
    mfaAttempts.add(1);
    
    // 登录触发 MFA
    const loginPayload = JSON.stringify({
      username: user.username,
      password: user.password,
    });
    
    const response = http.post(
      `${env.baseUrl}/api/v1/auth/login`,
      loginPayload,
      { headers: getHeaders(), tags: { endpoint: 'auth' } }
    );
    
    const body = parseJson(response);
    
    // 检查是否需要 MFA
    if (body && body.data && body.data.mfa_required) {
      // 发送 MFA 验证码 (测试环境通常使用固定验证码)
      sleep(1);
      
      const mfaPayload = JSON.stringify({
        mfa_token: body.data.mfa_token,
        code: '123456', // 测试验证码
      });
      
      const mfaResponse = http.post(
        `${env.baseUrl}/api/v1/auth/mfa/verify`,
        mfaPayload,
        { headers: getHeaders(), tags: { endpoint: 'auth' } }
      );
      
      check(mfaResponse, {
        'mfa verification completed': (r) => r.status === 200 || r.status === 400,
      });
    }
  });
}

// 测试结束处理
export function teardown(data) {
  console.log('Auth load test completed');
  console.log(`Total users tested: ${data.users.length}`);
}
