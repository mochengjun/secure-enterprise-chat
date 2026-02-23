import { useEffect, useState, useCallback, useRef } from 'react';
import { List, Avatar, Typography, Badge, Input, Button, Modal, Form, Select, Spin, Empty, message } from 'antd';
import {
  SearchOutlined,
  PlusOutlined,
  UserOutlined,
  TeamOutlined,
  MessageOutlined,
  GlobalOutlined,
  UserAddOutlined,
} from '@ant-design/icons';
import { useNavigate } from 'react-router-dom';
import { useChatStore } from '@presentation/stores/chatStore';
import { apiClient } from '@core/api/client';
import { ENDPOINTS } from '@core/api/endpoints';
import type { Room } from '@domain/entities/Room';
import type { CreateRoomRequest, UserSearchResponse, UserSearchResult } from '@shared/types/api.types';
import dayjs from 'dayjs';
import relativeTime from 'dayjs/plugin/relativeTime';
import 'dayjs/locale/zh-cn';

dayjs.extend(relativeTime);
dayjs.locale('zh-cn');

const { Text, Paragraph } = Typography;

export function ChatRoomListPage() {
  const navigate = useNavigate();
  const { rooms, currentRoom, isLoadingRooms, fetchRooms, createRoom, setCurrentRoom } = useChatStore();
  const [searchText, setSearchText] = useState('');
  const [isCreateModalOpen, setIsCreateModalOpen] = useState(false);
  const [createForm] = Form.useForm<CreateRoomRequest>();
  const [isCreating, setIsCreating] = useState(false);
  const [isDirectChatModalOpen, setIsDirectChatModalOpen] = useState(false);
  const [userSearchText, setUserSearchText] = useState('');
  const [userSearchResults, setUserSearchResults] = useState<UserSearchResult[]>([]);
  const [isSearchingUsers, setIsSearchingUsers] = useState(false);
  const [isCreatingDirectChat, setIsCreatingDirectChat] = useState(false);
  const searchTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    fetchRooms();
  }, [fetchRooms]);

  const handleUserSearch = useCallback((query: string) => {
    setUserSearchText(query);
    if (searchTimerRef.current) clearTimeout(searchTimerRef.current);
    if (!query.trim()) {
      setUserSearchResults([]);
      return;
    }
    searchTimerRef.current = setTimeout(async () => {
      setIsSearchingUsers(true);
      try {
        const response = await apiClient.get<UserSearchResponse>(ENDPOINTS.USERS.SEARCH, {
          params: { search: query.trim(), limit: 20 },
        });
        setUserSearchResults(response.data.users || []);
      } catch {
        setUserSearchResults([]);
      } finally {
        setIsSearchingUsers(false);
      }
    }, 400);
  }, []);

  const handleStartDirectChat = async (user: UserSearchResult) => {
    setIsCreatingDirectChat(true);
    try {
      const room = await createRoom({
        name: user.display_name || user.username,
        type: 'direct',
        member_ids: [user.user_id],
      });
      setIsDirectChatModalOpen(false);
      setUserSearchText('');
      setUserSearchResults([]);
      handleRoomClick(room);
    } catch {
      message.error('创建私聊失败');
    } finally {
      setIsCreatingDirectChat(false);
    }
  };

  const filteredRooms = rooms.filter(room =>
    room.name.toLowerCase().includes(searchText.toLowerCase())
  );

  const handleRoomClick = (room: Room) => {
    setCurrentRoom(room);
    navigate(`/chat/${room.id}`);
  };

  const handleCreateRoom = async (values: CreateRoomRequest) => {
    setIsCreating(true);
    try {
      const room = await createRoom(values);
      setIsCreateModalOpen(false);
      createForm.resetFields();
      handleRoomClick(room);
    } finally {
      setIsCreating(false);
    }
  };

  const getRoomIcon = (type: Room['type']) => {
    switch (type) {
      case 'direct':
        return <UserOutlined />;
      case 'group':
        return <TeamOutlined />;
      case 'channel':
        return <MessageOutlined />;
      default:
        return <MessageOutlined />;
    }
  };

  const formatTime = (date: Date) => {
    const now = dayjs();
    const messageTime = dayjs(date);
    
    if (now.diff(messageTime, 'day') === 0) {
      return messageTime.format('HH:mm');
    } else if (now.diff(messageTime, 'day') === 1) {
      return '昨天';
    } else if (now.diff(messageTime, 'week') < 1) {
      return messageTime.format('dddd');
    } else {
      return messageTime.format('MM/DD');
    }
  };

  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column' }}>
      {/* 搜索栏和创建按钮 */}
      <div style={{
        padding: '16px',
        background: '#fff',
        borderBottom: '1px solid #f0f0f0',
        display: 'flex',
        gap: 12,
      }}>
        <Input
          placeholder="搜索聊天室"
          prefix={<SearchOutlined style={{ color: '#bfbfbf' }} />}
          value={searchText}
          onChange={(e) => setSearchText(e.target.value)}
          allowClear
          style={{ flex: 1 }}
        />
        <Button
          icon={<GlobalOutlined />}
          onClick={() => navigate('/chat/browse')}
        >
          发现
        </Button>
        <Button
          icon={<UserAddOutlined />}
          onClick={() => setIsDirectChatModalOpen(true)}
        >
          私聊
        </Button>
        <Button
          type="primary"
          icon={<PlusOutlined />}
          onClick={() => setIsCreateModalOpen(true)}
        >
          创建
        </Button>
      </div>

      {/* 聊天室列表 */}
      <div style={{ flex: 1, overflow: 'auto', background: '#fff' }}>
        {isLoadingRooms ? (
          <div style={{ padding: 40, textAlign: 'center' }}>
            <Spin />
          </div>
        ) : filteredRooms.length === 0 ? (
          <Empty
            image={Empty.PRESENTED_IMAGE_SIMPLE}
            description={searchText ? '没有找到匹配的聊天室' : '暂无聊天室'}
            style={{ padding: 40 }}
          >
            {!searchText && (
              <Button type="primary" onClick={() => setIsCreateModalOpen(true)}>
                创建第一个聊天室
              </Button>
            )}
          </Empty>
        ) : (
          <List
            dataSource={filteredRooms}
            renderItem={(room) => (
              <List.Item
                onClick={() => handleRoomClick(room)}
                style={{
                  padding: '12px 16px',
                  cursor: 'pointer',
                  background: currentRoom?.id === room.id ? '#f0f7ff' : 'transparent',
                  transition: 'background 0.2s',
                }}
                onMouseEnter={(e) => {
                  if (currentRoom?.id !== room.id) {
                    e.currentTarget.style.background = '#fafafa';
                  }
                }}
                onMouseLeave={(e) => {
                  if (currentRoom?.id !== room.id) {
                    e.currentTarget.style.background = 'transparent';
                  }
                }}
              >
                <List.Item.Meta
                  avatar={
                    <Badge count={room.unreadCount} offset={[-4, 4]}>
                      <Avatar
                        size={48}
                        src={room.avatarUrl}
                        icon={getRoomIcon(room.type)}
                        style={{ backgroundColor: '#667eea' }}
                      />
                    </Badge>
                  }
                  title={
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                      <Text strong ellipsis style={{ maxWidth: 180 }}>
                        {room.name}
                      </Text>
                      {room.lastMessage && (
                        <Text type="secondary" style={{ fontSize: 12 }}>
                          {formatTime(room.lastMessage.createdAt)}
                        </Text>
                      )}
                    </div>
                  }
                  description={
                    <Paragraph
                      ellipsis={{ rows: 1 }}
                      style={{ margin: 0, color: '#8c8c8c', fontSize: 13 }}
                    >
                      {room.lastMessage
                        ? `${room.lastMessage.sender.displayName}: ${room.lastMessage.content}`
                        : '暂无消息'}
                    </Paragraph>
                  }
                />
              </List.Item>
            )}
          />
        )}
      </div>

      {/* 创建聊天室弹窗 */}
      <Modal
        title="创建聊天室"
        open={isCreateModalOpen}
        onCancel={() => {
          setIsCreateModalOpen(false);
          createForm.resetFields();
        }}
        footer={null}
      >
        <Form
          form={createForm}
          layout="vertical"
          onFinish={handleCreateRoom}
          initialValues={{ type: 'group' }}
        >
          <Form.Item
            name="name"
            label="聊天室名称"
            rules={[
              { required: true, message: '请输入聊天室名称' },
              { max: 50, message: '名称最多50个字符' },
            ]}
          >
            <Input placeholder="请输入聊天室名称" />
          </Form.Item>

          <Form.Item
            name="type"
            label="聊天室类型"
            rules={[{ required: true, message: '请选择聊天室类型' }]}
          >
            <Select
              options={[
                { value: 'group', label: '群组 - 多人私密聊天' },
                { value: 'channel', label: '频道 - 公开广播消息' },
              ]}
            />
          </Form.Item>

          <Form.Item
            name="description"
            label="描述（可选）"
            rules={[{ max: 200, message: '描述最多200个字符' }]}
          >
            <Input.TextArea rows={3} placeholder="请输入聊天室描述" />
          </Form.Item>

          <Form.Item style={{ marginBottom: 0, textAlign: 'right' }}>
            <Button onClick={() => setIsCreateModalOpen(false)} style={{ marginRight: 8 }}>
              取消
            </Button>
            <Button type="primary" htmlType="submit" loading={isCreating}>
              创建
            </Button>
          </Form.Item>
        </Form>
      </Modal>

      {/* 新建私聊弹窗 */}
      <Modal
        title="新建私聊"
        open={isDirectChatModalOpen}
        onCancel={() => {
          setIsDirectChatModalOpen(false);
          setUserSearchText('');
          setUserSearchResults([]);
        }}
        footer={null}
      >
        <Input
          placeholder="搜索用户名..."
          prefix={<SearchOutlined style={{ color: '#bfbfbf' }} />}
          value={userSearchText}
          onChange={(e) => handleUserSearch(e.target.value)}
          allowClear
          style={{ marginBottom: 16 }}
          autoFocus
        />
        {isCreatingDirectChat && (
          <div style={{ padding: 16, textAlign: 'center' }}>
            <Spin tip="正在创建..." />
          </div>
        )}
        {!isCreatingDirectChat && isSearchingUsers && (
          <div style={{ padding: 24, textAlign: 'center' }}>
            <Spin />
          </div>
        )}
        {!isCreatingDirectChat && !isSearchingUsers && userSearchText && userSearchResults.length === 0 && (
          <Empty image={Empty.PRESENTED_IMAGE_SIMPLE} description="未找到匹配的用户" />
        )}
        {!isCreatingDirectChat && !isSearchingUsers && userSearchResults.length > 0 && (
          <List
            dataSource={userSearchResults}
            style={{ maxHeight: 300, overflow: 'auto' }}
            renderItem={(user) => (
              <List.Item
                style={{ cursor: 'pointer', padding: '8px 0' }}
                onClick={() => handleStartDirectChat(user)}
              >
                <List.Item.Meta
                  avatar={
                    <Avatar
                      src={user.avatar_url}
                      icon={<UserOutlined />}
                      style={{ backgroundColor: '#667eea' }}
                    />
                  }
                  title={user.display_name || user.username}
                  description={`@${user.username}`}
                />
              </List.Item>
            )}
          />
        )}
        {!isCreatingDirectChat && !isSearchingUsers && !userSearchText && (
          <div style={{ padding: 24, textAlign: 'center', color: '#8c8c8c' }}>
            输入用户名搜索
          </div>
        )}
      </Modal>
    </div>
  );
}
