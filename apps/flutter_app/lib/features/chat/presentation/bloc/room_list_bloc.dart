import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/room.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/usecases/get_rooms_usecase.dart';
import '../../domain/usecases/create_room_usecase.dart';
import 'room_list_event.dart';
import 'room_list_state.dart';

class RoomListBloc extends Bloc<RoomListEvent, RoomListState> {
  final GetRoomsUseCase _getRoomsUseCase;
  final CreateRoomUseCase _createRoomUseCase;
  final ChatRepository _repository;
  
  StreamSubscription<Room>? _roomUpdateSubscription;

  RoomListBloc({
    required GetRoomsUseCase getRoomsUseCase,
    required CreateRoomUseCase createRoomUseCase,
    required ChatRepository repository,
  })  : _getRoomsUseCase = getRoomsUseCase,
        _createRoomUseCase = createRoomUseCase,
        _repository = repository,
        super(const RoomListInitial()) {
    on<LoadRooms>(_onLoadRooms);
    on<RefreshRooms>(_onRefreshRooms);
    on<CreateRoom>(_onCreateRoom);
    on<RoomUpdated>(_onRoomUpdated);
    on<MuteRoom>(_onMuteRoom);
    on<PinRoom>(_onPinRoom);
    on<LeaveRoom>(_onLeaveRoom);

    _roomUpdateSubscription = _repository.roomUpdateStream.listen((room) {
      add(RoomUpdated(room));
    });
  }

  Future<void> _onLoadRooms(
    LoadRooms event,
    Emitter<RoomListState> emit,
  ) async {
    emit(const RoomListLoading());
    
    try {
      await _repository.connect();
      final rooms = await _getRoomsUseCase();
      emit(RoomListLoaded(rooms: _sortRooms(rooms)));
    } catch (e) {
      emit(RoomListError(message: e.toString()));
    }
  }

  Future<void> _onRefreshRooms(
    RefreshRooms event,
    Emitter<RoomListState> emit,
  ) async {
    try {
      final rooms = await _getRoomsUseCase();
      emit(RoomListLoaded(rooms: _sortRooms(rooms)));
    } catch (e) {
      final currentState = state;
      if (currentState is RoomListLoaded) {
        emit(RoomListError(
          message: e.toString(),
          cachedRooms: currentState.rooms,
        ));
      } else {
        emit(RoomListError(message: e.toString()));
      }
    }
  }

  Future<void> _onCreateRoom(
    CreateRoom event,
    Emitter<RoomListState> emit,
  ) async {
    final currentState = state;
    if (currentState is RoomListLoaded) {
      emit(currentState.copyWith(isCreatingRoom: true));
      
      try {
        final room = await _createRoomUseCase(
          name: event.name,
          description: event.description,
          type: event.type,
          memberIds: event.memberIds,
          retentionHours: event.retentionHours,
        );
        
        final updatedRooms = [room, ...currentState.rooms];
        emit(RoomListLoaded(rooms: _sortRooms(updatedRooms)));
      } catch (e) {
        emit(currentState.copyWith(isCreatingRoom: false));
        emit(RoomListError(
          message: '创建房间失败: ${e.toString()}',
          cachedRooms: currentState.rooms,
        ));
      }
    }
  }

  void _onRoomUpdated(
    RoomUpdated event,
    Emitter<RoomListState> emit,
  ) {
    final currentState = state;
    if (currentState is RoomListLoaded) {
      final updatedRooms = currentState.rooms.map((room) {
        return room.id == event.room.id ? event.room : room;
      }).toList();
      
      emit(RoomListLoaded(rooms: _sortRooms(updatedRooms)));
    }
  }

  Future<void> _onMuteRoom(
    MuteRoom event,
    Emitter<RoomListState> emit,
  ) async {
    final currentState = state;
    if (currentState is RoomListLoaded) {
      try {
        await _repository.muteRoom(event.roomId, event.muted);
        
        final updatedRooms = currentState.rooms.map((room) {
          return room.id == event.roomId
              ? room.copyWith(isMuted: event.muted)
              : room;
        }).toList();
        
        emit(RoomListLoaded(rooms: updatedRooms));
      } catch (e) {
        emit(RoomListError(
          message: e.toString(),
          cachedRooms: currentState.rooms,
        ));
      }
    }
  }

  Future<void> _onPinRoom(
    PinRoom event,
    Emitter<RoomListState> emit,
  ) async {
    final currentState = state;
    if (currentState is RoomListLoaded) {
      try {
        await _repository.pinRoom(event.roomId, event.pinned);
        
        final updatedRooms = currentState.rooms.map((room) {
          return room.id == event.roomId
              ? room.copyWith(isPinned: event.pinned)
              : room;
        }).toList();
        
        emit(RoomListLoaded(rooms: _sortRooms(updatedRooms)));
      } catch (e) {
        emit(RoomListError(
          message: e.toString(),
          cachedRooms: currentState.rooms,
        ));
      }
    }
  }

  Future<void> _onLeaveRoom(
    LeaveRoom event,
    Emitter<RoomListState> emit,
  ) async {
    final currentState = state;
    if (currentState is RoomListLoaded) {
      try {
        await _repository.leaveRoom(event.roomId);
        
        final updatedRooms = currentState.rooms
            .where((room) => room.id != event.roomId)
            .toList();
        
        emit(RoomListLoaded(rooms: updatedRooms));
      } catch (e) {
        emit(RoomListError(
          message: e.toString(),
          cachedRooms: currentState.rooms,
        ));
      }
    }
  }

  List<Room> _sortRooms(List<Room> rooms) {
    final pinned = rooms.where((r) => r.isPinned).toList();
    final unpinned = rooms.where((r) => !r.isPinned).toList();
    
    pinned.sort((a, b) => (b.updatedAt ?? b.createdAt)
        .compareTo(a.updatedAt ?? a.createdAt));
    unpinned.sort((a, b) => (b.updatedAt ?? b.createdAt)
        .compareTo(a.updatedAt ?? a.createdAt));
    
    return [...pinned, ...unpinned];
  }

  @override
  Future<void> close() {
    _roomUpdateSubscription?.cancel();
    return super.close();
  }
}
