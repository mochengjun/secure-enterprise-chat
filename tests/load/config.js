// k6 负载测试配置
// 支持多环境配置

export const environments = {
  local: {
    baseUrl: 'http://localhost:8081',
    wsUrl: 'ws://localhost:8081',
  },
  staging: {
    baseUrl: 'https://staging-api.sec-chat.example.com',
    wsUrl: 'wss://staging-api.sec-chat.example.com',
  },
  production: {
    baseUrl: 'https://api.sec-chat.example.com',
    wsUrl: 'wss://api.sec-chat.example.com',
  },
};

// 根据环境变量选择配置
export const env = environments[__ENV.TARGET_ENV || 'local'];

// 测试阈值配置
export const thresholds = {
  // HTTP 请求
  http_req_duration: ['p(95)<500', 'p(99)<1000'],       // 95% 请求 < 500ms
  http_req_failed: ['rate<0.01'],                       // 失败率 < 1%
  http_reqs: ['rate>100'],                              // 每秒请求数 > 100
  
  // 自定义指标
  'http_req_duration{endpoint:auth}': ['p(95)<200'],    // 认证接口更严格
  'http_req_duration{endpoint:chat}': ['p(95)<300'],    // 聊天接口
  'http_req_duration{endpoint:media}': ['p(95)<1000'],  // 媒体上传允许更长
  
  // WebSocket
  ws_connecting: ['p(95)<100'],                         // WS 连接时间
  ws_session_duration: ['avg>60000'],                   // 平均会话时长 > 1分钟
  
  // 迭代
  iteration_duration: ['p(95)<5000'],                   // 完整迭代 < 5秒
};

// 负载配置预设
export const loadProfiles = {
  // 冒烟测试 - 快速验证
  smoke: {
    stages: [
      { duration: '1m', target: 5 },
    ],
  },
  
  // 负载测试 - 正常负载
  load: {
    stages: [
      { duration: '2m', target: 50 },   // 爬坡
      { duration: '5m', target: 50 },   // 稳定
      { duration: '2m', target: 0 },    // 降负载
    ],
  },
  
  // 压力测试 - 找极限
  stress: {
    stages: [
      { duration: '2m', target: 50 },
      { duration: '3m', target: 100 },
      { duration: '3m', target: 200 },
      { duration: '3m', target: 300 },
      { duration: '5m', target: 300 },
      { duration: '2m', target: 0 },
    ],
  },
  
  // 峰值测试 - 突发流量
  spike: {
    stages: [
      { duration: '1m', target: 50 },
      { duration: '10s', target: 500 },  // 突发
      { duration: '2m', target: 500 },
      { duration: '10s', target: 50 },   // 恢复
      { duration: '2m', target: 50 },
      { duration: '1m', target: 0 },
    ],
  },
  
  // 浸泡测试 - 长时间运行
  soak: {
    stages: [
      { duration: '5m', target: 100 },
      { duration: '4h', target: 100 },   // 长时间稳定
      { duration: '5m', target: 0 },
    ],
  },
};

// 获取负载配置
export function getLoadProfile(profileName) {
  return loadProfiles[profileName || __ENV.LOAD_PROFILE || 'load'];
}

// 测试数据配置
export const testData = {
  // 虚拟用户数量
  virtualUsers: parseInt(__ENV.VUS || '50'),
  
  // 测试持续时间
  duration: __ENV.DURATION || '5m',
  
  // 批量操作大小
  batchSize: parseInt(__ENV.BATCH_SIZE || '10'),
  
  // 消息长度范围
  messageLengthMin: 10,
  messageLengthMax: 1000,
  
  // 文件大小范围 (bytes)
  fileSizeMin: 1024,
  fileSizeMax: 5 * 1024 * 1024,
};
