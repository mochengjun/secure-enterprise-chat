import { create } from 'zustand';
import { WebSocketClient } from '@core/websocket/WebSocketClient';
import { WS_EVENTS } from '@core/websocket/events';

type ConnectionStatus = 'disconnected' | 'connecting' | 'connected' | 'reconnecting';

interface WsState {
  status: ConnectionStatus;
  reconnectAttempt: number;
  error: string | null;
  
  // Actions
  setStatus: (status: ConnectionStatus) => void;
  setReconnectAttempt: (attempt: number) => void;
  setError: (error: string | null) => void;
  initializeListeners: () => () => void;
}

export const useWsStore = create<WsState>((set) => ({
  status: 'disconnected',
  reconnectAttempt: 0,
  error: null,

  setStatus: (status) => set({ status }),
  setReconnectAttempt: (attempt) => set({ reconnectAttempt: attempt }),
  setError: (error) => set({ error }),

  initializeListeners: () => {
    const unsubConnected = WebSocketClient.subscribe(WS_EVENTS.CONNECTED, () => {
      set({ status: 'connected', reconnectAttempt: 0, error: null });
    });

    const unsubDisconnected = WebSocketClient.subscribe<{ permanent?: boolean }>(
      WS_EVENTS.DISCONNECTED,
      (data) => {
        if (data?.permanent) {
          set({ status: 'disconnected', error: '连接已断开，请刷新页面' });
        } else {
          set({ status: 'disconnected' });
        }
      }
    );

    const unsubReconnecting = WebSocketClient.subscribe<{ attempt: number }>(
      WS_EVENTS.RECONNECTING,
      (data) => {
        set({ status: 'reconnecting', reconnectAttempt: data?.attempt || 0 });
      }
    );

    const unsubError = WebSocketClient.subscribe(WS_EVENTS.ERROR, () => {
      set({ error: 'WebSocket连接错误' });
    });

    // 返回清理函数
    return () => {
      unsubConnected();
      unsubDisconnected();
      unsubReconnecting();
      unsubError();
    };
  },
}));
