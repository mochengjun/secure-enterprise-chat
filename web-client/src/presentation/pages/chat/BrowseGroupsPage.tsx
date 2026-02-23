import { useEffect, useState } from 'react';
import { List, Avatar, Typography, Input, Button, Spin, Empty, Tag, message } from 'antd';
import {
  SearchOutlined,
  ArrowLeftOutlined,
  TeamOutlined,
  MessageOutlined,
  UserAddOutlined,
  CheckOutlined,
} from '@ant-design/icons';
import { useNavigate } from 'react-router-dom';
import { useChatStore } from '@presentation/stores/chatStore';
import dayjs from 'dayjs';

const { Text, Paragraph } = Typography;

export function BrowseGroupsPage() {
  const navigate = useNavigate();
  const { publicRooms, isLoadingPublicRooms, fetchPublicRooms, joinRoom } = useChatStore();
  const [searchText, setSearchText] = useState('');
  const [joiningId, setJoiningId] = useState<string | null>(null);

  useEffect(() => {
    fetchPublicRooms();
  }, [fetchPublicRooms]);

  const handleSearch = () => {
    fetchPublicRooms(searchText || undefined);
  };

  const handleJoin = async (roomId: string) => {
    setJoiningId(roomId);
    try {
      const room = await joinRoom(roomId);
      message.success('加入成功');
      navigate(`/chat/${room.id}`);
    } catch {
      message.error('加入失败');
    } finally {
      setJoiningId(null);
    }
  };

  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column' }}>
      {/* Header */}
      <div style={{
        padding: '16px',
        background: '#fff',
        borderBottom: '1px solid #f0f0f0',
        display: 'flex',
        gap: 12,
        alignItems: 'center',
      }}>
        <Button
          type="text"
          icon={<ArrowLeftOutlined />}
          onClick={() => navigate('/chat')}
        />
        <Input
          placeholder="搜索公开群组..."
          prefix={<SearchOutlined style={{ color: '#bfbfbf' }} />}
          value={searchText}
          onChange={(e) => setSearchText(e.target.value)}
          onPressEnter={handleSearch}
          allowClear
          style={{ flex: 1 }}
        />
        <Button type="primary" onClick={handleSearch}>
          搜索
        </Button>
      </div>

      {/* List */}
      <div style={{ flex: 1, overflow: 'auto', background: '#fff' }}>
        {isLoadingPublicRooms ? (
          <div style={{ padding: 40, textAlign: 'center' }}>
            <Spin />
          </div>
        ) : publicRooms.length === 0 ? (
          <Empty
            image={Empty.PRESENTED_IMAGE_SIMPLE}
            description="没有找到公开群组"
            style={{ padding: 40 }}
          />
        ) : (
          <List
            dataSource={publicRooms}
            renderItem={(room) => (
              <List.Item
                style={{ padding: '12px 16px' }}
                actions={[
                  room.is_member ? (
                    <Button
                      key="joined"
                      type="default"
                      icon={<CheckOutlined />}
                      onClick={() => navigate(`/chat/${room.id}`)}
                    >
                      已加入
                    </Button>
                  ) : (
                    <Button
                      key="join"
                      type="primary"
                      icon={<UserAddOutlined />}
                      loading={joiningId === room.id}
                      onClick={() => handleJoin(room.id)}
                    >
                      加入
                    </Button>
                  ),
                ]}
              >
                <List.Item.Meta
                  avatar={
                    <Avatar
                      size={48}
                      icon={room.type === 'channel' ? <MessageOutlined /> : <TeamOutlined />}
                      style={{ backgroundColor: '#667eea' }}
                    />
                  }
                  title={
                    <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                      <Text strong>{room.name}</Text>
                      <Tag color={room.type === 'channel' ? 'blue' : 'green'}>
                        {room.type === 'channel' ? '频道' : '群组'}
                      </Tag>
                      <Text type="secondary" style={{ fontSize: 12 }}>
                        {room.member_count || 0} 成员
                      </Text>
                    </div>
                  }
                  description={
                    <Paragraph
                      ellipsis={{ rows: 1 }}
                      style={{ margin: 0, color: '#8c8c8c', fontSize: 13 }}
                    >
                      {room.description || '暂无描述'}
                      <Text type="secondary" style={{ fontSize: 12, marginLeft: 8 }}>
                        创建于 {dayjs(room.created_at).format('YYYY-MM-DD')}
                      </Text>
                    </Paragraph>
                  }
                />
              </List.Item>
            )}
          />
        )}
      </div>
    </div>
  );
}
