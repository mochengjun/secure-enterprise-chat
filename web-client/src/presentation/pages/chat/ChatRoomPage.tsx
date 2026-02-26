import { useEffect, useRef, useState, useCallback, useMemo, memo } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { Layout, Input, Button, Avatar, Typography, Spin, Empty, Tooltip, Upload, message, Dropdown, Modal } from 'antd';
import type { MenuProps } from 'antd';
import {
  SendOutlined,
  ArrowLeftOutlined,
  PictureOutlined,
  PaperClipOutlined,
  SmileOutlined,
  UserOutlined,
  TeamOutlined,
  SettingOutlined,
  CheckOutlined,
  CopyOutlined,
  FileOutlined,
  PlayCircleOutlined,
} from '@ant-design/icons';
import { useChatStore } from '@presentation/stores/chatStore';
import { useAuthStore } from '@presentation/stores/authStore';
import AuthImage from '@presentation/components/chat/AuthImage';
import type { Message } from '@domain/entities/Message';
import dayjs from 'dayjs';
import { useMediaUpload } from '@presentation/hooks/useMediaUpload';
import { formatToBeijingDateTime, formatChatMessageTime, getDateSeparatorText } from '@shared/utils/timeUtils';

const { Header, Content, Footer } = Layout;
const { Text, Paragraph } = Typography;

// ==================== 常量样式定义 ====================
// 提取为常量，避免每次渲染创建新对象
const STYLES = {
  messageContainer: {
    display: 'flex',
    padding: '4px 16px',
    gap: 8,
  },
  messageBubble: {
    maxWidth: '70%',
    display: 'flex',
    flexDirection: 'column' as const,
  },
  messageBubbleOwn: {
    alignItems: 'flex-end' as const,
  },
  messageBubbleOther: {
    alignItems: 'flex-start' as const,
  },
  avatar: {
    backgroundColor: '#667eea',
    flexShrink: 0,
  },
  dateSeparator: {
    textAlign: 'center' as const,
    padding: '16px 0',
  },
  dateSeparatorText: {
    background: '#f0f0f0',
    padding: '4px 12px',
    borderRadius: 12,
    fontSize: 12,
  },
  messageText: {
    margin: 0,
    whiteSpace: 'pre-wrap' as const,
    wordBreak: 'break-word' as const,
    color: 'inherit',
  },
  timestamp: {
    fontSize: 11,
    marginTop: 2,
    display: 'flex',
    alignItems: 'center' as const,
    gap: 4,
  },
  header: {
    background: '#fff',
    padding: '0 16px',
    display: 'flex',
    alignItems: 'center',
    gap: 12,
    boxShadow: '0 1px 4px rgba(0,0,0,0.08)',
    height: 56,
  },
  footer: {
    background: '#fff',
    padding: '12px 16px',
    borderTop: '1px solid #f0f0f0',
  },
  inputContainer: {
    display: 'flex',
    gap: 8,
    alignItems: 'flex-end' as const,
  },
  typingIndicator: {
    padding: '4px 16px',
    background: '#fff',
    borderTop: '1px solid #f0f0f0',
  },
  emptyContainer: {
    height: '100%',
    display: 'flex',
    justifyContent: 'center',
    alignItems: 'center',
  },
  messagesContent: {
    flex: 1,
    overflow: 'auto',
    padding: '8px 0',
    display: 'flex',
    flexDirection: 'column-reverse' as const,
  },
  loadMoreContainer: {
    textAlign: 'center' as const,
    padding: 16,
  },
  loadingContainer: {
    textAlign: 'center' as const,
    padding: 40,
  },
  imageCaption: {
    margin: '4px 0 0 0',
    fontSize: 12,
  },
  fileInfo: {
    display: 'flex',
    alignItems: 'center',
    gap: 8,
  },
};

// ==================== 消息项组件 ====================
interface MessageItemProps {
  msg: Message;
  prevMsg?: Message;
  isOwnMessage: boolean;
  showDateSeparator: boolean;
  onCopy: (content: string) => void;
  onImageClick: (url: string) => void;
  formatFullTime: (date: Date) => string;
  formatChatTime: (date: Date) => string;
  formatDateSeparator: (date: Date) => string;
  isRead?: boolean;
  userId?: string;
}

