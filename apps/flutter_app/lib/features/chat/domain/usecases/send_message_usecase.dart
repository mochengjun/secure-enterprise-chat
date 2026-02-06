import '../entities/message.dart';
import '../repositories/chat_repository.dart';

class SendMessageUseCase {
  final ChatRepository repository;

  SendMessageUseCase(this.repository);

  Future<Message> call({
    required String roomId,
    required String content,
    MessageType type = MessageType.text,
    Map<String, dynamic>? metadata,
  }) async {
    return await repository.sendMessage(
      roomId: roomId,
      content: content,
      type: type,
      metadata: metadata,
    );
  }
}
