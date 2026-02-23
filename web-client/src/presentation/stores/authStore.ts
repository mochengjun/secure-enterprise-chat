import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import type { User } from '@domain/entities/User';
import { apiClient } from '@core/api/client';
import { ENDPOINTS } from '@core/api/endpoints';
import { TokenStorage } from '@core/storage/TokenStorage';
import { WebSocketClient } from '@core/websocket/WebSocketClient';
import type { LoginRequest, LoginResponse, RegisterRequest, RegisterResponse, UserResponse } from '@shared/types/api.types';
import axios from 'axios';

// 从后端UserResponse转换为前端User
function mapUserResponse(data: UserResponse): User {
  return {
    id: data.user_id,
    username: data.username,
    email: data.email,
    displayName: data.display_name || data.username,
    avatarUrl: data.avatar_url,
    createdAt: new Date(data.created_at),
    updatedAt: new Date(data.updated_at),
  };
}

// 从axios错误中提取错误信息
function extractErrorMessage(error: unknown, fallback: string): string {
  if (axios.isAxiosError(error) && error.response?.data?.error) {
    return error.response.data.error;
  }
  if (error instanceof Error) {
    return error.message;
  }
  return fallback;
}

interface AuthState {
  user: User | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  error: string | null;
  
  // Actions
  login: (credentials: LoginRequest) => Promise<void>;
  register: (data: RegisterRequest) => Promise<void>;
  logout: () => Promise<void>;
  fetchCurrentUser: () => Promise<void>;
  clearError: () => void;
  initializeAuth: () => Promise<void>;
}

export const useAuthStore = create<AuthState>()(
  persist(
    (set, get) => ({
      user: null,
      isAuthenticated: false,
      isLoading: false,
      error: null,

      login: async (credentials: LoginRequest) => {
        set({ isLoading: true, error: null });
        try {
          // 后端直接返回 {access_token, refresh_token, expires_in, token_type}
          const response = await apiClient.post<LoginResponse>(
            ENDPOINTS.AUTH.LOGIN,
            credentials
          );
          
          const { access_token, refresh_token } = response.data;
          TokenStorage.setTokens(access_token, refresh_token);
          
          // 设置WebSocket的Token提供者
          WebSocketClient.setTokenProvider(() => TokenStorage.getAccessToken());
          
          // 登录响应不包含用户信息，需要调用/auth/me获取
          const userResponse = await apiClient.get<UserResponse>(ENDPOINTS.AUTH.ME);
          const user = mapUserResponse(userResponse.data);
          
          WebSocketClient.connect();
          
          set({
            user,
            isAuthenticated: true,
            isLoading: false,
          });
        } catch (error) {
          const message = extractErrorMessage(error, '登录失败，请检查用户名和密码');
          set({ error: message, isLoading: false });
          throw error;
        }
      },

      register: async (data: RegisterRequest) => {
        set({ isLoading: true, error: null });
        try {
          // 后端注册不返回token，只返回 {user_id, username, message}
          await apiClient.post<RegisterResponse>(
            ENDPOINTS.AUTH.REGISTER,
            data
          );
          
          // 注册成功后自动登录
          const loginResponse = await apiClient.post<LoginResponse>(
            ENDPOINTS.AUTH.LOGIN,
            { username: data.username, password: data.password }
          );
          
          const { access_token, refresh_token } = loginResponse.data;
          TokenStorage.setTokens(access_token, refresh_token);
          
          // 设置WebSocket的Token提供者
          WebSocketClient.setTokenProvider(() => TokenStorage.getAccessToken());
          
          // 获取用户信息
          const userResponse = await apiClient.get<UserResponse>(ENDPOINTS.AUTH.ME);
          const user = mapUserResponse(userResponse.data);
          
          WebSocketClient.connect();
          
          set({
            user,
            isAuthenticated: true,
            isLoading: false,
          });
        } catch (error) {
          const message = extractErrorMessage(error, '注册失败，请稍后重试');
          set({ error: message, isLoading: false });
          throw error;
        }
      },

      logout: async () => {
        try {
          await apiClient.post(ENDPOINTS.AUTH.LOGOUT);
        } catch {
          // 忽略登出API错误
        } finally {
          TokenStorage.clearTokens();
          WebSocketClient.disconnect();
          set({
            user: null,
            isAuthenticated: false,
            error: null,
          });
        }
      },

      fetchCurrentUser: async () => {
        if (!TokenStorage.hasValidToken()) {
          return;
        }
        
        set({ isLoading: true });
        try {
          // 后端直接返回用户对象（无data包装）
          const response = await apiClient.get<UserResponse>(ENDPOINTS.AUTH.ME);
          set({
            user: mapUserResponse(response.data),
            isAuthenticated: true,
            isLoading: false,
          });
        } catch {
          // Token无效，清除状态
          TokenStorage.clearTokens();
          set({
            user: null,
            isAuthenticated: false,
            isLoading: false,
          });
        }
      },

      clearError: () => {
        set({ error: null });
      },

      initializeAuth: async () => {
        const { fetchCurrentUser } = get();
        
        if (TokenStorage.hasValidToken()) {
          // 设置WebSocket的Token提供者
          WebSocketClient.setTokenProvider(() => TokenStorage.getAccessToken());
          
          await fetchCurrentUser();
          
          // 如果认证成功，连接WebSocket
          if (get().isAuthenticated) {
            WebSocketClient.connect();
          }
        }
      },
    }),
    {
      name: 'auth-storage',
      partialize: (state) => ({
        // 只持久化用户信息，不持久化loading和error状态
        user: state.user,
        isAuthenticated: state.isAuthenticated,
      }),
    }
  )
);
