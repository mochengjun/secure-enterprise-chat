import { create } from 'zustand';
import type { Room } from '@domain/entities/Room';
import type { Message } from '@domain/entities/Message';
import { apiClient } from '@core/api/client';
import { ENDPOINTS } from '@core/api/endpoints';
import { WebSocketClient } from '@core/websocket/WebSocketClient';
import { WS_EVENTS } from '@core/websocket/events';
import type { RoomResponse, RoomsListResponse, MessageResponse, MessagesListResponse, CreateRoomRequest, SendMessageRequest, ReadReceiptsListResponse, PublicRoomResponse, PublicRoomsListResponse } from '@shared/types/api.types';

// 将后端RoomResponse转换为前端Room实体
function mapRoom(data: RoomResponse): Room {
  return {
    id: data.id,
    name: data.name,
    type: data.type,
    createdBy: data.creator_id,
    memberCount: data.members?.length || 0,
    unreadCount: data.unread_count || 0,
    lastMessage: data.last_message ? mapMessage(data.last_message) : undefined,
    createdAt: new Date(data.created_at),
    updatedAt: new Date(data.updated_at),
  };
}

// 将后端MessageResponse转换为前端Message实体
function mapMessage(data: MessageResponse | RoomResponse['last_message']): Message {
  if (!data) {
    throw new Error('Message data is null');
  }
  return {
    id: data.id,
    roomId: data.room_id,
    senderId: data.sender_id,
    sender: {
      id: data.sender_id,
      username: data.sender_name || data.sender_id,
      email: '',
      displayName: data.sender_name || data.sender_id,
      createdAt: new Date(),
      updatedAt: new Date(),
    },
    content: data.content,
    type: data.type,
    mediaUrl: data.media_url,
    mediaType: data.mime_type,
    mediaSize: data.media_size,
    isEdited: false,
    isDeleted: data.is_deleted,
    readBy: [],
    createdAt: new Date(data.created_at),
    updatedAt: new Date(data.created_at),
  };
}

// 消息提示音 - 使用 Web Audio API 生成简单的提示音
let audioContext: AudioContext | null = null;
let audioInitialized = false;

// 初始化音频上下文（需要用户交互后调用）
async function initAudioContext() {
  if (audioInitialized) return;
  try {
    audioContext = new AudioContext();
    // 如果 AudioContext 被挂起，等待用户交互后恢复
    if (audioContext.state === 'suspended') {
      await audioContext.resume();
    }
    audioInitialized = true;
    console.log('AudioContext initialized successfully');
  } catch (e) {
    console.warn('Failed to initialize AudioContext:', e);
  }
}

// 在用户首次交互时初始化音频
if (typeof document !== 'undefined') {
  const initOnInteraction = async () => {
    await initAudioContext();
    document.removeEventListener('click', initOnInteraction);
    document.removeEventListener('keydown', initOnInteraction);
    document.removeEventListener('touchstart', initOnInteraction);
  };
  document.addEventListener('click', initOnInteraction);
  document.addEventListener('keydown', initOnInteraction);
  document.addEventListener('touchstart', initOnInteraction);
}

async function playNotificationSound() {
  try {
    // 如果音频上下文未初始化，尝试初始化
    if (!audioContext) {
      initAudioContext();
    }
    if (!audioContext) return;

    // 如果 AudioContext 被挂起，尝试恢复
    if (audioContext.state === 'suspended') {
      await audioContext.resume();
    }

    const oscillator = audioContext.createOscillator();
    const gainNode = audioContext.createGain();
    oscillator.connect(gainNode);
    gainNode.connect(audioContext.destination);
    oscillator.frequency.setValueAtTime(880, audioContext.currentTime);
    oscillator.frequency.setValueAtTime(660, audioContext.currentTime + 0.1);
    gainNode.gain.setValueAtTime(0.3, audioContext.currentTime);
    gainNode.gain.exponentialRampToValueAtTime(0.01, audioContext.currentTime + 0.3);
    oscillator.start(audioContext.currentTime);
    oscillator.stop(audioContext.currentTime + 0.3);
  } catch (e) {
    console.warn('Failed to play notification sound:', e);
  }
}

