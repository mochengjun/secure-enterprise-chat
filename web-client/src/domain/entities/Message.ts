import type { User } from './User';

export type MessageType = 'text' | 'image' | 'file' | 'video' | 'audio';

export interface Message {
  id: string;
  roomId: string;
  senderId: string;
  sender: User;
  content: string;
  type: MessageType;
  mediaUrl?: string;
  mediaType?: string;
  mediaSize?: number;
  replyTo?: string;
  isEdited: boolean;
  isDeleted: boolean;
  readBy: string[];
  createdAt: Date;
  updatedAt: Date;
}
