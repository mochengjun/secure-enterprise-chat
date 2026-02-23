import { useEffect } from 'react';
import { Layout, Menu, Avatar, Typography, Badge, Spin, Button, Dropdown } from 'antd';
import {
  MessageOutlined,
  SettingOutlined,
  LogoutOutlined,
  UserOutlined,
  WifiOutlined,
  DisconnectOutlined,
  LoadingOutlined,
} from '@ant-design/icons';
import { Outlet, useNavigate, useLocation } from 'react-router-dom';
import { useAuthStore } from '@presentation/stores/authStore';
import { useWsStore } from '@presentation/stores/wsStore';
import { useChatStore } from '@presentation/stores/chatStore';
import { ROUTES } from '@shared/constants/config';

const { Sider, Content, Header } = Layout;
const { Text } = Typography;

export function MainLayout() {
  const navigate = useNavigate();
  const location = useLocation();
  const { user, logout, isLoading: authLoading, initializeAuth } = useAuthStore();
  const { status: wsStatus, initializeListeners: initWsListeners } = useWsStore();
  const { rooms, initializeListeners: initChatListeners } = useChatStore();

  // 初始化认证和监听器
  useEffect(() => {
    initializeAuth();
  }, [initializeAuth]);

  useEffect(() => {
    const cleanupWs = initWsListeners();
    const cleanupChat = initChatListeners();
    return () => {
      cleanupWs();
      cleanupChat();
    };
  }, [initWsListeners, initChatListeners]);

  const handleLogout = async () => {
    await logout();
    navigate(ROUTES.LOGIN);
  };

  // 计算总未读数
  const totalUnread = rooms.reduce((sum, room) => sum + room.unreadCount, 0);

  // 连接状态图标
  const connectionIcon = () => {
    switch (wsStatus) {
      case 'connected':
        return <WifiOutlined style={{ color: '#52c41a' }} />;
      case 'connecting':
      case 'reconnecting':
        return <LoadingOutlined style={{ color: '#faad14' }} />;
      default:
        return <DisconnectOutlined style={{ color: '#ff4d4f' }} />;
    }
  };

  const userMenuItems = [
    {
      key: 'profile',
      icon: <UserOutlined />,
      label: '个人资料',
    },
    {
      key: 'settings',
      icon: <SettingOutlined />,
      label: '设置',
      onClick: () => navigate(ROUTES.SETTINGS),
    },
    {
      type: 'divider' as const,
    },
    {
      key: 'logout',
      icon: <LogoutOutlined />,
      label: '退出登录',
      onClick: handleLogout,
    },
  ];

  if (authLoading) {
    return (
      <div style={{
        height: '100vh',
        display: 'flex',
        justifyContent: 'center',
        alignItems: 'center',
      }}>
        <Spin size="large" />
      </div>
    );
  }

  return (
    <Layout style={{ minHeight: '100vh' }}>
      <Sider
        width={240}
        style={{
          background: '#1a1a2e',
          borderRight: '1px solid #2d2d44',
        }}
      >
        <div style={{
          height: 64,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          borderBottom: '1px solid #2d2d44',
        }}>
          <Text strong style={{ color: '#fff', fontSize: 18 }}>
            安全聊天
          </Text>
        </div>

        <Menu
          mode="inline"
          selectedKeys={[location.pathname]}
          style={{
            background: 'transparent',
            borderRight: 0,
          }}
          theme="dark"
          items={[
            {
              key: ROUTES.CHAT,
              icon: (
                <Badge count={totalUnread} size="small" offset={[8, 0]}>
                  <MessageOutlined style={{ color: '#8b8b9a' }} />
                </Badge>
              ),
              label: '消息',
              onClick: () => navigate(ROUTES.CHAT),
            },
            {
              key: ROUTES.SETTINGS,
              icon: <SettingOutlined style={{ color: '#8b8b9a' }} />,
              label: '设置',
              onClick: () => navigate(ROUTES.SETTINGS),
            },
          ]}
        />
      </Sider>

      <Layout>
        <Header style={{
          background: '#fff',
          padding: '0 24px',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          boxShadow: '0 1px 4px rgba(0,0,0,0.08)',
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            {connectionIcon()}
            <Text type="secondary" style={{ fontSize: 12 }}>
              {wsStatus === 'connected' ? '已连接' :
               wsStatus === 'connecting' ? '连接中...' :
               wsStatus === 'reconnecting' ? '重连中...' : '未连接'}
            </Text>
          </div>

          <Dropdown menu={{ items: userMenuItems }} placement="bottomRight">
            <Button type="text" style={{ height: 'auto', padding: '4px 8px' }}>
              <Avatar
                size={32}
                src={user?.avatarUrl}
                icon={<UserOutlined />}
                style={{ backgroundColor: '#667eea' }}
              />
              <Text style={{ marginLeft: 8 }}>
                {user?.displayName || user?.username}
              </Text>
            </Button>
          </Dropdown>
        </Header>

        <Content style={{ background: '#f5f5f5' }}>
          <Outlet />
        </Content>
      </Layout>
    </Layout>
  );
}
