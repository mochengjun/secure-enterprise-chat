import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { LoginPage } from '@presentation/pages/auth/LoginPage';
import { MainLayout } from '@presentation/components/common/MainLayout';
import { ChatRoomListPage } from '@presentation/pages/chat/ChatRoomListPage';
import { ChatRoomPage } from '@presentation/pages/chat/ChatRoomPage';
import { RoomMembersPage } from '@presentation/pages/chat/RoomMembersPage';
import { BrowseGroupsPage } from '@presentation/pages/chat/BrowseGroupsPage';
import { useAuthStore } from '@presentation/stores/authStore';
import { ROUTES } from '@shared/constants/config';

// 受保护的路由组件
function ProtectedRoute({ children }: { children: React.ReactNode }) {
  const { isAuthenticated } = useAuthStore();
  
  if (!isAuthenticated) {
    return <Navigate to={ROUTES.LOGIN} replace />;
  }
  
  return <>{children}</>;
}

// 公开路由组件（已登录时跳转到聊天页）
function PublicRoute({ children }: { children: React.ReactNode }) {
  const { isAuthenticated } = useAuthStore();
  
  if (isAuthenticated) {
    return <Navigate to={ROUTES.CHAT} replace />;
  }
  
  return <>{children}</>;
}

export function AppRouter() {
  return (
    <BrowserRouter>
      <Routes>
        {/* 公开路由 */}
        <Route
          path={ROUTES.LOGIN}
          element={
            <PublicRoute>
              <LoginPage />
            </PublicRoute>
          }
        />
        <Route
          path={ROUTES.REGISTER}
          element={
            <PublicRoute>
              <LoginPage />
            </PublicRoute>
          }
        />

        {/* 受保护的路由 */}
        <Route
          path="/"
          element={
            <ProtectedRoute>
              <MainLayout />
            </ProtectedRoute>
          }
        >
          <Route index element={<Navigate to={ROUTES.CHAT} replace />} />
          <Route path="chat" element={<ChatRoomListPage />} />
          <Route path="chat/browse" element={<BrowseGroupsPage />} />
          <Route path="chat/:roomId" element={<ChatRoomPage />} />
          <Route path="chat/:roomId/members" element={<RoomMembersPage />} />
          <Route path="settings" element={<div style={{ padding: 24 }}>设置页面（待实现）</div>} />
        </Route>

        {/* 404 重定向 */}
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  );
}
