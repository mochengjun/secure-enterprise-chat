import { useEffect, useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { Layout, List, Avatar, Typography, Button, Modal, Input, Select, Spin, Empty, Tag, message, Popconfirm } from 'antd';
import {
  ArrowLeftOutlined,
  UserOutlined,
  UserAddOutlined,
  CrownOutlined,
  DeleteOutlined,
  SearchOutlined,
} from '@ant-design/icons';
import { useChatStore } from '@presentation/stores/chatStore';
import { useAuthStore } from '@presentation/stores/authStore';
import { apiClient } from '@core/api/client';
import { ENDPOINTS } from '@core/api/endpoints';
import type { Member, MemberRole } from '@domain/entities/Member';
import type { MemberResponse, MembersListResponse, UserResponse } from '@shared/types/api.types';

const { Header, Content } = Layout;
const { Text } = Typography;

// 将后端MemberResponse转换为域Member
function mapMember(data: MemberResponse, roomId: string): Member {
  return {
    id: data.user_id, // 后端无独立id，用user_id
    userId: data.user_id,
    roomId,
    user: {
      id: data.user_id,
      username: data.user_id.split(':')[0]?.replace('@', '') || data.user_id,
      email: '',
      displayName: data.display_name || data.user_id,
      createdAt: new Date(),
      updatedAt: new Date(),
    },
    role: data.role,
    joinedAt: new Date(data.joined_at),
  };
}

export function RoomMembersPage() {
  const { roomId } = useParams<{ roomId: string }>();
  const navigate = useNavigate();
  const { user } = useAuthStore();
  const { currentRoom, rooms } = useChatStore();

  const [members, setMembers] = useState<Member[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [isAddModalOpen, setIsAddModalOpen] = useState(false);
  const [searchText, setSearchText] = useState('');
  const [searchResults, setSearchResults] = useState<UserResponse[]>([]);
  const [isSearching, setIsSearching] = useState(false);
  const [selectedUserId, setSelectedUserId] = useState<string | null>(null);
  const [selectedRole, setSelectedRole] = useState<MemberRole>('member');
  const [isAdding, setIsAdding] = useState(false);

  const room = currentRoom || rooms.find(r => r.id === roomId);

  // 获取成员列表
  useEffect(() => {
    const fetchMembers = async () => {
      if (!roomId) return;
      
      setIsLoading(true);
      try {
        const response = await apiClient.get<MembersListResponse>(
          ENDPOINTS.CHAT.ROOM_MEMBERS(roomId)
        );
        setMembers(response.data.members.map(m => mapMember(m, roomId)));
      } catch {
        message.error('获取成员列表失败');
      } finally {
        setIsLoading(false);
      }
    };

    fetchMembers();
  }, [roomId]);

  // 搜索用户
  const handleSearch = async (value: string) => {
    if (!value.trim()) {
      setSearchResults([]);
      return;
    }

    setIsSearching(true);
    try {
      const response = await apiClient.get<UserResponse[]>(
        ENDPOINTS.USERS.SEARCH,
        { params: { q: value } }
      );
      // 过滤掉已经是成员的用户
      const existingMemberIds = new Set(members.map(m => m.userId));
      setSearchResults((response.data || []).filter(u => !existingMemberIds.has(u.user_id)));
    } catch {
      message.error('搜索用户失败');
    } finally {
      setIsSearching(false);
    }
  };

  // 添加成员
  const handleAddMember = async () => {
    if (!roomId || !selectedUserId) return;

    setIsAdding(true);
    try {
      const response = await apiClient.post<MemberResponse>(
        ENDPOINTS.CHAT.ROOM_MEMBERS(roomId),
        { user_id: selectedUserId, role: selectedRole }
      );
      setMembers([...members, mapMember(response.data, roomId)]);
      message.success('成员添加成功');
      setIsAddModalOpen(false);
      setSearchText('');
      setSearchResults([]);
      setSelectedUserId(null);
    } catch {
      message.error('添加成员失败');
    } finally {
      setIsAdding(false);
    }
  };

  // 移除成员
  const handleRemoveMember = async (memberId: string, userId: string) => {
    if (!roomId) return;

    try {
      await apiClient.delete(ENDPOINTS.CHAT.ROOM_MEMBER(roomId, userId));
      setMembers(members.filter(m => m.id !== memberId));
      message.success('成员已移除');
    } catch {
      message.error('移除成员失败');
    }
  };

  // 获取当前用户在房间中的角色
  const currentUserMember = members.find(m => m.userId === user?.id);
  const isAdmin = currentUserMember?.role === 'owner' || currentUserMember?.role === 'admin';

  // 获取角色标签
  const getRoleTag = (role: MemberRole) => {
    switch (role) {
      case 'owner':
        return <Tag color="gold" icon={<CrownOutlined />}>群主</Tag>;
      case 'admin':
        return <Tag color="blue">管理员</Tag>;
      default:
        return null;
    }
  };

  if (!room) {
    return (
      <div style={{ height: '100%', display: 'flex', justifyContent: 'center', alignItems: 'center' }}>
        <Empty description="聊天室不存在" />
      </div>
    );
  }

  return (
    <Layout style={{ height: '100%', background: '#f5f5f5' }}>
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
          onClick={() => navigate(`/chat/${roomId}`)}
        />
        <Text strong style={{ flex: 1 }}>
          成员管理 ({members.length})
        </Text>
        {isAdmin && (
          <Button
            type="primary"
            icon={<UserAddOutlined />}
            onClick={() => setIsAddModalOpen(true)}
          >
            添加成员
          </Button>
        )}
      </Header>

      <Content style={{ overflow: 'auto', background: '#fff', margin: 16, borderRadius: 8 }}>
        {isLoading ? (
          <div style={{ padding: 40, textAlign: 'center' }}>
            <Spin />
          </div>
        ) : members.length === 0 ? (
          <Empty description="暂无成员" style={{ padding: 40 }} />
        ) : (
          <List
            dataSource={members}
            renderItem={(member) => (
              <List.Item
                style={{ padding: '12px 16px' }}
                actions={isAdmin && member.role !== 'owner' && member.userId !== user?.id ? [
                  <Popconfirm
                    key="remove"
                    title="确定要移除该成员吗？"
                    onConfirm={() => handleRemoveMember(member.id, member.userId)}
                    okText="确定"
                    cancelText="取消"
                  >
                    <Button
                      type="text"
                      danger
                      icon={<DeleteOutlined />}
                      size="small"
                    >
                      移除
                    </Button>
                  </Popconfirm>
                ] : []}
              >
                <List.Item.Meta
                  avatar={
                    <Avatar
                      size={40}
                      src={member.user.avatarUrl}
                      icon={<UserOutlined />}
                      style={{ backgroundColor: '#667eea' }}
                    />
                  }
                  title={
                    <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                      <Text strong>{member.user.displayName}</Text>
                      {getRoleTag(member.role)}
                      {member.userId === user?.id && (
                        <Tag color="green">我</Tag>
                      )}
                    </div>
                  }
                  description={`@${member.user.username}`}
                />
              </List.Item>
            )}
          />
        )}
      </Content>

      {/* 添加成员弹窗 */}
      <Modal
        title="添加成员"
        open={isAddModalOpen}
        onCancel={() => {
          setIsAddModalOpen(false);
          setSearchText('');
          setSearchResults([]);
          setSelectedUserId(null);
        }}
        onOk={handleAddMember}
        okText="添加"
        cancelText="取消"
        confirmLoading={isAdding}
        okButtonProps={{ disabled: !selectedUserId }}
      >
        <div style={{ marginBottom: 16 }}>
          <Input.Search
            placeholder="搜索用户名或邮箱"
            prefix={<SearchOutlined />}
            value={searchText}
            onChange={(e) => setSearchText(e.target.value)}
            onSearch={handleSearch}
            loading={isSearching}
            allowClear
          />
        </div>

        {searchResults.length > 0 && (
          <>
            <List
              size="small"
              dataSource={searchResults}
              style={{ maxHeight: 200, overflow: 'auto', marginBottom: 16 }}
              renderItem={(u) => (
                <List.Item
                  style={{
                    cursor: 'pointer',
                    background: selectedUserId === u.user_id ? '#f0f7ff' : 'transparent',
                    padding: '8px 12px',
                    borderRadius: 4,
                  }}
                  onClick={() => setSelectedUserId(u.user_id)}
                >
                  <List.Item.Meta
                    avatar={
                      <Avatar
                        size={32}
                        src={u.avatar_url}
                        icon={<UserOutlined />}
                      />
                    }
                    title={u.display_name}
                    description={`@${u.username}`}
                  />
                </List.Item>
              )}
            />

            {selectedUserId && (
              <div>
                <Text type="secondary" style={{ marginRight: 8 }}>角色：</Text>
                <Select
                  value={selectedRole}
                  onChange={setSelectedRole}
                  style={{ width: 120 }}
                  options={[
                    { value: 'member', label: '普通成员' },
                    { value: 'admin', label: '管理员' },
                  ]}
                />
              </div>
            )}
          </>
        )}

        {searchText && searchResults.length === 0 && !isSearching && (
          <Empty description="未找到用户" image={Empty.PRESENTED_IMAGE_SIMPLE} />
        )}
      </Modal>
    </Layout>
  );
}
