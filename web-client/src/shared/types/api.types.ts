// 认证相关类型 - 匹配后端实际响应格式
export interface LoginRequest {
  username: string;
  password: string;
}

export interface RegisterRequest {
  username: string;
  email: string;
  password: string;
  display_name?: string;
}

// 登录响应 - 后端直接返回（无包装层）
export interface LoginResponse {
  access_token: string;
  refresh_token: string;
  expires_in: number;
  token_type: string;
}

// 注册响应 - 后端直接返回（无token，需要二次登录）
export interface RegisterResponse {
  user_id: string;
  username: string;
  message: string;
}

// 刷新Token响应 - 与登录响应相同
export type RefreshTokenResponse = LoginResponse;

// 用户信息响应 - GET /auth/me 直接返回
export interface UserResponse {
  user_id: string;
  username: string;
  email: string;
  display_name: string;
  avatar_url?: string;
  mfa_enabled: boolean;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

// 用户搜索响应
export interface UserSearchResult {
  user_id: string;
  username: string;
  display_name: string;
  avatar_url?: string;
}

export interface UserSearchResponse {
  users: UserSearchResult[];
}

// 聊天室相关类型 - 匹配后端实际响应格式
export interface RoomMemberResponse {
  user_id: string;
  display_name: string;
  role: 'owner' | 'admin' | 'member';
  joined_at: string;
  is_online: boolean;
}

export interface RoomMessageResponse {
  id: string;
  room_id: string;
  sender_id: string;
  sender_name: string;
  content: string;
  type: 'text' | 'image' | 'file' | 'video' | 'audio';
  status: string;
  media_url?: string;
  thumbnail_url?: string;
  media_size?: number;
  mime_type?: string;
  is_deleted: boolean;
  created_at: string;
}

export interface RoomResponse {
  id: string;
  name: string;
  type: 'direct' | 'group' | 'channel';
  creator_id: string;
  unread_count: number;
  last_message?: RoomMessageResponse;
  members: RoomMemberResponse[];
  is_muted: boolean;
  is_pinned: boolean;
  created_at: string;
  updated_at: string;
}

// 房间列表响应 - 包装在rooms字段中
export interface RoomsListResponse {
  rooms: RoomResponse[];
}

// 公开房间响应（含member_count和is_member）
export interface PublicRoomResponse extends RoomResponse {
  member_count: number;
  is_member: boolean;
  description?: string;
}

export interface PublicRoomsListResponse {
  rooms: PublicRoomResponse[];
}

export interface CreateRoomRequest {
  name: string;
  type: 'direct' | 'group' | 'channel';
  description?: string;
  member_ids?: string[];
}

// 消息相关类型
export interface MessageResponse {
  id: string;
  room_id: string;
  sender_id: string;
  sender_name: string;
  content: string;
  type: 'text' | 'image' | 'file' | 'video' | 'audio';
  status: string;
  media_url?: string;
  thumbnail_url?: string;
  media_size?: number;
  mime_type?: string;
  is_deleted: boolean;
  created_at: string;
}

export interface MessagesListResponse {
  messages: MessageResponse[];
}

export interface SendMessageRequest {
  content: string;
  type?: 'text' | 'image' | 'file' | 'video' | 'audio';
  media_id?: string;
  reply_to?: string;
}

// 成员相关类型
export interface MemberResponse {
  user_id: string;
  display_name: string;
  role: 'owner' | 'admin' | 'member';
  joined_at: string;
  is_online: boolean;
}

export interface MembersListResponse {
  members: MemberResponse[];
}

export interface AddMemberRequest {
  user_id: string;
  role?: 'admin' | 'member';
}

// 媒体相关类型
export interface MediaUploadResponse {
  id: string;
  url: string;
  filename: string;
  mime_type: string;
  size: number;
  created_at: string;
}

// WebSocket消息类型
export interface WsMessage<T = unknown> {
  type: string;
  payload: T;
  timestamp?: string;
}

// 错误响应
export interface ErrorResponse {
  error: string;
}

// 已读回执响应
export interface ReadReceiptResponse {
  user_id: string;
  room_id: string;
  read_at: string;
}

export interface ReadReceiptsListResponse {
  read_receipts: ReadReceiptResponse[];
}
