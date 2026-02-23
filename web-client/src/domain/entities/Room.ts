import type { Message } from './Message';

export type RoomType = 'direct' | 'group' | 'channel';

export interface Room {
  id: string;
  name: string;
  type: RoomType;
  description?: string;
  avatarUrl?: string;
  createdBy: string;
  memberCount: number;
  unreadCount: number;
  lastMessage?: Message;
  createdAt: Date;
  updatedAt: Date;
}
