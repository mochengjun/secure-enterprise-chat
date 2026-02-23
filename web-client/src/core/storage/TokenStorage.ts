import { TOKEN_CONFIG } from '@shared/constants/config';

class TokenStorageClass {
  private accessToken: string | null = null;

  // 获取AccessToken（优先从内存）
  getAccessToken(): string | null {
    if (this.accessToken) {
      return this.accessToken;
    }
    // 降级到localStorage（页面刷新后）
    return localStorage.getItem(TOKEN_CONFIG.ACCESS_TOKEN_KEY);
  }

  // 设置AccessToken（存内存，备份到localStorage）
  setAccessToken(token: string): void {
    this.accessToken = token;
    localStorage.setItem(TOKEN_CONFIG.ACCESS_TOKEN_KEY, token);
  }

  // 获取RefreshToken
  getRefreshToken(): string | null {
    return localStorage.getItem(TOKEN_CONFIG.REFRESH_TOKEN_KEY);
  }

  // 设置RefreshToken
  setRefreshToken(token: string): void {
    localStorage.setItem(TOKEN_CONFIG.REFRESH_TOKEN_KEY, token);
  }

  // 设置所有Token
  setTokens(accessToken: string, refreshToken: string): void {
    this.setAccessToken(accessToken);
    this.setRefreshToken(refreshToken);
  }

  // 清除所有Token
  clearTokens(): void {
    this.accessToken = null;
    localStorage.removeItem(TOKEN_CONFIG.ACCESS_TOKEN_KEY);
    localStorage.removeItem(TOKEN_CONFIG.REFRESH_TOKEN_KEY);
  }

  // 检查是否有有效Token
  hasValidToken(): boolean {
    return !!this.getAccessToken();
  }

  // 检查是否有RefreshToken
  hasRefreshToken(): boolean {
    return !!this.getRefreshToken();
  }
}

export const TokenStorage = new TokenStorageClass();
