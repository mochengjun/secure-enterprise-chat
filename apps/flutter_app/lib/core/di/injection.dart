import 'dart:io' show Platform;
import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
import '../network/dio_client.dart';
import '../network/websocket_client.dart';
import '../security/secure_storage.dart';
import '../services/push_notification_service.dart';
import '../services/media_service.dart';
import '../services/webrtc_service.dart';
import '../services/e2ee_service.dart';

// Auth imports
import '../../features/authentication/data/datasources/auth_remote_datasource.dart';
import '../../features/authentication/data/datasources/auth_local_datasource.dart';
import '../../features/authentication/data/repositories/auth_repository_impl.dart';
import '../../features/authentication/domain/repositories/auth_repository.dart';
import '../../features/authentication/domain/usecases/login_usecase.dart';
import '../../features/authentication/domain/usecases/register_usecase.dart';
import '../../features/authentication/domain/usecases/logout_usecase.dart';
import '../../features/authentication/presentation/bloc/auth_bloc.dart';

// Chat imports
import '../../features/chat/data/datasources/chat_remote_datasource.dart';
import '../../features/chat/data/datasources/chat_local_datasource.dart';
import '../../features/chat/data/repositories/chat_repository_impl.dart';
import '../../features/chat/domain/repositories/chat_repository.dart';
import '../../features/chat/domain/usecases/get_rooms_usecase.dart';
import '../../features/chat/domain/usecases/get_messages_usecase.dart';
import '../../features/chat/domain/usecases/send_message_usecase.dart';
import '../../features/chat/domain/usecases/create_room_usecase.dart';
import '../../features/chat/domain/usecases/mark_as_read_usecase.dart';
import '../../features/chat/presentation/bloc/room_list_bloc.dart';
import '../../features/chat/presentation/bloc/chat_room_bloc.dart';

// Call imports
import '../../features/call/services/audio_session_manager.dart';
import '../../features/call/presentation/bloc/call_bloc.dart';

final getIt = GetIt.instance;

/// 服务器IP地址配置
/// 修改此值为服务器的实际IP地址以从其他设备访问
const String _serverHost = '192.168.0.39';
const int _serverPort = 8081;

/// 获取 API 基础地址
/// Android 模拟器需要使用 10.0.2.2 访问宿主机
String getApiBaseUrl() {
  if (Platform.isAndroid) {
    // Android 真机使用服务器IP
    // Android 模拟器使用 10.0.2.2 访问宿主机
    // 如果是真机测试，使用服务器IP
    return 'http://$_serverHost:$_serverPort/api/v1';
  }
  // 桌面平台使用服务器IP（支持远程访问）
  return 'http://$_serverHost:$_serverPort/api/v1';
}

