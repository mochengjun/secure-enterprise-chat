---
name: web-client-paste-image
overview: 在Windows前端聊天页面增加粘贴图片功能
todos:
  - id: import-media-upload-hook
    content: 在 ChatRoomPage.tsx 中导入 useMediaUpload hook
    status: completed
  - id: add-paste-handler-state
    content: 添加 paste 处理函数和上传状态状态
    status: completed
    dependencies:
      - import-media-upload-hook
  - id: add-onpaste-to-textarea
    content: 为 Input.TextArea 添加 onPaste 事件处理
    status: completed
    dependencies:
      - add-paste-handler-state
  - id: add-upload-progress-indicator
    content: 添加上传进度显示UI
    status: completed
    dependencies:
      - add-onpaste-to-textarea
---

## 用户需求

在Windows前端聊天页面的输入消息框内增加可以直接粘贴剪贴板里图片的功能。

## 产品概述

这是一个聊天应用的输入增强功能，用户可以在聊天输入框中直接粘贴（Ctrl+V）剪贴板中的图片，系统自动上传并发送图片消息。

## 核心功能

1. 监听输入框的粘贴事件（onPaste）
2. 检测剪贴板中是否包含图片数据
3. 将图片数据转换为File对象并上传
4. 上传成功后自动发送图片消息
5. 支持上传进度显示和错误提示

## 技术栈

- 前端框架: React + TypeScript
- UI组件库: Ant Design (antd)
- 状态管理: React hooks (useState, useCallback)
- 图片上传: 现有 useMediaUpload hook

## 技术方案

### 实现思路

1. 在 ChatRoomPage.tsx 中导入 useMediaUpload hook
2. 为 Input.TextArea 组件添加 onPaste 事件处理
3. 在 onPaste 回调中：

- 检查剪贴板事件中是否包含图片 items
- 获取图片 Blob 数据
- 将 Blob 转换为 File 对象
- 使用 useMediaUpload hook 上传图片
- 上传成功后调用 sendMessage 发送图片消息

### 关键代码逻辑

```typescript
// 1. 导入 hook
import { useMediaUpload } from '@presentation/hooks/useMediaUpload';

// 2. 初始化 hook
const { uploading, progress, uploadFile } = useMediaUpload({
  maxSize: 10, // 图片限制10MB
  acceptTypes: ['image/*'],
});

// 3. 处理粘贴事件
const handlePaste = async (e: React.ClipboardEvent) => {
  const items = e.clipboardData?.items;
  if (!items) return;

  for (const item of items) {
    if (item.type.startsWith('image/')) {
      const blob = item.getAsFile();
      if (blob) {
        // 转换为 File 对象
        const file = new File([blob], `paste_${Date.now()}.png`, { type: blob.type });
        // 上传并发送
        const result = await uploadFile(file);
        if (result && roomId) {
          await sendMessage(roomId, {
            type: 'image',
            content: '',
            mediaUrl: result.url,
            mediaType: result.type,
            mediaSize: result.size,
          });
        }
      }
    }
  }
};
```

### 性能考虑

- 使用 useCallback 缓存处理函数，避免不必要的重渲染
- 上传过程不阻塞输入框继续使用
- 图片上传使用已有的分片上传机制，支持大文件

### 兼容性

- 使用 Clipboard API 的标准写法
- 支持 PNG、JPG、GIF 等常见图片格式