const MessageItem = memo(function MessageItem({
  msg,
  prevMsg: _prevMsg, // 重命名以避免未使用警告，showDateSeparator 已包含判断结果
  isOwnMessage,
  showDateSeparator,
  onCopy,
  onImageClick,
  formatFullTime,
  formatChatTime,
  formatDateSeparator,
  isRead,
  userId,
}: MessageItemProps) {
  // prevMsg 用于计算 showDateSeparator，已在父组件中处理
  // 右键菜单项
  const contextMenuItems: MenuProps['items'] = useMemo(() => [
    {
      key: 'copy',
      label: '复制',
      icon: <CopyOutlined />,
      onClick: () => onCopy(msg.content),
    },
  ], [msg.content, onCopy]);

  // 消息气泡样式
  const bubbleStyle = useMemo(() => ({
    ...STYLES.messageBubble,
    ...(isOwnMessage ? STYLES.messageBubbleOwn : STYLES.messageBubbleOther),
  }), [isOwnMessage]);

  // 内联气泡样式
  const innerBubbleStyle = useMemo(() => ({
    background: isOwnMessage ? '#667eea' : '#fff',
    color: isOwnMessage ? '#fff' : '#1a1a1a',
    padding: msg.type === 'image' ? '6px' : '10px 14px',
    borderRadius: isOwnMessage ? '16px 16px 4px 16px' : '16px 16px 16px 4px',
    boxShadow: '0 1px 2px rgba(0,0,0,0.08)',
    cursor: 'context-menu',
  }), [isOwnMessage, msg.type]);

  // 渲染消息内容
  const messageContent = useMemo(() => {
    switch (msg.type) {
      case 'image':
        return (
          <div style={{ cursor: 'pointer' }}>
            <AuthImage
              src={msg.mediaUrl}
              alt={msg.content || '图片'}
              onClick={() => msg.mediaUrl && onImageClick(msg.mediaUrl)}
            />
            {msg.content && (
              <Paragraph style={{
                ...STYLES.imageCaption,
                color: isOwnMessage ? 'rgba(255,255,255,0.8)' : '#666',
              }}>
                {msg.content}
              </Paragraph>
            )}
          </div>
        );
      case 'file':
        return (
          <div style={STYLES.fileInfo}>
            <FileOutlined style={{ fontSize: 24 }} />
            <div>
              <div>{msg.content || '文件'}</div>
              {msg.mediaSize && (
                <Text type="secondary" style={{ fontSize: 12, color: isOwnMessage ? 'rgba(255,255,255,0.7)' : undefined }}>
                  {(msg.mediaSize / 1024).toFixed(1)} KB
                </Text>
              )}
            </div>
          </div>
        );
      case 'video':
        return (
          <div style={STYLES.fileInfo}>
            <PlayCircleOutlined style={{ fontSize: 24 }} />
            <span>{msg.content || '视频'}</span>
          </div>
        );
      default:
        return (
          <Paragraph style={STYLES.messageText}>
            {msg.content}
          </Paragraph>
        );
    }
  }, [msg, isOwnMessage, onImageClick]);

  return (
    <div>
      {showDateSeparator && (
        <div style={STYLES.dateSeparator}>
          <Text type="secondary" style={STYLES.dateSeparatorText}>
            {formatDateSeparator(msg.createdAt)}
          </Text>
        </div>
      )}
      
      <div style={{
        ...STYLES.messageContainer,
        justifyContent: isOwnMessage ? 'flex-end' : 'flex-start',
      }}>
        {!isOwnMessage && (
          <Avatar
            size={36}
            src={msg.sender.avatarUrl}
            icon={<UserOutlined />}
            style={STYLES.avatar}
          />
        )}
        
        <div style={bubbleStyle}>
          {!isOwnMessage && (
            <Text type="secondary" style={{ fontSize: 12, marginBottom: 2 }}>
              {msg.sender.displayName}
            </Text>
          )}
          
          <Dropdown menu={{ items: contextMenuItems }} trigger={['contextMenu']}>
            <div style={innerBubbleStyle}>
              {messageContent}
            </div>
          </Dropdown>
          
          <Tooltip title={formatFullTime(msg.createdAt)}>
            <Text type="secondary" style={STYLES.timestamp}>
              {formatChatTime(msg.createdAt)}
              {msg.isEdited && ' (已编辑)'}
              {isOwnMessage && userId && (
                isRead ? (
                  <span style={{ display: 'inline-flex', alignItems: 'center', color: '#667eea' }}>
                    <CheckOutlined style={{ fontSize: 10 }} />
                    <CheckOutlined style={{ fontSize: 10, marginLeft: -6 }} />
                  </span>
                ) : (
                  <CheckOutlined style={{ fontSize: 10, color: '#999' }} />
                )
              )}
            </Text>
          </Tooltip>
        </div>
        
        {isOwnMessage && (
          <Avatar
            size={36}
            src={userId}
            icon={<UserOutlined />}
            style={STYLES.avatar}
          />
        )}
      </div>
    </div>
  );
});

