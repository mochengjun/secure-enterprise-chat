import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';

/// 推送通知类型
enum PushNotificationType {
  newMessage,
  mention,
  roomInvite,
  systemAlert,
  callIncoming,
  callMissed,
}

/// 推送通知数据
class PushNotificationData {
  final String? type;
  final String? roomId;
  final String? messageId;
  final String? senderId;
  final Map<String, dynamic> extra;

  PushNotificationData({
    this.type,
    this.roomId,
    this.messageId,
    this.senderId,
    this.extra = const {},
  });

  factory PushNotificationData.fromMap(Map<String, dynamic> map) {
    return PushNotificationData(
      type: map['type'] as String?,
      roomId: map['room_id'] as String?,
      messageId: map['message_id'] as String?,
      senderId: map['sender_id'] as String?,
      extra: Map<String, dynamic>.from(map),
    );
  }
}

/// 推送设置
class PushSettings {
  final bool enablePush;
  final bool enableSound;
  final bool enableVibration;
  final bool enablePreview;
  final int? quietHoursStart;
  final int? quietHoursEnd;
  final List<String> mutedRooms;

  PushSettings({
    this.enablePush = true,
    this.enableSound = true,
    this.enableVibration = true,
    this.enablePreview = true,
    this.quietHoursStart,
    this.quietHoursEnd,
    this.mutedRooms = const [],
  });

  factory PushSettings.fromJson(Map<String, dynamic> json) {
    return PushSettings(
      enablePush: json['enable_push'] ?? true,
      enableSound: json['enable_sound'] ?? true,
      enableVibration: json['enable_vibration'] ?? true,
      enablePreview: json['enable_preview'] ?? true,
      quietHoursStart: json['quiet_hours_start'],
      quietHoursEnd: json['quiet_hours_end'],
      mutedRooms: json['muted_rooms'] != null
          ? List<String>.from(jsonDecode(json['muted_rooms']))
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enable_push': enablePush,
      'enable_sound': enableSound,
      'enable_vibration': enableVibration,
      'enable_preview': enablePreview,
      'quiet_hours_start': quietHoursStart,
      'quiet_hours_end': quietHoursEnd,
      'muted_rooms': jsonEncode(mutedRooms),
    };
  }

  PushSettings copyWith({
    bool? enablePush,
    bool? enableSound,
    bool? enableVibration,
    bool? enablePreview,
    int? quietHoursStart,
    int? quietHoursEnd,
    List<String>? mutedRooms,
  }) {
    return PushSettings(
      enablePush: enablePush ?? this.enablePush,
      enableSound: enableSound ?? this.enableSound,
      enableVibration: enableVibration ?? this.enableVibration,
      enablePreview: enablePreview ?? this.enablePreview,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
      mutedRooms: mutedRooms ?? this.mutedRooms,
    );
  }
}

