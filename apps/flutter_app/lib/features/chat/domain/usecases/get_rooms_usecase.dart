import '../entities/room.dart';
import '../repositories/chat_repository.dart';

class GetRoomsUseCase {
  final ChatRepository repository;

  GetRoomsUseCase(this.repository);

  Future<List<Room>> call() async {
    return await repository.getRooms();
  }
}