// ==================== 主组件 ====================
export function ChatRoomPage() {
  const { roomId } = useParams<{ roomId: string }>();
  const navigate = useNavigate();
  const user = useAuthStore((state) => state.user);
  
  // 使用选择器只订阅需要的状态，减少不必要的重渲染
  const currentRoom = useChatStore((state) => state.currentRoom);
  const isLoadingMessages = useChatStore((state) => state.isLoadingMessages);
  const rooms = useChatStore((state) => state.rooms);
  const fetchMessages = useChatStore((state) => state.fetchMessages);
  const sendMessage = useChatStore((state) => state.sendMessage);
  const setCurrentRoom = useChatStore((state) => state.setCurrentRoom);
  const isMessageRead = useChatStore((state) => state.isMessageRead);
  
  // 使用 useMemo 缓存 Map 查找结果
  const messagesMap = useChatStore((state) => state.messages);
  const hasMoreMessagesMap = useChatStore((state) => state.hasMoreMessages);
  const typingUsersMap = useChatStore((state) => state.typingUsers);
  
  const roomMessages = useMemo(() => 
    roomId ? (messagesMap.get(roomId) || []) : [],
    [roomId, messagesMap]
  );
  
  const canLoadMore = useMemo(() =>
    roomId ? (hasMoreMessagesMap.get(roomId) ?? true) : false,
    [roomId, hasMoreMessagesMap]
  );
  
  const roomTypingUsers = useMemo(() =>
    roomId ? (typingUsersMap.get(roomId) || []) : [],
    [roomId, typingUsersMap]
  );

  const [inputValue, setInputValue] = useState('');
  const [isSending, setIsSending] = useState(false);
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const messagesContainerRef = useRef<HTMLDivElement>(null);
  const [isInitialLoad, setIsInitialLoad] = useState(true);
  const [previewImage, setPreviewImage] = useState<string | null>(null);
  const [uploadingImage, setUploadingImage] = useState(false);

  // 图片上传
  const { uploadFile, progress } = useMediaUpload();

  // 获取当前房间
  useEffect(() => {
    if (roomId) {
      const room = rooms.find(r => r.id === roomId);
      if (room) {
        setCurrentRoom(room);
      }
    }
    return () => {
      setCurrentRoom(null);
    };
  }, [roomId, rooms, setCurrentRoom]);

  // 滚动到底部 - 使用 instant 而非 smooth 提高性能
  const scrollToBottom = useCallback(() => {
    // 使用 instant 模式避免平滑滚动的性能开销
    messagesEndRef.current?.scrollIntoView({ behavior: 'instant' });
  }, []);

  useEffect(() => {
    if (!isLoadingMessages && isInitialLoad) {
      scrollToBottom();
      setIsInitialLoad(false);
    }
  }, [isLoadingMessages, isInitialLoad, scrollToBottom]);

  // 加载更多消息
  const handleLoadMore = useCallback(async () => {
    if (roomId && canLoadMore && !isLoadingMessages && roomMessages.length > 0) {
      const oldestMessage = roomMessages[roomMessages.length - 1];
      await fetchMessages(roomId, oldestMessage.id);
    }
  }, [roomId, canLoadMore, isLoadingMessages, roomMessages, fetchMessages]);

  // 发送消息
  const handleSend = useCallback(async () => {
    if (!inputValue.trim() || !roomId || isSending) return;

    setIsSending(true);
    try {
      await sendMessage(roomId, { content: inputValue.trim(), type: 'text' });
      setInputValue('');
      // 使用 requestAnimationFrame 避免阻塞 UI
      requestAnimationFrame(() => scrollToBottom());
    } catch {
      message.error('发送消息失败');
    } finally {
      setIsSending(false);
    }
  }, [inputValue, roomId, isSending, sendMessage, scrollToBottom]);

  // 处理键盘事件
  const handleKeyPress = useCallback((e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSend();
    }
  }, [handleSend]);

  // 处理粘贴事件
  const handlePaste = useCallback(async (e: React.ClipboardEvent<HTMLTextAreaElement>) => {
    const items = e.clipboardData?.items;
    if (!items) return;

    for (let i = 0; i < items.length; i++) {
      const item = items[i];
      if (item.type.indexOf('image') !== -1) {
        e.preventDefault();
        
        const file = item.getAsFile();
        if (!file || !roomId) return;

        try {
          setUploadingImage(true);
          
          const uploadResult = await uploadFile(file as any);
          
          if (!uploadResult) {
            message.error('图片上传失败');
            return;
          }
          
          await sendMessage(roomId, {
            content: file.name, 
            type: 'image', 
            media_id: uploadResult.id,
          });
          requestAnimationFrame(() => scrollToBottom());
        } catch (error: any) {
          message.error(`图片上传失败: ${error.message}`);
        } finally {
          setUploadingImage(false);
        }
        
        break;
      }
    }
  }, [roomId, uploadFile, sendMessage, scrollToBottom]);

  // 格式化函数 - 使用 useCallback 缓存
  const formatFullTime = useCallback((date: Date) => {
    return formatToBeijingDateTime(date);
  }, []);

  const formatChatTime = useCallback((date: Date) => {
    return formatChatMessageTime(date);
  }, []);

  const formatDateSeparator = useCallback((date: Date) => {
    return getDateSeparatorText(date);
  }, []);

  // 复制消息
  const handleCopyMessage = useCallback((content: string) => {
    navigator.clipboard.writeText(content).then(() => {
      message.success('已复制到剪贴板');
    }).catch(() => {
      message.error('复制失败');
    });
  }, []);

  // 图片点击
  const handleImageClick = useCallback((url: string) => {
    setPreviewImage(url);
  }, []);

  // 检查日期分隔符 - 使用 useCallback
  const checkDateSeparator = useCallback((currentMsg: Message, prevMsg?: Message) => {
    if (!prevMsg) return true;
    const currentDate = dayjs(currentMsg.createdAt).tz('Asia/Shanghai');
    const prevDate = dayjs(prevMsg.createdAt).tz('Asia/Shanghai');
    return !currentDate.isSame(prevDate, 'day');
  }, []);

  // 预计算消息属性
  const messageItems = useMemo(() => {
    return roomMessages.map((msg, index) => {
      const prevMsg = roomMessages[index + 1];
      const isOwnMessage = msg.senderId === user?.id;
      const showDateSeparator = checkDateSeparator(msg, prevMsg);
      const isRead = roomId ? isMessageRead(roomId, msg.senderId, msg.createdAt) : false;
      
      return {
        msg,
        prevMsg,
        isOwnMessage,
        showDateSeparator,
        isRead,
      };
    });
  }, [roomMessages, user?.id, checkDateSeparator, roomId, isMessageRead]);

  // 输入状态显示文本
  const typingText = useMemo(() => {
    if (roomTypingUsers.length === 0) return null;
    return `${roomTypingUsers.join(', ')} 正在输入...`;
  }, [roomTypingUsers]);

  // 关闭预览
  const closePreview = useCallback(() => setPreviewImage(null), []);

  if (!currentRoom) {
    return (
      <div style={STYLES.emptyContainer}>
        <Empty description="请选择一个聊天室" />
      </div>
    );
  }

  return (
    <Layout style={{ height: '100%', background: '#f5f5f5' }}>
      {/* 头部 */}
      <Header style={STYLES.header}>
        <Button
          type="text"
          icon={<ArrowLeftOutlined />}
          onClick={() => navigate('/chat')}
        />
        <Avatar
          size={40}
          src={currentRoom.avatarUrl}
          icon={currentRoom.type === 'direct' ? <UserOutlined /> : <TeamOutlined />}
          style={STYLES.avatar}
        />
        <div style={{ flex: 1 }}>
          <Text strong style={{ display: 'block' }}>{currentRoom.name}</Text>
          <Text type="secondary" style={{ fontSize: 12 }}>
            {currentRoom.memberCount} 成员
          </Text>
        </div>
        <Button
          type="text"
          icon={<SettingOutlined />}
          onClick={() => navigate(`/chat/${roomId}/members`)}
        />
      </Header>

      {/* 消息列表 */}
      <Content ref={messagesContainerRef} style={STYLES.messagesContent}>
        <div ref={messagesEndRef} />
        
        {messageItems.map(({ msg, prevMsg, isOwnMessage, showDateSeparator, isRead }) => (
          <MessageItem
            key={msg.id}
            msg={msg}
            prevMsg={prevMsg}
            isOwnMessage={isOwnMessage}
            showDateSeparator={showDateSeparator}
            onCopy={handleCopyMessage}
            onImageClick={handleImageClick}
            formatFullTime={formatFullTime}
            formatChatTime={formatChatTime}
            formatDateSeparator={formatDateSeparator}
            isRead={isRead}
            userId={user?.avatarUrl}
          />
        ))}
        
        {canLoadMore && (
          <div style={STYLES.loadMoreContainer}>
            <Button
              type="link"
              onClick={handleLoadMore}
              loading={isLoadingMessages}
            >
              加载更多消息
            </Button>
          </div>
        )}
        
        {isLoadingMessages && roomMessages.length === 0 && (
          <div style={STYLES.loadingContainer}>
            <Spin />
          </div>
        )}
      </Content>

      {/* 输入状态提示 */}
      {typingText && (
        <div style={STYLES.typingIndicator}>
          <Text type="secondary" style={{ fontSize: 12 }}>
            {typingText}
          </Text>
        </div>
      )}

      {/* 输入框 */}
      <Footer style={STYLES.footer}>
        <div style={STYLES.inputContainer}>
          <Upload showUploadList={false} disabled>
            <Button type="text" icon={<PictureOutlined />} />
          </Upload>
          <Upload showUploadList={false} disabled>
            <Button type="text" icon={<PaperClipOutlined />} />
          </Upload>
          <Button type="text" icon={<SmileOutlined />} disabled />
          
          <div style={{ position: 'relative', flex: 1 }}>
            <Input.TextArea
              value={inputValue}
              onChange={(e) => setInputValue(e.target.value)}
              onKeyDown={handleKeyPress}
              onPaste={handlePaste}
              placeholder="输入消息...（支持 Ctrl+V 粘贴图片）"
              autoSize={{ minRows: 1, maxRows: 4 }}
              style={{ width: '100%', resize: 'none' }}
            />
            
            {uploadingImage && (
              <div style={{ 
                position: 'absolute', 
                right: 12, 
                top: 12, 
                display: 'flex', 
                alignItems: 'center',
                background: 'rgba(0, 0, 0, 0.5)', 
                padding: '4px 8px', 
                borderRadius: 12 
              }}>
                <Spin size="small" />
                <span style={{ color: '#fff', fontSize: 12, marginLeft: 6 }}>
                  上传中 {progress}%
                </span>
              </div>
            )}
          </div>
          
          <Button
            type="primary"
            icon={<SendOutlined />}
            onClick={handleSend}
            loading={isSending}
            disabled={!inputValue.trim()}
          >
            发送
          </Button>
        </div>
      </Footer>

      {/* 图片预览模态框 */}
      <Modal
        open={!!previewImage}
        footer={null}
        onCancel={closePreview}
        width="auto"
        centered
        styles={{ body: { padding: 0, textAlign: 'center' } }}
      >
        {previewImage && <AuthImage src={previewImage} style={{ maxWidth: '80vw', maxHeight: '80vh', borderRadius: 0 }} />}
      </Modal>
    </Layout>
  );
}
