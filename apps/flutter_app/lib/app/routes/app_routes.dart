import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/authentication/presentation/pages/login_page.dart';
import '../../features/authentication/presentation/pages/register_page.dart';
import '../../features/chat/presentation/pages/room_list_page.dart';
import '../../features/chat/presentation/pages/chat_room_page.dart';

final appRouter = GoRouter(
  initialLocation: '/login',
  routes: [
    // 认证路由
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: '/register',
      name: 'register',
      builder: (context, state) => const RegisterPage(),
    ),
    
    // 主页路由
    GoRoute(
      path: '/',
      name: 'home',
      builder: (context, state) => const RoomListPage(),
      routes: [
        GoRoute(
          path: 'room/:roomId',
          name: 'chatRoom',
          builder: (context, state) {
            final roomId = state.pathParameters['roomId']!;
            return ChatRoomPage(roomId: roomId);
          },
        ),
      ],
    ),
  ],
  
  // 错误页面
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Text('Page not found: ${state.uri}'),
    ),
  ),
  
  // 路由重定向（用于认证检查）
  redirect: (context, state) {
    // TODO: 实现认证检查逻辑
    return null;
  },
);
