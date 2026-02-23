# Web客户端部署说明

## 安装包信息

- **文件名**: `secure-chat-web-Static-1.0.0.zip`
- **大小**: 347 KB
- **类型**: 静态Web应用（可直接部署到任何Web服务器）

## 部署方式

### 方式一：直接部署到Web服务器

1. 解压 `secure-chat-web-Static-1.0.0.zip`
2. 将解压后的文件复制到Web服务器的根目录或子目录
3. 访问对应URL即可使用

#### 支持的Web服务器：

- **Nginx**
  ```nginx
  server {
      listen 80;
      server_name your-domain.com;
      root /path/to/your/website;
      index index.html;
      
      location / {
          try_files $uri $uri/ /index.html;
      }
      
      # API代理配置（如果需要）
      location /api/ {
          proxy_pass http://backend-server:port;
      }
  }
  ```

- **Apache**
  ```apache
  <VirtualHost *:80>
      ServerName your-domain.com
      DocumentRoot /path/to/your/website
      
      <Directory /path/to/your/website>
          Options -Indexes
          AllowOverride All
          Require all granted
      </Directory>
      
      # SPA路由支持
      RewriteEngine On
      RewriteCond %{REQUEST_FILENAME} !-f
      RewriteCond %{REQUEST_FILENAME} !-d
      RewriteRule ^(.*)$ /index.html [QSA,L]
  </VirtualHost>
  ```

- **Node.js (Express)**
  ```javascript
  const express = require('express');
  const path = require('path');
  const app = express();
  
  app.use(express.static(path.join(__dirname, 'dist')));
  app.get('*', (req, res) => {
      res.sendFile(path.join(__dirname, 'dist', 'index.html'));
  });
  
  app.listen(3000);
  ```

- **IIS**
  - 在IIS管理器中创建新网站
  - 设置物理路径为解压后的目录
  - 安装 URL Rewrite 模块并添加重写规则

### 方式二：使用Python简单HTTP服务器（测试用）

```bash
# Python 3
cd /path/to/your/website
python -m http.server 8080

# Python 2
python -m SimpleHTTPServer 8080
```

访问: `http://localhost:8080`

### 方式三：使用Docker（需要Docker Desktop运行）

1. 在 `web-client` 目录运行：
   ```bash
   docker build -t secure-chat-web:1.0.0 .
   docker run -p 80:80 secure-chat-web:1.0.0
   ```

2. 访问: `http://localhost`

## 配置说明

### 环境配置

在部署前，可能需要修改配置文件：

1. **开发环境配置** (.env.development)
2. **生产环境配置** (.env.production)

配置示例：
```
VITE_API_BASE_URL=https://your-api-server.com
VITE_WS_URL=wss://your-api-server.com/ws
```

### API代理

如果前端和后端不在同一个域名，需要配置API代理：

**Nginx配置示例：**
```nginx
server {
    listen 80;
    server_name your-domain.com;
    
    # 前端静态文件
    location / {
        root /path/to/frontend/dist;
        try_files $uri $uri/ /index.html;
    }
    
    # API代理
    location /api/ {
        proxy_pass http://backend-server:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
    
    # WebSocket代理
    location /ws/ {
        proxy_pass http://backend-server:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

## 功能特性

### 已实现的功能

1. ✅ 用户认证（登录/注册）
2. ✅ 聊天室管理（创建/加入/离开）
3. ✅ 实时消息收发
4. ✅ WebSocket实时通信
5. ✅ 文件上传（图片、文件等）
6. ✅ **粘贴图片功能**（Ctrl+V）
7. ✅ 消息提示音（修复后稳定）
8. ✅ 已读回执
9. ✅ 输入状态显示
10. ✅ 消息历史加载（游标分页）
11. ✅ 用户搜索
12. ✅ 响应式设计

### 最近修复的问题

1. **粘贴图片功能** - 可以在输入框中按 Ctrl+V 直接粘贴剪贴板图片
2. **消息提示音不稳定** - 修复了 AudioContext 初始化和恢复问题，确保提示音稳定播放

## 技术栈

- **前端框架**: React 19.2.0
- **UI组件库**: Ant Design 6.3.0
- **状态管理**: Zustand 5.0.11
- **路由**: React Router DOM 7.13.0
- **HTTP客户端**: Axios 1.13.5
- **WebSocket**: 自定义WebSocket客户端
- **构建工具**: Vite 7.3.1
- **语言**: TypeScript 5.9.3

## 浏览器兼容性

- Chrome/Edge (推荐)
- Firefox
- Safari
- 其他现代浏览器

要求浏览器支持：
- ES6+
- WebSocket
- File API
- Clipboard API（粘贴图片功能）

## 安全注意事项

1. **HTTPS**: 生产环境建议使用HTTPS
2. **CORS**: 配置正确的CORS策略
3. **认证**: 确保API端点有适当的认证机制
4. **文件上传**: 后端需验证上传文件类型和大小
5. **WebSocket**: 使用 WSS 而非 WS

## 常见问题

### Q: 页面无法访问后端API
A: 检查 API_BASE_URL 配置和CORS设置

### Q: WebSocket连接失败
A: 检查 WS_URL 配置，确保支持WSS协议

### Q: 粘贴图片功能不工作
A: 确保浏览器支持Clipboard API，且用户已与页面交互

### Q: 消息提示音不响
A: 检查浏览器音频权限和系统音量设置

## 技术支持

如有问题，请联系技术支持团队。

---

**版本**: 1.0.0  
**更新日期**: 2026-02-23
