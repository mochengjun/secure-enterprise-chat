import { API_CONFIG, WS_CONFIG } from '@shared/constants/config';
import { WS_EVENTS, type WsEventType } from './events';
import type { WsMessage } from '@shared/types/api.types';

type EventCallback<T = unknown> = (data: T) => void;

class WebSocketClientClass {
  private ws: WebSocket | null = null;
  private reconnectAttempts = 0;
  private heartbeatTimer: ReturnType<typeof setInterval> | null = null;
  private reconnectTimer: ReturnType<typeof setTimeout> | null = null;
  private eventHandlers = new Map<string, Set<EventCallback>>();
  private messageQueue: WsMessage[] = [];
  private isConnecting = false;
  private tokenProvider: (() => string | null) | null = null;

  // 设置Token提供者
  setTokenProvider(provider: () => string | null): void {
    this.tokenProvider = provider;
  }

  // 连接WebSocket
  connect(): void {
    if (this.ws?.readyState === WebSocket.OPEN || this.isConnecting) {
      return;
    }

    const token = this.tokenProvider?.();
    if (!token) {
      console.warn('WebSocket: No token available');
      return;
    }

    this.isConnecting = true;
    const wsUrl = `${API_CONFIG.WS_URL}?token=${token}`;
    
    try {
      this.ws = new WebSocket(wsUrl);
      this.setupEventListeners();
    } catch (error) {
      console.error('WebSocket connection error:', error);
      this.isConnecting = false;
      this.handleReconnect();
    }
  }

  // 设置WebSocket事件监听
  private setupEventListeners(): void {
    if (!this.ws) return;

    this.ws.onopen = () => {
      console.log('WebSocket connected');
      this.isConnecting = false;
      this.reconnectAttempts = 0;
      this.startHeartbeat();
      this.flushMessageQueue();
      this.emit(WS_EVENTS.CONNECTED, null);
    };

    this.ws.onmessage = (event: MessageEvent) => {
      try {
        // 后端可能会合并多条消息用换行符分隔发送，需要分割处理
        const rawData = event.data as string;
        const messages = rawData.split('\n').filter(line => line.trim());
        
        for (const msgStr of messages) {
          try {
            const data = JSON.parse(msgStr) as WsMessage;
            
            // 处理心跳响应
            if (data.type === WS_EVENTS.PONG) {
              continue;
            }
            
            // 触发对应事件
            this.emit(data.type, data.payload);
          } catch (parseError) {
            console.error('WebSocket message parse error:', parseError, 'Raw:', msgStr);
          }
        }
      } catch (error) {
        console.error('WebSocket message handling error:', error);
      }
    };

    this.ws.onerror = (event: Event) => {
      console.error('WebSocket error:', event);
      this.isConnecting = false;
      this.emit(WS_EVENTS.ERROR, event);
    };

    this.ws.onclose = (event: CloseEvent) => {
      console.log('WebSocket closed:', event.code, event.reason);
      this.isConnecting = false;
      this.stopHeartbeat();
      this.emit(WS_EVENTS.DISCONNECTED, { code: event.code, reason: event.reason });
      this.handleReconnect();
    };
  }

  // 发送消息
  send<T>(type: string, payload: T): void {
    const message: WsMessage<T> = {
      type,
      payload,
      timestamp: new Date().toISOString(),
    };

    if (this.ws?.readyState === WebSocket.OPEN) {
      this.ws.send(JSON.stringify(message));
    } else {
      // 离线时加入队列
      this.messageQueue.push(message as WsMessage);
    }
  }

  // 发送消息（原始格式）
  sendRaw(message: WsMessage): void {
    if (this.ws?.readyState === WebSocket.OPEN) {
      this.ws.send(JSON.stringify(message));
    } else {
      this.messageQueue.push(message);
    }
  }

  // 订阅事件
  subscribe<T = unknown>(event: WsEventType | string, callback: EventCallback<T>): () => void {
    if (!this.eventHandlers.has(event)) {
      this.eventHandlers.set(event, new Set());
    }
    this.eventHandlers.get(event)!.add(callback as EventCallback);

    // 返回取消订阅函数
    return () => {
      this.unsubscribe(event, callback as EventCallback);
    };
  }

  // 取消订阅
  unsubscribe(event: WsEventType | string, callback: EventCallback): void {
    this.eventHandlers.get(event)?.delete(callback);
  }

  // 触发事件
  private emit<T>(event: string, data: T): void {
    this.eventHandlers.get(event)?.forEach(handler => {
      try {
        handler(data);
      } catch (error) {
        console.error(`WebSocket event handler error for ${event}:`, error);
      }
    });
  }

  // 开始心跳
  private startHeartbeat(): void {
    this.stopHeartbeat();
    this.heartbeatTimer = setInterval(() => {
      if (this.ws?.readyState === WebSocket.OPEN) {
        this.send(WS_EVENTS.PING, {});
      }
    }, WS_CONFIG.HEARTBEAT_INTERVAL);
  }

  // 停止心跳
  private stopHeartbeat(): void {
    if (this.heartbeatTimer) {
      clearInterval(this.heartbeatTimer);
      this.heartbeatTimer = null;
    }
  }

  // 处理重连
  private handleReconnect(): void {
    if (this.reconnectTimer) {
      return;
    }

    if (this.reconnectAttempts >= WS_CONFIG.MAX_RECONNECT_ATTEMPTS) {
      console.log('WebSocket: Max reconnect attempts reached');
      this.emit(WS_EVENTS.DISCONNECTED, { permanent: true });
      return;
    }

    const delay = WS_CONFIG.RECONNECT_DELAY * Math.pow(1.5, this.reconnectAttempts);
    this.reconnectAttempts++;
    
    console.log(`WebSocket: Reconnecting in ${delay}ms (attempt ${this.reconnectAttempts})`);
    this.emit(WS_EVENTS.RECONNECTING, { attempt: this.reconnectAttempts });

    this.reconnectTimer = setTimeout(() => {
      this.reconnectTimer = null;
      this.connect();
    }, delay);
  }

  // 刷新消息队列
  private flushMessageQueue(): void {
    while (this.messageQueue.length > 0) {
      const message = this.messageQueue.shift();
      if (message && this.ws?.readyState === WebSocket.OPEN) {
        this.ws.send(JSON.stringify(message));
      }
    }
  }

  // 断开连接
  disconnect(): void {
    this.stopHeartbeat();
    
    if (this.reconnectTimer) {
      clearTimeout(this.reconnectTimer);
      this.reconnectTimer = null;
    }

    if (this.ws) {
      this.ws.close(1000, 'Client disconnect');
      this.ws = null;
    }

    this.reconnectAttempts = 0;
    this.messageQueue = [];
  }

  // 获取连接状态
  isConnected(): boolean {
    return this.ws?.readyState === WebSocket.OPEN;
  }

  // 获取连接状态
  getReadyState(): number {
    return this.ws?.readyState ?? WebSocket.CLOSED;
  }
}

export const WebSocketClient = new WebSocketClientClass();
