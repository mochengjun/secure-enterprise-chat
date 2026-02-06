import '../repositories/chat_repository.dart';

class MarkAsReadUseCase {
  final ChatRepository repository;

  MarkAsReadUseCase(this.repository);

  Future<void> call(String roomId, {String? messageId}) async {
    return await repository.markAsRead(roomId, messageId: messageId);
  }
}