/// 推送通知服务
class PushNotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final Dio _dio;
  final String _baseUrl;

  // 通知回调
  Function(PushNotificationData)? onNotificationTap;
  Function(RemoteMessage)? onForegroundMessage;

  // 通知频道
  static const String _channelId = 'sec_chat_messages';
  static const String _channelName = 'Chat Messages';
  static const String _channelDescription = 'Notifications for new chat messages';

  PushNotificationService({
    required Dio dio,
    required String baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl;

  /// 初始化推送服务
  Future<void> initialize() async {
    // 请求权限
    await _requestPermission();

    // 初始化本地通知
    await _initLocalNotifications();

    // 配置 FCM 消息处理
    _configureMessageHandlers();

    // 获取并注册 token
    await _registerToken();

    // 监听 token 刷新
    _messaging.onTokenRefresh.listen(_onTokenRefresh);
  }

  /// 请求通知权限
  Future<bool> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }

  /// 初始化本地通知
  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    // 创建 Android 通知频道
    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }

  /// 配置消息处理器
  void _configureMessageHandlers() {
    // 前台消息
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // 后台/终止状态点击通知
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // 检查是否从通知启动
    _checkInitialMessage();
  }

  /// 检查初始消息（从通知启动应用）
  Future<void> _checkInitialMessage() async {
    final message = await _messaging.getInitialMessage();
    if (message != null) {
      _handleNotificationTap(message);
    }
  }

  /// 处理前台消息
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    onForegroundMessage?.call(message);

    // 显示本地通知
    final notification = message.notification;
    if (notification != null) {
      await _showLocalNotification(
        title: notification.title ?? 'New Message',
        body: notification.body ?? '',
        payload: jsonEncode(message.data),
      );
    }
  }

  /// 处理通知点击
  void _handleNotificationTap(RemoteMessage message) {
    final data = PushNotificationData.fromMap(message.data);
    onNotificationTap?.call(data);
  }

  /// 本地通知点击响应
  void _onNotificationResponse(NotificationResponse response) {
    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!) as Map<String, dynamic>;
        onNotificationTap?.call(PushNotificationData.fromMap(data));
      } catch (_) {}
    }
  }

  /// 显示本地通知
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// 获取并注册 FCM token
  Future<void> _registerToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _sendTokenToServer(token);
      }
    } catch (e) {
      print('Error getting FCM token: $e');
    }
  }

  /// Token 刷新回调
  Future<void> _onTokenRefresh(String token) async {
    await _sendTokenToServer(token);
  }

  /// 发送 token 到服务器
  Future<void> _sendTokenToServer(String token) async {
    try {
      final deviceId = await _getDeviceId();
      final platform = Platform.isIOS ? 'apns' : 'fcm';

      await _dio.post(
        '$_baseUrl/push/token',
        data: {
          'device_id': deviceId,
          'platform': platform,
          'token': token,
        },
      );

      // 保存 token 到本地
      await _storage.write(key: 'push_token', value: token);
    } catch (e) {
      print('Error sending token to server: $e');
    }
  }

  /// 获取设备 ID
  Future<String> _getDeviceId() async {
    var deviceId = await _storage.read(key: 'device_id');
    if (deviceId == null) {
      deviceId = DateTime.now().millisecondsSinceEpoch.toString();
      await _storage.write(key: 'device_id', value: deviceId);
    }
    return deviceId;
  }

  /// 注销推送 token
  Future<void> unregisterToken() async {
    try {
      final token = await _storage.read(key: 'push_token');
      if (token != null) {
        await _dio.delete(
          '$_baseUrl/push/token',
          data: {'token': token},
        );
        await _storage.delete(key: 'push_token');
      }
    } catch (e) {
      print('Error unregistering token: $e');
    }
  }

  /// 获取推送设置
  Future<PushSettings> getSettings() async {
    try {
      final response = await _dio.get('$_baseUrl/push/settings');
      return PushSettings.fromJson(response.data);
    } catch (e) {
      return PushSettings();
    }
  }

  /// 更新推送设置
  Future<void> updateSettings(PushSettings settings) async {
    await _dio.put(
      '$_baseUrl/push/settings',
      data: settings.toJson(),
    );
  }

  /// 订阅房间主题
  Future<void> subscribeToRoom(String roomId) async {
    await _messaging.subscribeToTopic('room_$roomId');
  }

  /// 取消订阅房间主题
  Future<void> unsubscribeFromRoom(String roomId) async {
    await _messaging.unsubscribeFromTopic('room_$roomId');
  }

  /// 清除所有通知
  Future<void> clearAllNotifications() async {
    await _localNotifications.cancelAll();
  }

  /// 清除特定房间的通知
  Future<void> clearRoomNotifications(String roomId) async {
    // 本地通知不支持按 tag 清除，需要自己管理通知 ID
  }

  /// 设置徽章数量 (iOS)
  Future<void> setBadgeCount(int count) async {
    // iOS 可以通过 flutter_app_badger 包实现
  }
}

/// 后台消息处理器（必须是顶级函数）
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // 后台消息处理逻辑
  print('Background message: ${message.messageId}');
}