interface ChatState {
  rooms: Room[];
  publicRooms: PublicRoomResponse[];
  isLoadingPublicRooms: boolean;
  currentRoom: Room | null;
  messages: Map<string, Message[]>;
  isLoadingRooms: boolean;
  isLoadingMessages: boolean;
  hasMoreMessages: Map<string, boolean>;
  typingUsers: Map<string, string[]>;
  readReceipts: Map<string, Map<string, string>>; // roomId -> userId -> readAt ISO string
  error: string | null;
  
  // Room actions
  fetchRooms: () => Promise<void>;
  fetchPublicRooms: (query?: string) => Promise<void>;
  joinRoom: (roomId: string) => Promise<Room>;
  createRoom: (data: CreateRoomRequest) => Promise<Room>;
  setCurrentRoom: (room: Room | null) => void;
  leaveRoom: (roomId: string) => Promise<void>;
  
  // Message actions
  fetchMessages: (roomId: string, beforeId?: string) => Promise<void>;
  sendMessage: (roomId: string, data: SendMessageRequest) => Promise<void>;
  markAsRead: (roomId: string) => Promise<void>;
  
  // Read receipt actions
  fetchReadReceipts: (roomId: string) => Promise<void>;
  handleReadReceipt: (data: { room_id: string; user_id: string; read_at: string }) => void;
  isMessageRead: (roomId: string, senderId: string, createdAt: Date) => boolean;
  
  // WebSocket event handlers
  handleNewMessage: (message: MessageResponse) => void;
  handleRoomUpdated: (room: RoomResponse) => void;
  handleTyping: (roomId: string, _userId: string, userName: string) => void;
  
  // Listeners
  initializeListeners: () => () => void;
  
  clearError: () => void;
}

