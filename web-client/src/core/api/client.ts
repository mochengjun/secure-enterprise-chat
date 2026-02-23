import axios from 'axios';
import type { AxiosInstance, InternalAxiosRequestConfig, AxiosResponse, AxiosError } from 'axios';
import { API_CONFIG } from '@shared/constants/config';
import { TokenStorage } from '@core/storage/TokenStorage';
import { ENDPOINTS } from './endpoints';
import type { LoginResponse } from '@shared/types/api.types';

// 创建Axios实例
const apiClient: AxiosInstance = axios.create({
  baseURL: API_CONFIG.BASE_URL,
  timeout: API_CONFIG.TIMEOUT,
  headers: {
    'Content-Type': 'application/json',
  },
});

// 是否正在刷新Token
let isRefreshing = false;
// 等待Token刷新的请求队列
let refreshSubscribers: ((token: string) => void)[] = [];

// 订阅Token刷新
const subscribeTokenRefresh = (cb: (token: string) => void) => {
  refreshSubscribers.push(cb);
};

// 通知所有订阅者
const onTokenRefreshed = (token: string) => {
  refreshSubscribers.forEach(cb => cb(token));
  refreshSubscribers = [];
};

// 请求拦截器：添加Authorization Header
apiClient.interceptors.request.use(
  (config: InternalAxiosRequestConfig) => {
    const token = TokenStorage.getAccessToken();
    if (token && config.headers) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error: AxiosError) => {
    return Promise.reject(error);
  }
);

// 响应拦截器：处理401错误和Token刷新
apiClient.interceptors.response.use(
  (response: AxiosResponse) => {
    return response;
  },
  async (error: AxiosError) => {
    const originalRequest = error.config as InternalAxiosRequestConfig & { _retry?: boolean };
    
    // 如果是401错误且未重试过
    if (error.response?.status === 401 && !originalRequest._retry) {
      // 如果是登录或刷新接口，直接返回错误
      if (originalRequest.url?.includes('/auth/login') || 
          originalRequest.url?.includes('/auth/refresh')) {
        return Promise.reject(error);
      }

      if (isRefreshing) {
        // 如果正在刷新，等待刷新完成后重试
        return new Promise((resolve) => {
          subscribeTokenRefresh((token: string) => {
            if (originalRequest.headers) {
              originalRequest.headers.Authorization = `Bearer ${token}`;
            }
            resolve(apiClient(originalRequest));
          });
        });
      }

      originalRequest._retry = true;
      isRefreshing = true;

      try {
        const refreshToken = TokenStorage.getRefreshToken();
        if (!refreshToken) {
          throw new Error('No refresh token');
        }

        // 后端直接返回 {access_token, refresh_token, ...}
        const response = await axios.post<LoginResponse>(
          `${API_CONFIG.BASE_URL}${ENDPOINTS.AUTH.REFRESH}`,
          { refresh_token: refreshToken }
        );

        const { access_token, refresh_token } = response.data;
        TokenStorage.setTokens(access_token, refresh_token);
        
        // 通知所有等待的请求
        onTokenRefreshed(access_token);
        
        // 重试原请求
        if (originalRequest.headers) {
          originalRequest.headers.Authorization = `Bearer ${access_token}`;
        }
        return apiClient(originalRequest);
      } catch (refreshError) {
        // 刷新失败，清除Token并跳转登录页
        TokenStorage.clearTokens();
        window.location.href = '/login';
        return Promise.reject(refreshError);
      } finally {
        isRefreshing = false;
      }
    }

    return Promise.reject(error);
  }
);

export { apiClient };
