import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../../../core/network/dio_client.dart';

abstract class AuthRemoteDataSource {
  Future<AuthResult> login({
    required String username,
    required String password,
    String? deviceId,
    String? deviceName,
    String? deviceType,
  });

  Future<User> register({
    required String username,
    required String password,
    String? phoneNumber,
    String? email,
    String? displayName,
  });

  Future<AuthResult> refreshToken(String refreshToken);

  Future<void> logout({String? refreshToken});

  Future<User> getCurrentUser();

  Future<AuthResult> verifyMFA({
    required String username,
    required String password,
    required String code,
    String? deviceId,
  });
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final DioClient _client;

  AuthRemoteDataSourceImpl(this._client);

  @override
  Future<AuthResult> login({
    required String username,
    required String password,
    String? deviceId,
    String? deviceName,
    String? deviceType,
  }) async {
    final response = await _client.post(
      '/auth/login',
      data: {
        'username': username,
        'password': password,
        if (deviceId != null) 'device_id': deviceId,
        if (deviceName != null) 'device_name': deviceName,
        if (deviceType != null) 'device_type': deviceType,
      },
    );

    final data = response.data;
    
    if (data['mfa_required'] == true) {
      return const AuthResult(mfaRequired: true);
    }

    _client.setAuthToken(data['access_token']);

    return AuthResult(
      accessToken: data['access_token'],
      refreshToken: data['refresh_token'],
      expiresIn: data['expires_in'],
    );
  }

  @override
  Future<User> register({
    required String username,
    required String password,
    String? phoneNumber,
    String? email,
    String? displayName,
  }) async {
    final response = await _client.post(
      '/auth/register',
      data: {
        'username': username,
        'password': password,
        if (phoneNumber != null) 'phone_number': phoneNumber,
        if (email != null) 'email': email,
        if (displayName != null) 'display_name': displayName,
      },
    );

    final data = response.data;
    return User(
      userId: data['user_id'],
      username: data['username'],
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<AuthResult> refreshToken(String refreshToken) async {
    final response = await _client.post(
      '/auth/refresh',
      data: {'refresh_token': refreshToken},
    );

    final data = response.data;
    _client.setAuthToken(data['access_token']);

    return AuthResult(
      accessToken: data['access_token'],
      refreshToken: data['refresh_token'],
      expiresIn: data['expires_in'],
    );
  }

  @override
  Future<void> logout({String? refreshToken}) async {
    await _client.post(
      '/auth/logout',
      data: {
        if (refreshToken != null) 'refresh_token': refreshToken,
      },
    );
    _client.clearAuthToken();
  }

  @override
  Future<User> getCurrentUser() async {
    final response = await _client.get('/auth/me');
    final data = response.data;

    return User(
      userId: data['user_id'],
      username: data['username'],
      phoneNumber: data['phone_number'],
      email: data['email'],
      displayName: data['display_name'],
      avatarUrl: data['avatar_url'],
      mfaEnabled: data['mfa_enabled'] ?? false,
      isActive: data['is_active'] ?? true,
      createdAt: DateTime.parse(data['created_at']),
    );
  }

  @override
  Future<AuthResult> verifyMFA({
    required String username,
    required String password,
    required String code,
    String? deviceId,
  }) async {
    final response = await _client.post(
      '/auth/verify-mfa',
      data: {
        'username': username,
        'password': password,
        'code': code,
        if (deviceId != null) 'device_id': deviceId,
      },
    );

    final data = response.data;
    _client.setAuthToken(data['access_token']);

    return AuthResult(
      accessToken: data['access_token'],
      refreshToken: data['refresh_token'],
      expiresIn: data['expires_in'],
    );
  }
}
