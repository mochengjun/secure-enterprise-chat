// API端点常量
export const ENDPOINTS = {
  // 认证
  AUTH: {
    LOGIN: '/auth/login',
    REGISTER: '/auth/register',
    REFRESH: '/auth/refresh',
    LOGOUT: '/auth/logout',
    ME: '/auth/me',
  },
  
  // 聊天室
  CHAT: {
    ROOMS: '/chat/rooms',
    PUBLIC_ROOMS: '/chat/rooms/public',
    ROOM: (roomId: string) => `/chat/rooms/${roomId}`,
    ROOM_JOIN: (roomId: string) => `/chat/rooms/${roomId}/join`,
    ROOM_LEAVE: (roomId: string) => `/chat/rooms/${roomId}/leave`,
    ROOM_MESSAGES: (roomId: string) => `/chat/rooms/${roomId}/messages`,
    ROOM_MEMBERS: (roomId: string) => `/chat/rooms/${roomId}/members`,
    ROOM_MEMBER: (roomId: string, userId: string) => `/chat/rooms/${roomId}/members/${userId}`,
    MARK_READ: (roomId: string) => `/chat/rooms/${roomId}/read`,
    READ_RECEIPTS: (roomId: string) => `/chat/rooms/${roomId}/read-receipts`,
    TYPING: (roomId: string) => `/chat/rooms/${roomId}/typing`,
  },
  
  // 用户
  USERS: {
    SEARCH: '/chat/users/search',
    PROFILE: (userId: string) => `/users/${userId}`,
  },
  
  // 媒体
  MEDIA: {
    UPLOAD: '/media/upload',
    DOWNLOAD: (mediaId: string) => `/media/${mediaId}/download`,
    DELETE: (mediaId: string) => `/media/${mediaId}`,
    CHUNKED_INIT: '/media/upload/chunked/init',
    CHUNKED_CHUNK: (sessionId: string, index: number) => `/media/upload/chunked/${sessionId}/chunk/${index}`,
    CHUNKED_COMPLETE: (sessionId: string) => `/media/upload/chunked/${sessionId}/complete`,
  },
} as const;
