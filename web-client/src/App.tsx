import { useEffect } from 'react';
import { ConfigProvider, App as AntdApp } from 'antd';
import zhCN from 'antd/locale/zh_CN';
import { AppRouter } from './router';
import { useAuthStore } from '@presentation/stores/authStore';

function App() {
  const { initializeAuth } = useAuthStore();

  useEffect(() => {
    initializeAuth();
  }, [initializeAuth]);

  return (
    <ConfigProvider
      locale={zhCN}
      theme={{
        token: {
          colorPrimary: '#667eea',
          borderRadius: 8,
        },
      }}
    >
      <AntdApp>
        <AppRouter />
      </AntdApp>
    </ConfigProvider>
  );
}

export default App;
