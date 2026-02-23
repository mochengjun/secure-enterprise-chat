import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import path from 'path'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
      '@core': path.resolve(__dirname, './src/core'),
      '@domain': path.resolve(__dirname, './src/domain'),
      '@data': path.resolve(__dirname, './src/data'),
      '@presentation': path.resolve(__dirname, './src/presentation'),
      '@shared': path.resolve(__dirname, './src/shared'),
    },
  },
  server: {
    port: 3000,
    host: true, // 允许外网访问
    proxy: {
      '/api': {
        target: 'http://172.25.118.254:8081',
        changeOrigin: true,
        ws: true, // 同时代理 WebSocket（/api/v1/ws）
      },
    },
  },
})
