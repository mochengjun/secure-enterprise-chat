import '../repositories/auth_repository.dart';

class LoginUseCase {
  final AuthRepository _repository;

  LoginUseCase(this._repository);

  Future<AuthResult> call({
    required String username,
    required String password,
    String? deviceId,
    String? deviceName,
    String? deviceType,
  }) {
    return _repository.login(
      username: username,
      password: password,
      deviceId: deviceId,
      deviceName: deviceName,
      deviceType: deviceType,
    );
  }
}
