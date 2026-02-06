import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection.dart';
import '../../domain/entities/room.dart';
import '../bloc/room_list_bloc.dart';
import '../bloc/room_list_event.dart';
import '../bloc/room_list_state.dart';
import '../widgets/room_list_item.dart';

class RoomListPage extends StatelessWidget {
  const RoomListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<RoomListBloc>()..add(const LoadRooms()),
      child: const _RoomListView(),
    );
  }
}

class _RoomListView extends StatelessWidget {
  const _RoomListView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('消息'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _showSearchDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showMoreMenu(context),
          ),
        ],
      ),
      body: BlocBuilder<RoomListBloc, RoomListState>(
        builder: (context, state) {
          if (state is RoomListLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (state is RoomListError) {
            return _buildErrorView(context, state);
          }
          
          if (state is RoomListLoaded) {
            return _buildRoomList(context, state);
          }
          
          return const Center(child: Text('加载中...'));
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateRoomDialog(context),
        child: const Icon(Icons.chat),
      ),
    );
  }

  Widget _buildRoomList(BuildContext context, RoomListLoaded state) {
    if (state.rooms.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              '暂无会话',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _showCreateRoomDialog(context),
              child: const Text('开始新聊天'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        context.read<RoomListBloc>().add(const RefreshRooms());
      },
      child: ListView.builder(
        itemCount: state.rooms.length,
        itemBuilder: (context, index) {
          final room = state.rooms[index];
          return RoomListItem(
            room: room,
            onTap: () => context.push('/room/${room.id}'),
            onLongPress: () => _showRoomOptions(context, room),
          );
        },
      ),
    );
  }

  Widget _buildErrorView(BuildContext context, RoomListError state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            '加载失败',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            state.message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              context.read<RoomListBloc>().add(const LoadRooms());
            },
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }

  void _showSearchDialog(BuildContext context) {
    showSearch(
      context: context,
      delegate: _RoomSearchDelegate(),
    );
  }

  void _showMoreMenu(BuildContext context) {
    final bloc = context.read<RoomListBloc>();
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.group_add),
              title: const Text('创建群聊'),
              onTap: () {
                Navigator.pop(sheetContext);
                _showCreateRoomDialogWithBloc(context, bloc, isGroup: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_add),
              title: const Text('添加好友'),
              onTap: () {
                Navigator.pop(sheetContext);
              },
            ),
            ListTile(
              leading: const Icon(Icons.qr_code_scanner),
              title: const Text('扫一扫'),
              onTap: () {
                Navigator.pop(sheetContext);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateRoomDialog(BuildContext context, {bool isGroup = false}) {
    final bloc = context.read<RoomListBloc>();
    _showCreateRoomDialogWithBloc(context, bloc, isGroup: isGroup);
  }

  void _showCreateRoomDialogWithBloc(BuildContext context, RoomListBloc bloc, {bool isGroup = false}) {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isGroup ? '创建群聊' : '新建会话'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: '名称',
                hintText: '输入会话名称',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: '描述 (可选)',
                hintText: '输入会话描述',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                bloc.add(CreateRoom(
                  name: nameController.text.trim(),
                  description: descController.text.trim().isNotEmpty 
                      ? descController.text.trim() 
                      : null,
                  type: isGroup ? RoomType.group : RoomType.direct,
                ));
                Navigator.pop(dialogContext);
              }
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  void _showRoomOptions(BuildContext context, Room room) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(room.isPinned ? Icons.push_pin_outlined : Icons.push_pin),
              title: Text(room.isPinned ? '取消置顶' : '置顶'),
              onTap: () {
                context.read<RoomListBloc>().add(PinRoom(
                  roomId: room.id,
                  pinned: !room.isPinned,
                ));
                Navigator.pop(sheetContext);
              },
            ),
            ListTile(
              leading: Icon(room.isMuted ? Icons.notifications : Icons.notifications_off),
              title: Text(room.isMuted ? '取消静音' : '静音'),
              onTap: () {
                context.read<RoomListBloc>().add(MuteRoom(
                  roomId: room.id,
                  muted: !room.isMuted,
                ));
                Navigator.pop(sheetContext);
              },
            ),
            ListTile(
              leading: const Icon(Icons.exit_to_app),
              title: const Text('退出会话'),
              onTap: () {
                Navigator.pop(sheetContext);
                _confirmLeaveRoom(context, room);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmLeaveRoom(BuildContext context, Room room) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('退出会话'),
        content: Text('确定要退出 "${room.name}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              context.read<RoomListBloc>().add(LeaveRoom(room.id));
              Navigator.pop(dialogContext);
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('退出'),
          ),
        ],
      ),
    );
  }
}

class _RoomSearchDelegate extends SearchDelegate<Room?> {
  @override
  String get searchFieldLabel => '搜索会话';

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults(context);
  }

  Widget _buildSearchResults(BuildContext context) {
    if (query.isEmpty) {
      return const Center(child: Text('输入关键词搜索'));
    }
    
    return Center(
      child: Text('搜索 "$query" 的结果'),
    );
  }
}
