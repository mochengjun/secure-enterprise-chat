import type { User } from './User';

export type MemberRole = 'owner' | 'admin' | 'member';

export interface Member {
  id: string;
  userId: string;
  roomId: string;
  user: User;
  role: MemberRole;
  joinedAt: Date;
}
