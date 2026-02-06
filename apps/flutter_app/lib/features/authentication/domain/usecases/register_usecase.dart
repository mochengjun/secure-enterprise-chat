import '../entities/user.dart';
import '../repositories/auth_repository.dart';

class RegisterUseCase {
  final AuthRepository _repository;

  RegisterUseCase(this._repository);

  Future<User> call({
    required String username,
    required String password,
    String? phoneNumber,
    String? email,
    String? displayName,
  }) {
    return _repository.register(
      username: username,
      password: password,
      phoneNumber: phoneNumber,
      email: email,
      displayName: displayName,
    );
  }
}
