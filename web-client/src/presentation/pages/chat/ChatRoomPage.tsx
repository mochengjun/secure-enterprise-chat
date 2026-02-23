import { useEffect, useRef, useState, useCallback } from 'react';
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

const { Header, Content, Footer } = Layout;
const { Text, Paragraph } = Typography;

export function ChatRoomPage() {
  const { roomId } = useParams<{ roomId: string }>();
  const navigate = useNavigate();
  const { user } = useAuthStore();
  const {
    currentRoom,
    messages,
    isLoadingMessages,
    hasMoreMessages,
    typingUsers,
    fetchMessages,
    sendMessage,
    setCurrentRoom,
    rooms,
    isMessageRead,
  } = useChatStore();

  const [inputValue, setInputValue] = useState('');
  const [isSending, setIsSending] = useState(false);
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const messagesContainerRef = useRef<HTMLDivElement>(null);
  const [isInitialLoad, setIsInitialLoad] = useState(true);
  const [previewImage, setPreviewImage] = useState<string | null>(null);

  // 图片上传
  const { uploadFile } = useMediaUpload();

  // 获取当前房间和消息
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

  // 滚动到底部
  const scrollToBottom = useCallback(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, []);

  useEffect(() => {
    if (!isLoadingMessages && isInitialLoad) {
      scrollToBottom();
      setIsInitialLoad(false);
    }
  }, [isLoadingMessages, isInitialLoad, scrollToBottom]);

  // 获取房间消息
  const roomMessages = roomId ? (messages.get(roomId) || []) : [];
  const canLoadMore = roomId ? (hasMoreMessages.get(roomId) ?? true) : false;
  const roomTypingUsers = roomId ? (typingUsers.get(roomId) || []) : [];

  // 加载更多消息（游标分页）
  const handleLoadMore = async () => {
    if (roomId && canLoadMore && !isLoadingMessages && roomMessages.length > 0) {
      // 获取最后一条（最老的）消息ID作为游标
      const oldestMessage = roomMessages[roomMessages.length - 1];
      await fetchMessages(roomId, oldestMessage.id);
    }
  };

  // 发送消息
  const handleSend = async () => {
    if (!inputValue.trim() || !roomId || isSending) return;

    setIsSending(true);
    try {
      await sendMessage(roomId, { content: inputValue.trim(), type: 'text' });
      setInputValue('');
      scrollToBottom();
    } catch {
      message.error('发送消息失败');
    } finally {
      setIsSending(false);
    }
  };

  // 处理键盘事件
  const handleKeyPress = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSend();
    }
  };

  // 处理粘贴事件（支持粘贴图片）
  const handlePaste = async (e: React.ClipboardEvent<HTMLTextAreaElement>) => {
    const items = e.clipboardData?.items;
    if (!items) return;

    // 查找剪贴板中的图片
    for (let i = 0; i < items.length; i++) {
      const item = items[i];
      if (item.type.indexOf('image') !== -1) {
        e.preventDefault();
        
        const file = item.getAsFile();
        if (!file || !roomId) return;

        try {
          message.loading({ content: '正在上传图片...', key: 'upload', duration: 0 });
          const mediaResponse = await uploadFile(file as any);
          message.destroy('upload');
          
          if (!mediaResponse) {
            message.error('图片上传失败');
            return;
          }
          
          message.success('图片上传成功');
          
          // 自动发送图片消息
          await sendMessage(roomId, { content: file.name, type: 'image', media_id: mediaResponse.id });
          scrollToBottom();
        } catch (error) {
          message.destroy('upload');
          message.error('图片上传失败');
        }
        
        break;
      }
    }
  };

  // 格式化消息时间
  const formatMessageTime = (date: Date) => {
    return dayjs(date).format('HH:mm');
  };

  // 检查是否需要显示日期分隔符
  const shouldShowDateSeparator = (currentMsg: Message, prevMsg?: Message) => {
    if (!prevMsg) return true;
    return !dayjs(currentMsg.createdAt).isSame(prevMsg.createdAt, 'day');
  };

  // 格式化日期分隔符
  const formatDateSeparator = (date: Date) => {
    const today = dayjs();
    const msgDate = dayjs(date);
    
    if (msgDate.isSame(today, 'day')) {
      return '今天';
    } else if (msgDate.isSame(today.subtract(1, 'day'), 'day')) {
      return '昨天';
    } else if (msgDate.isSame(today, 'year')) {
      return msgDate.format('M月D日');
    } else {
      return msgDate.format('YYYY年M月D日');
    }
  };

  // 复制消息到剪贴板
  const handleCopyMessage = (content: string) => {
    navigator.clipboard.writeText(content).then(() => {
      message.success('已复制到剪贴板');
    }).catch(() => {
      message.error('复制失败');
    });
  };

  // 渲染消息内容（支持不同类型）
  const renderMessageContent = (msg: Message, isOwnMessage: boolean) => {
    switch (msg.type) {
      case 'image':
        return (
          <div 
            style={{ cursor: 'pointer' }}
          >
            <AuthImage
              src={msg.mediaUrl}
              alt={msg.content || '图片'}
              onClick={() => msg.mediaUrl && setPreviewImage(msg.mediaUrl)}
            />
            {msg.content && (
              <Paragraph style={{
                margin: '4px 0 0 0',
                fontSize: 12,
                color: isOwnMessage ? 'rgba(255,255,255,0.8)' : '#666',
              }}>
                {msg.content}
              </Paragraph>
            )}
          </div>
        );
      case 'file':
        return (
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
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
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <PlayCircleOutlined style={{ fontSize: 24 }} />
            <span>{msg.content || '视频'}</span>
          </div>
        );
      default:
        return (
          <Paragraph style={{
            margin: 0,
            whiteSpace: 'pre-wrap',
            wordBreak: 'break-word',
            color: 'inherit',
          }}>
            {msg.content}
          </Paragraph>
        );
    }
  };

  // 渲染消息项
  const renderMessage = (msg: Message, index: number) => {
    const prevMsg = roomMessages[index + 1]; // 消息是倒序的
    const isOwnMessage = msg.senderId === user?.id;
    const showDateSeparator = shouldShowDateSeparator(msg, prevMsg);

    // 右键菜单项
    const contextMenuItems: MenuProps['items'] = [
      {
        key: 'copy',
        label: '复制',
        icon: <CopyOutlined />,
        onClick: () => handleCopyMessage(msg.content),
      },
    ];

    return (
      <div key={msg.id}>
        {showDateSeparator && (
          <div style={{
            textAlign: 'center',
            padding: '16px 0',
          }}>
            <Text type="secondary" style={{
              background: '#f0f0f0',
              padding: '4px 12px',
              borderRadius: 12,
              fontSize: 12,
            }}>
              {formatDateSeparator(msg.createdAt)}
            </Text>
          </div>
        )}
        
        <div style={{
          display: 'flex',
          justifyContent: isOwnMessage ? 'flex-end' : 'flex-start',
          padding: '4px 16px',
          gap: 8,
        }}>
          {!isOwnMessage && (
            <Avatar
              size={36}
              src={msg.sender.avatarUrl}
              icon={<UserOutlined />}
              style={{ backgroundColor: '#667eea', flexShrink: 0 }}
            />
          )}
          
          <div style={{
            maxWidth: '70%',
            display: 'flex',
            flexDirection: 'column',
            alignItems: isOwnMessage ? 'flex-end' : 'flex-start',
          }}>
            {!isOwnMessage && (
              <Text type="secondary" style={{ fontSize: 12, marginBottom: 2 }}>
                {msg.sender.displayName}
              </Text>
            )}
            
            <Dropdown menu={{ items: contextMenuItems }} trigger={['contextMenu']}>
              <div style={{
                background: isOwnMessage ? '#667eea' : '#fff',
                color: isOwnMessage ? '#fff' : '#1a1a1a',
                padding: msg.type === 'image' ? '6px' : '10px 14px',
                borderRadius: isOwnMessage ? '16px 16px 4px 16px' : '16px 16px 16px 4px',
                boxShadow: '0 1px 2px rgba(0,0,0,0.08)',
                cursor: 'context-menu',
              }}>
                {renderMessageContent(msg, isOwnMessage)}
              </div>
            </Dropdown>
            
            <Tooltip title={dayjs(msg.createdAt).format('YYYY-MM-DD HH:mm:ss')}>
              <Text type="secondary" style={{ fontSize: 11, marginTop: 2, display: 'flex', alignItems: 'center', gap: 4 }}>
                {formatMessageTime(msg.createdAt)}
                {msg.isEdited && ' (已编辑)'}
                {isOwnMessage && roomId && (
                  isMessageRead(roomId, msg.senderId, msg.createdAt) ? (
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
              src={user?.avatarUrl}
              icon={<UserOutlined />}
              style={{ backgroundColor: '#667eea', flexShrink: 0 }}
            />
          )}
        </div>
      </div>
    );
  };

  if (!currentRoom) {
    return (
      <div style={{
        height: '100%',
        display: 'flex',
        justifyContent: 'center',
        alignItems: 'center',
      }}>
        <Empty description="请选择一个聊天室" />
      </div>
    );
  }

  return (
    <Layout style={{ height: '100%', background: '#f5f5f5' }}>
      {/* 头部 */}
      <Header style={{
        background: '#fff',
        padding: '0 16px',
        display: 'flex',
        alignItems: 'center',
        gap: 12,
        boxShadow: '0 1px 4px rgba(0,0,0,0.08)',
        height: 56,
      }}>
        <Button
          type="text"
          icon={<ArrowLeftOutlined />}
          onClick={() => navigate('/chat')}
        />
        <Avatar
          size={40}
          src={currentRoom.avatarUrl}
          icon={currentRoom.type === 'direct' ? <UserOutlined /> : <TeamOutlined />}
          style={{ backgroundColor: '#667eea' }}
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
      <Content
        ref={messagesContainerRef}
        style={{
          flex: 1,
          overflow: 'auto',
          padding: '8px 0',
          display: 'flex',
          flexDirection: 'column-reverse',
        }}
      >
        <div ref={messagesEndRef} />
        
        {roomMessages.map((msg, index) => renderMessage(msg, index))}
        
        {canLoadMore && (
          <div style={{ textAlign: 'center', padding: 16 }}>
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
          <div style={{ textAlign: 'center', padding: 40 }}>
            <Spin />
          </div>
        )}
      </Content>

      {/* 输入状态提示 */}
      {roomTypingUsers.length > 0 && (
        <div style={{
          padding: '4px 16px',
          background: '#fff',
          borderTop: '1px solid #f0f0f0',
        }}>
          <Text type="secondary" style={{ fontSize: 12 }}>
            {roomTypingUsers.join(', ')} 正在输入...
          </Text>
        </div>
      )}

      {/* 输入框 */}
      <Footer style={{
        background: '#fff',
        padding: '12px 16px',
        borderTop: '1px solid #f0f0f0',
      }}>
        <div style={{ display: 'flex', gap: 8, alignItems: 'flex-end' }}>
          <Upload showUploadList={false} disabled>
            <Button type="text" icon={<PictureOutlined />} />
          </Upload>
          <Upload showUploadList={false} disabled>
            <Button type="text" icon={<PaperClipOutlined />} />
          </Upload>
          <Button type="text" icon={<SmileOutlined />} disabled />
          
          <Input.TextArea
            value={inputValue}
            onChange={(e) => setInputValue(e.target.value)}
            onKeyDown={handleKeyPress}
            onPaste={handlePaste}
            placeholder="输入消息...（支持 Ctrl+V 粘贴图片）"
            autoSize={{ minRows: 1, maxRows: 4 }}
            style={{ flex: 1, resize: 'none' }}
          />
          
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
        onCancel={() => setPreviewImage(null)}
        width="auto"
        centered
        styles={{ body: { padding: 0, textAlign: 'center' } }}
      >
        {previewImage && <AuthImage src={previewImage} style={{ maxWidth: '80vw', maxHeight: '80vh', borderRadius: 0 }} />}
      </Modal>
    </Layout>
  );
}
