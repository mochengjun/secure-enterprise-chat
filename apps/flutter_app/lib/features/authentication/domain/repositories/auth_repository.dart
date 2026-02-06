import '../entities/user.dart';

abstract class AuthRepository {
  /// 用户登录
  Future<AuthResult> login({
    required String username,
    required String password,
    String? deviceId,
    String? deviceName,
    String? deviceType,
  });

  /// 用户注册
  Future<User> register({
    required String username,
    required String password,
    String? phoneNumber,
    String? email,
    String? displayName,
  });

  /// 刷新 Token
  Future<AuthResult> refreshToken(String refreshToken);

  /// 登出
  Future<void> logout();

  /// 获取当前用户
  Future<User?> getCurrentUser();

  /// 检查是否已登录
  Future<bool> isLoggedIn();

  /// 验证 MFA
  Future<AuthResult> verifyMFA({
    required String username,
    required String password,
    required String code,
    String? deviceId,
  });
}

class AuthResult {
  final String? accessToken;
  final String? refreshToken;
  final int? expiresIn;
  final bool mfaRequired;
  final User? user;

  const AuthResult({
    this.accessToken,
    this.refreshToken,
    this.expiresIn,
    this.mfaRequired = false,
    this.user,
  });
}
