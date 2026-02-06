import 'package:equatable/equatable.dart';
import '../../domain/entities/room.dart';

abstract class RoomListState extends Equatable {
  const RoomListState();

  @override
  List<Object?> get props => [];
}

class RoomListInitial extends RoomListState {
  const RoomListInitial();
}

class RoomListLoading extends RoomListState {
  const RoomListLoading();
}

class RoomListLoaded extends RoomListState {
  final List<Room> rooms;
  final bool isCreatingRoom;

  const RoomListLoaded({
    required this.rooms,
    this.isCreatingRoom = false,
  });

  RoomListLoaded copyWith({
    List<Room>? rooms,
    bool? isCreatingRoom,
  }) {
    return RoomListLoaded(
      rooms: rooms ?? this.rooms,
      isCreatingRoom: isCreatingRoom ?? this.isCreatingRoom,
    );
  }

  @override
  List<Object?> get props => [rooms, isCreatingRoom];
}

class RoomListError extends RoomListState {
  final String message;
  final List<Room>? cachedRooms;

  const RoomListError({
    required this.message,
    this.cachedRooms,
  });

  @override
  List<Object?> get props => [message, cachedRooms];
}
