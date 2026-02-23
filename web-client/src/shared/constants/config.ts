// API配置
// 使用相对路径 /api/v1，通过 vite proxy 代理到后端，确保局域网/外网都能访问
const BASE_URL = import.meta.env.VITE_API_BASE_URL || '/api/v1';

// WebSocket URL：根据当前页面 host 动态计算，确保外网也能连接
function getWsUrl(): string {
  const envWsUrl = import.meta.env.VITE_WS_URL;
  if (envWsUrl) return envWsUrl;
  
  const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
  return `${protocol}//${window.location.host}/api/v1/ws`;
}

export const API_CONFIG = {
  BASE_URL,
  get WS_URL() { return getWsUrl(); },
  TIMEOUT: 30000,
} as const;

// Token配置
export const TOKEN_CONFIG = {
  ACCESS_TOKEN_KEY: 'sec_chat_access_token',
  REFRESH_TOKEN_KEY: 'sec_chat_refresh_token',
  ACCESS_TOKEN_EXPIRES: 60 * 60 * 1000, // 1小时
  REFRESH_TOKEN_EXPIRES: 7 * 24 * 60 * 60 * 1000, // 7天
} as const;

// WebSocket配置
export const WS_CONFIG = {
  MAX_RECONNECT_ATTEMPTS: 5,
  RECONNECT_DELAY: 3000,
  HEARTBEAT_INTERVAL: 30000,
} as const;

// 路由路径
export const ROUTES = {
  LOGIN: '/login',
  REGISTER: '/register',
  CHAT: '/chat',
  CHAT_ROOM: '/chat/:roomId',
  SETTINGS: '/settings',
} as const;