Future<void> configureDependencies() async {
  final apiBaseUrl = getApiBaseUrl();
  
  // Core
  getIt.registerLazySingleton<SecureStorageService>(() => SecureStorageService());
  getIt.registerLazySingleton<Dio>(() => createDio(apiBaseUrl));
  getIt.registerLazySingleton<DioClient>(() => DioClient(getIt<Dio>()));
  
  // WebSocket Client
  getIt.registerLazySingleton<WebSocketClient>(() => WebSocketClient(
    baseUrl: apiBaseUrl,
    tokenProvider: () {
      final storage = getIt<SecureStorageService>();
      return storage.getAccessTokenSync() ?? '';
    },
  ));

  // ==================== Auth Module ====================
  
  // Auth Data Sources
  getIt.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(getIt<DioClient>()),
  );
  getIt.registerLazySingleton<AuthLocalDataSource>(
    () => AuthLocalDataSourceImpl(getIt<SecureStorageService>()),
  );

  // Auth Repositories
  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      remoteDataSource: getIt<AuthRemoteDataSource>(),
      localDataSource: getIt<AuthLocalDataSource>(),
    ),
  );

  // Auth Use Cases
  getIt.registerLazySingleton(() => LoginUseCase(getIt<AuthRepository>()));
  getIt.registerLazySingleton(() => RegisterUseCase(getIt<AuthRepository>()));
  getIt.registerLazySingleton(() => LogoutUseCase(getIt<AuthRepository>()));

  // Auth Blocs
  getIt.registerFactory(() => AuthBloc(
    loginUseCase: getIt<LoginUseCase>(),
    registerUseCase: getIt<RegisterUseCase>(),
    logoutUseCase: getIt<LogoutUseCase>(),
  ));

  // ==================== Chat Module ====================
  
  // Chat Local Data Source (needs initialization)
  final chatLocalDataSource = ChatLocalDataSourceImpl();
  await chatLocalDataSource.init();
  getIt.registerLazySingleton<ChatLocalDataSource>(() => chatLocalDataSource);
  
  // Chat Remote Data Source
  getIt.registerLazySingleton<ChatRemoteDataSource>(
    () => ChatRemoteDataSourceImpl(getIt<DioClient>()),
  );

  // Chat Repository
  getIt.registerLazySingleton<ChatRepository>(
    () => ChatRepositoryImpl(
      remoteDataSource: getIt<ChatRemoteDataSource>(),
      localDataSource: getIt<ChatLocalDataSource>(),
      webSocketClient: getIt<WebSocketClient>(),
    ),
  );

  // Chat Use Cases
  getIt.registerLazySingleton(() => GetRoomsUseCase(getIt<ChatRepository>()));
  getIt.registerLazySingleton(() => GetMessagesUseCase(getIt<ChatRepository>()));
  getIt.registerLazySingleton(() => SendMessageUseCase(getIt<ChatRepository>()));
  getIt.registerLazySingleton(() => CreateRoomUseCase(getIt<ChatRepository>()));
  getIt.registerLazySingleton(() => MarkAsReadUseCase(getIt<ChatRepository>()));

  // Chat Blocs
  getIt.registerFactory(() => RoomListBloc(
    getRoomsUseCase: getIt<GetRoomsUseCase>(),
    createRoomUseCase: getIt<CreateRoomUseCase>(),
    repository: getIt<ChatRepository>(),
  ));
  
  getIt.registerFactory(() => ChatRoomBloc(
    getMessagesUseCase: getIt<GetMessagesUseCase>(),
    sendMessageUseCase: getIt<SendMessageUseCase>(),
    markAsReadUseCase: getIt<MarkAsReadUseCase>(),
    repository: getIt<ChatRepository>(),
  ));

  // ==================== Push Notification Module ====================
  
  getIt.registerLazySingleton<PushNotificationService>(
    () => PushNotificationService(
      dio: getIt<Dio>(),
      baseUrl: apiBaseUrl,
    ),
  );

  // ==================== Media Module ====================
  
  final mediaService = MediaService(
    dio: getIt<Dio>(),
    baseUrl: apiBaseUrl,
  );
  await mediaService.initialize();
  getIt.registerLazySingleton<MediaService>(() => mediaService);

  // ==================== WebRTC Module ====================
  
  final webrtcService = WebRTCService(
    dio: getIt<Dio>(),
    baseUrl: apiBaseUrl,
    tokenProvider: () {
      final storage = getIt<SecureStorageService>();
      return storage.getAccessTokenSync() ?? '';
    },
  );
  await webrtcService.initialize();
  getIt.registerLazySingleton<WebRTCService>(() => webrtcService);

  // ==================== Call Module ====================
  
  // Audio Session Manager
  final audioSessionManager = AudioSessionManager();
  await audioSessionManager.initialize();
  getIt.registerLazySingleton<AudioSessionManager>(() => audioSessionManager);

  // Call BLoC
  getIt.registerFactory(() => CallBloc(
    webrtcService: getIt<WebRTCService>(),
    audioSessionManager: getIt<AudioSessionManager>(),
  ));

  // ==================== E2EE Module ====================
  
  final e2eeService = E2EEService(
    dio: getIt<Dio>(),
    baseUrl: apiBaseUrl,
  );
  await e2eeService.initialize();
  getIt.registerLazySingleton<E2EEService>(() => e2eeService);
}

Dio createDio(String baseUrl) {
  final dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  ));

  // 添加Auth拦截器，自动为请求添加Authorization header
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      final storage = getIt<SecureStorageService>();
      final token = storage.getAccessTokenSync();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    },
  ));

  dio.interceptors.add(LogInterceptor(
    requestBody: true,
    responseBody: true,
  ));

  return dio;
}