export const useChatStore = create<ChatState>((set, get) => ({
  rooms: [],
  publicRooms: [],
  isLoadingPublicRooms: false,
  currentRoom: null,
  messages: new Map(),
  isLoadingRooms: false,
  isLoadingMessages: false,
  hasMoreMessages: new Map(),
  typingUsers: new Map(),
  readReceipts: new Map(),
  error: null,

  fetchRooms: async () => {
    set({ isLoadingRooms: true, error: null });
    try {
      // 后端返回 {rooms: [...]}
      const response = await apiClient.get<RoomsListResponse>(ENDPOINTS.CHAT.ROOMS);
      const rooms = (response.data.rooms || []).map(mapRoom);
      set({ rooms, isLoadingRooms: false });
    } catch (error) {
      const message = error instanceof Error ? error.message : '获取聊天室列表失败';
      set({ error: message, isLoadingRooms: false });
    }
  },

  fetchPublicRooms: async (query?: string) => {
    set({ isLoadingPublicRooms: true, error: null });
    try {
      const params: Record<string, string> = {};
      if (query) params.q = query;
      const response = await apiClient.get<PublicRoomsListResponse>(
        ENDPOINTS.CHAT.PUBLIC_ROOMS,
        { params }
      );
      set({ publicRooms: response.data.rooms || [], isLoadingPublicRooms: false });
    } catch (error) {
      const message = error instanceof Error ? error.message : '获取公开群组失败';
      set({ error: message, isLoadingPublicRooms: false });
    }
  },

  joinRoom: async (roomId: string) => {
    try {
      const response = await apiClient.post<RoomResponse>(ENDPOINTS.CHAT.ROOM_JOIN(roomId));
      const room = mapRoom(response.data);
      set((state) => ({
        rooms: [room, ...state.rooms.filter(r => r.id !== room.id)],
        publicRooms: state.publicRooms.map(r =>
          r.id === roomId ? { ...r, is_member: true, member_count: (r.member_count || 0) + 1 } : r
        ),
      }));
      return room;
    } catch (error) {
      const message = error instanceof Error ? error.message : '加入群组失败';
      set({ error: message });
      throw error;
    }
  },

  createRoom: async (data: CreateRoomRequest) => {
    try {
      // 后端直接返回房间对象
      const response = await apiClient.post<RoomResponse>(ENDPOINTS.CHAT.ROOMS, data);
      const room = mapRoom(response.data);
      set((state) => ({ rooms: [room, ...state.rooms] }));
      return room;
    } catch (error) {
      const message = error instanceof Error ? error.message : '创建聊天室失败';
      set({ error: message });
      throw error;
    }
  },

  setCurrentRoom: (room: Room | null) => {
    set({ currentRoom: room });
    if (room) {
      get().fetchMessages(room.id);
      get().fetchReadReceipts(room.id);
      get().markAsRead(room.id);
    }
  },

  leaveRoom: async (roomId: string) => {
    try {
      await apiClient.post(ENDPOINTS.CHAT.ROOM_LEAVE(roomId));
      set((state) => ({
        rooms: state.rooms.filter(r => r.id !== roomId),
        currentRoom: state.currentRoom?.id === roomId ? null : state.currentRoom,
      }));
    } catch (error) {
      const message = error instanceof Error ? error.message : '离开聊天室失败';
      set({ error: message });
      throw error;
    }
  },

  fetchMessages: async (roomId: string, beforeId?: string) => {
    set({ isLoadingMessages: true, error: null });
    try {
      const params: Record<string, string | number> = { limit: 50 };
      if (beforeId) {
        params.before_id = beforeId;
      }
      // 后端返回 {messages: [...]}
      const response = await apiClient.get<MessagesListResponse>(
        ENDPOINTS.CHAT.ROOM_MESSAGES(roomId),
        { params }
      );
      
      const messagesList = response.data.messages || [];
      const newMessages = messagesList.map(mapMessage);
      
      set((state) => {
        const existingMessages = beforeId ? (state.messages.get(roomId) || []) : [];
        const updatedMessages = new Map(state.messages);
        // Messages from backend are newest-first; append older messages at the end
        updatedMessages.set(roomId, [...existingMessages, ...newMessages]);
        
        const updatedHasMore = new Map(state.hasMoreMessages);
        updatedHasMore.set(roomId, messagesList.length >= 50);
        
        return {
          messages: updatedMessages,
          hasMoreMessages: updatedHasMore,
          isLoadingMessages: false,
        };
      });
    } catch (error) {
      const message = error instanceof Error ? error.message : '获取消息失败';
      set({ error: message, isLoadingMessages: false });
    }
  },

  sendMessage: async (roomId: string, data: SendMessageRequest) => {
    try {
      // 后端直接返回消息对象
      const response = await apiClient.post<MessageResponse>(
        ENDPOINTS.CHAT.ROOM_MESSAGES(roomId),
        data
      );
      
      const newMessage = mapMessage(response.data);
      
      set((state) => {
        const updatedMessages = new Map(state.messages);
        const roomMessages = updatedMessages.get(roomId) || [];
        updatedMessages.set(roomId, [newMessage, ...roomMessages]);
        return { messages: updatedMessages };
      });
    } catch (error) {
      const message = error instanceof Error ? error.message : '发送消息失败';
      set({ error: message });
      throw error;
    }
  },

  markAsRead: async (roomId: string) => {
    try {
      await apiClient.post(ENDPOINTS.CHAT.MARK_READ(roomId));
      set((state) => ({
        rooms: state.rooms.map(room =>
          room.id === roomId ? { ...room, unreadCount: 0 } : room
        ),
      }));
    } catch {
      // 忽略已读标记失败
    }
  },

  fetchReadReceipts: async (roomId: string) => {
    try {
      const response = await apiClient.get<ReadReceiptsListResponse>(
        ENDPOINTS.CHAT.READ_RECEIPTS(roomId)
      );
      const receipts = response.data.read_receipts || [];
      set((state) => {
        const updatedReceipts = new Map(state.readReceipts);
        const roomReceipts = new Map<string, string>();
        for (const r of receipts) {
          roomReceipts.set(r.user_id, r.read_at);
        }
        updatedReceipts.set(roomId, roomReceipts);
        return { readReceipts: updatedReceipts };
      });
    } catch {
      // 忽略获取已读回执失败
    }
  },

  handleReadReceipt: (data: { room_id: string; user_id: string; read_at: string }) => {
    set((state) => {
      const updatedReceipts = new Map(state.readReceipts);
      const roomReceipts = new Map(updatedReceipts.get(data.room_id) || new Map<string, string>());
      roomReceipts.set(data.user_id, data.read_at);
      updatedReceipts.set(data.room_id, roomReceipts);

      // 同时更新房间的未读数（如果是当前用户在其他设备标记已读）
      const updatedRooms = state.rooms.map(room => {
        if (room.id === data.room_id && state.currentRoom?.id === data.room_id) {
          return { ...room, unreadCount: 0 };
        }
        return room;
      });

      return { readReceipts: updatedReceipts, rooms: updatedRooms };
    });
  },

  isMessageRead: (roomId: string, senderId: string, createdAt: Date): boolean => {
    const roomReceipts = get().readReceipts.get(roomId);
    if (!roomReceipts) return false;

    const msgTime = createdAt.getTime();
    for (const [userId, readAt] of roomReceipts) {
      // 跳过消息发送者自己的已读回执
      if (userId === senderId) continue;
      if (new Date(readAt).getTime() >= msgTime) {
        return true;
      }
    }
    return false;
  },

  handleNewMessage: (messageData: MessageResponse) => {
    const message = mapMessage(messageData);
    const { currentRoom } = get();
    
    set((state) => {
      const updatedMessages = new Map(state.messages);
      const roomMessages = updatedMessages.get(message.roomId) || [];
      
      if (!roomMessages.some(m => m.id === message.id)) {
        updatedMessages.set(message.roomId, [message, ...roomMessages]);
      }
      
      const updatedRooms = state.rooms.map(room => {
        if (room.id === message.roomId) {
          return {
            ...room,
            lastMessage: message,
            unreadCount: currentRoom?.id === room.id ? 0 : room.unreadCount + 1,
          };
        }
        return room;
      });
      
      return { messages: updatedMessages, rooms: updatedRooms };
    });
    
    // 不在当前房间时播放提示音
    if (currentRoom?.id !== message.roomId) {
      // 使用 async/await 确保 resume 完成
      playNotificationSound().catch(e => console.warn('Sound play failed:', e));
    } else {
      get().markAsRead(message.roomId);
    }
  },

  handleRoomUpdated: (roomData: RoomResponse) => {
    const room = mapRoom(roomData);
    set((state) => ({
      rooms: state.rooms.map(r => r.id === room.id ? room : r),
      currentRoom: state.currentRoom?.id === room.id ? room : state.currentRoom,
    }));
  },

  handleTyping: (roomId: string, _userId: string, userName: string) => {
    set((state) => {
      const updatedTyping = new Map(state.typingUsers);
      const roomTyping = updatedTyping.get(roomId) || [];
      if (!roomTyping.includes(userName)) {
        updatedTyping.set(roomId, [...roomTyping, userName]);
      }
      return { typingUsers: updatedTyping };
    });
    
    setTimeout(() => {
      set((state) => {
        const updatedTyping = new Map(state.typingUsers);
        const roomTyping = updatedTyping.get(roomId) || [];
        updatedTyping.set(roomId, roomTyping.filter(name => name !== userName));
        return { typingUsers: updatedTyping };
      });
    }, 3000);
  },

  initializeListeners: () => {
    const { handleNewMessage, handleRoomUpdated, handleTyping, handleReadReceipt } = get();
    
    const unsubNewMessage = WebSocketClient.subscribe<MessageResponse>(
      WS_EVENTS.MESSAGE_NEW,
      handleNewMessage
    );
    
    const unsubRoomUpdated = WebSocketClient.subscribe<RoomResponse>(
      WS_EVENTS.ROOM_UPDATED,
      handleRoomUpdated
    );
    
    const unsubTyping = WebSocketClient.subscribe<{ room_id: string; user_id: string; user_name: string }>(
      WS_EVENTS.TYPING,
      (data) => {
        if (data) {
          handleTyping(data.room_id, data.user_id, data.user_name);
        }
      }
    );

    const unsubReadReceipt = WebSocketClient.subscribe<{ room_id: string; user_id: string; read_at: string }>(
      WS_EVENTS.READ_RECEIPT,
      (data) => {
        if (data) {
          handleReadReceipt(data);
        }
      }
    );
    
    return () => {
      unsubNewMessage();
      unsubRoomUpdated();
      unsubTyping();
      unsubReadReceipt();
    };
  },

  clearError: () => set({ error: null }),
}));
