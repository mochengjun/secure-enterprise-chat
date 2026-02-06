import '../entities/message.dart';
import '../repositories/chat_repository.dart';

class GetMessagesUseCase {
  final ChatRepository repository;

  GetMessagesUseCase(this.repository);

  Future<List<Message>> call({
    required String roomId,
    int limit = 50,
    String? beforeId,
  }) async {
    return await repository.getMessages(
      roomId: roomId,
      limit: limit,
      beforeId: beforeId,
    );
  }
}
