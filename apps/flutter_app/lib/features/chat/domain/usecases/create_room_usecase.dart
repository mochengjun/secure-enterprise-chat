import '../entities/room.dart';
import '../repositories/chat_repository.dart';

class CreateRoomUseCase {
  final ChatRepository repository;

  CreateRoomUseCase(this.repository);

  Future<Room> call({
    required String name,
    String? description,
    RoomType type = RoomType.group,
    List<String>? memberIds,
    int? retentionHours,
  }) async {
    return await repository.createRoom(
      name: name,
      description: description,
      type: type,
      memberIds: memberIds,
      retentionHours: retentionHours,
    );
  }
}
