import '../../../../core/security/secure_storage.dart';

abstract class AuthLocalDataSource {
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  });

  Future<String?> getAccessToken();
  Future<String?> getRefreshToken();
  Future<void> clearAuth();
}

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  final SecureStorageService _storage;

  AuthLocalDataSourceImpl(this._storage);

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.saveTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
  }

  @override
  Future<String?> getAccessToken() async {
    return _storage.getAccessToken();
  }

  @override
  Future<String?> getRefreshToken() async {
    return _storage.getRefreshToken();
  }

  @override
  Future<void> clearAuth() async {
    await _storage.clearAuth();
  }
}
