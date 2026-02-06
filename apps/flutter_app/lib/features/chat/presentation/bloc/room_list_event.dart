import 'package:equatable/equatable.dart';
import '../../domain/entities/room.dart';

abstract class RoomListEvent extends Equatable {
  const RoomListEvent();

  @override
  List<Object?> get props => [];
}

class LoadRooms extends RoomListEvent {
  const LoadRooms();
}

class RefreshRooms extends RoomListEvent {
  const RefreshRooms();
}

class CreateRoom extends RoomListEvent {
  final String name;
  final String? description;
  final RoomType type;
  final List<String>? memberIds;
  final int? retentionHours;

  const CreateRoom({
    required this.name,
    this.description,
    this.type = RoomType.group,
    this.memberIds,
    this.retentionHours,
  });

  @override
  List<Object?> get props => [name, description, type, memberIds, retentionHours];
}

class RoomUpdated extends RoomListEvent {
  final Room room;

  const RoomUpdated(this.room);

  @override
  List<Object?> get props => [room];
}

class MuteRoom extends RoomListEvent {
  final String roomId;
  final bool muted;

  const MuteRoom({required this.roomId, required this.muted});

  @override
  List<Object?> get props => [roomId, muted];
}

class PinRoom extends RoomListEvent {
  final String roomId;
  final bool pinned;

  const PinRoom({required this.roomId, required this.pinned});

  @override
  List<Object?> get props => [roomId, pinned];
}

class LeaveRoom extends RoomListEvent {
  final String roomId;

  const LeaveRoom(this.roomId);

  @override
  List<Object?> get props => [roomId];
}
