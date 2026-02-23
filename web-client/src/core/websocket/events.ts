// WebSocket事件类型
export const WS_EVENTS = {
  // 连接事件
  CONNECTED: 'connected',
  DISCONNECTED: 'disconnected',
  RECONNECTING: 'reconnecting',
  ERROR: 'error',
  
  // 消息事件
  MESSAGE_NEW: 'message_new',
  MESSAGE_UPDATED: 'message_updated',
  MESSAGE_DELETED: 'message_deleted',
  
  // 聊天室事件
  ROOM_CREATED: 'room_created',
  ROOM_UPDATED: 'room_updated',
  ROOM_DELETED: 'room_deleted',
  
  // 成员事件
  MEMBER_JOINED: 'member_joined',
  MEMBER_LEFT: 'member_left',
  MEMBER_UPDATED: 'member_updated',
  
  // 输入状态
  TYPING: 'typing',
  TYPING_STOP: 'typing_stop',
  
  // 已读状态
  READ_RECEIPT: 'read_receipt',
  
  // 心跳
  PING: 'ping',
  PONG: 'pong',
} as const;

export type WsEventType = typeof WS_EVENTS[keyof typeof WS_EVENTS];
