// k6 通用工具函数库
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Counter, Rate, Trend, Gauge } from 'k6/metrics';
import { randomString, randomIntBetween } from 'https://jslib.k6.io/k6-utils/1.4.0/index.js';
import { env } from '../config.js';

// 自定义指标
export const authSuccessRate = new Rate('auth_success_rate');
export const authDuration = new Trend('auth_duration');
export const messagesSent = new Counter('messages_sent');
export const messagesReceived = new Counter('messages_received');
export const wsConnections = new Gauge('ws_active_connections');
export const wsReconnects = new Counter('ws_reconnects');
export const apiErrors = new Counter('api_errors');

// 存储测试用户凭证
const userTokens = new Map();

// HTTP 请求头
export function getHeaders(token = null) {
  const headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'X-Request-ID': `k6-${randomString(16)}`,
  };
  
  if (token) {
    headers['Authorization'] = `Bearer ${token}`;
  }
  
  return headers;
}

// 生成测试用户
export function generateUser(index) {
  return {
    username: `loadtest_user_${index}_${randomString(8)}`,
    email: `loadtest_${index}_${randomString(8)}@test.local`,
    password: `Test@${randomString(12)}`,
    phone: `1380000${String(index).padStart(4, '0')}`,
  };
}

// 用户注册
export function registerUser(user) {
  const url = `${env.baseUrl}/api/v1/auth/register`;
  const payload = JSON.stringify(user);
  
  const response = http.post(url, payload, {
    headers: getHeaders(),
    tags: { endpoint: 'auth' },
  });
  
  const success = check(response, {
    'register status is 200 or 201': (r) => r.status === 200 || r.status === 201,
    'register has user data': (r) => {
      try {
        const body = JSON.parse(r.body);
        return body.data && body.data.user;
      } catch {
        return false;
      }
    },
  });
  
  authSuccessRate.add(success);
  
  if (!success) {
    apiErrors.add(1);
    console.log(`Register failed: ${response.status} - ${response.body}`);
  }
  
  return { success, response };
}

// 用户登录
export function loginUser(username, password) {
  const url = `${env.baseUrl}/api/v1/auth/login`;
  const payload = JSON.stringify({ username, password });
  
  const start = Date.now();
  const response = http.post(url, payload, {
    headers: getHeaders(),
    tags: { endpoint: 'auth' },
  });
  authDuration.add(Date.now() - start);
  
  const success = check(response, {
    'login status is 200': (r) => r.status === 200,
    'login has tokens': (r) => {
      try {
        const body = JSON.parse(r.body);
        return body.data && body.data.access_token;
      } catch {
        return false;
      }
    },
  });
  
  authSuccessRate.add(success);
  
  if (success) {
    try {
      const body = JSON.parse(response.body);
      userTokens.set(username, {
        accessToken: body.data.access_token,
        refreshToken: body.data.refresh_token,
        expiresAt: Date.now() + (body.data.expires_in || 3600) * 1000,
      });
      return { success: true, token: body.data.access_token, response };
    } catch (e) {
      return { success: false, error: e.message, response };
    }
  }
  
  apiErrors.add(1);
  return { success: false, response };
}

// 获取或刷新令牌
export function getToken(username) {
  const tokenData = userTokens.get(username);
  if (!tokenData) return null;
  
  // 如果令牌即将过期(5分钟内),尝试刷新
  if (tokenData.expiresAt - Date.now() < 5 * 60 * 1000) {
    const refreshed = refreshToken(username, tokenData.refreshToken);
    if (refreshed.success) {
      return refreshed.token;
    }
  }
  
  return tokenData.accessToken;
}

// 刷新令牌
export function refreshToken(username, refreshTokenValue) {
  const url = `${env.baseUrl}/api/v1/auth/refresh`;
  const payload = JSON.stringify({ refresh_token: refreshTokenValue });
  
  const response = http.post(url, payload, {
    headers: getHeaders(),
    tags: { endpoint: 'auth' },
  });
  
  if (response.status === 200) {
    try {
      const body = JSON.parse(response.body);
      userTokens.set(username, {
        accessToken: body.data.access_token,
        refreshToken: body.data.refresh_token || refreshTokenValue,
        expiresAt: Date.now() + (body.data.expires_in || 3600) * 1000,
      });
      return { success: true, token: body.data.access_token };
    } catch (e) {
      return { success: false, error: e.message };
    }
  }
  
  return { success: false };
}

// 生成随机消息内容
export function generateMessage(minLen = 10, maxLen = 500) {
  const length = randomIntBetween(minLen, maxLen);
  const words = [
    '你好', '测试', '消息', '发送', '接收', '聊天', '群组', '文件',
    'hello', 'test', 'message', 'send', 'receive', 'chat', 'group', 'file',
    '安全', '加密', '传输', 'secure', 'encrypt', 'transfer',
  ];
  
  let message = '';
  while (message.length < length) {
    message += words[randomIntBetween(0, words.length - 1)] + ' ';
  }
  
  return message.substring(0, length).trim();
}

// 生成随机文件数据
export function generateFileData(size) {
  return randomString(size);
}

// API 调用封装
export function apiCall(method, path, body = null, token = null, tags = {}) {
  const url = `${env.baseUrl}${path}`;
  const params = {
    headers: getHeaders(token),
    tags: { ...tags },
  };
  
  let response;
  switch (method.toUpperCase()) {
    case 'GET':
      response = http.get(url, params);
      break;
    case 'POST':
      response = http.post(url, body ? JSON.stringify(body) : null, params);
      break;
    case 'PUT':
      response = http.put(url, body ? JSON.stringify(body) : null, params);
      break;
    case 'DELETE':
      response = http.del(url, null, params);
      break;
    default:
      throw new Error(`Unsupported method: ${method}`);
  }
  
  if (response.status >= 400) {
    apiErrors.add(1);
  }
  
  return response;
}

// 等待随机时间 (模拟真实用户行为)
export function think(minSeconds = 1, maxSeconds = 5) {
  sleep(randomIntBetween(minSeconds, maxSeconds));
}

// 解析响应 JSON
export function parseJson(response) {
  try {
    return JSON.parse(response.body);
  } catch {
    return null;
  }
}

// 验证响应
export function checkResponse(response, checks) {
  return check(response, checks);
}
