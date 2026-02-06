import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/di/injection.dart';
import '../../domain/entities/room.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/chat_repository.dart';

class AddMembersPage extends StatefulWidget {
  final Room room;

  const AddMembersPage({super.key, required this.room});

  @override
  State<AddMembersPage> createState() => _AddMembersPageState();
}

class _AddMembersPageState extends State<AddMembersPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _userIdController = TextEditingController();
  
  final Set<String> _selectedUserIds = {};
  final List<String> _manualUserIds = [];
  List<User> _searchResults = [];
  bool _isSearching = false;
  bool _isSubmitting = false;
  Timer? _debounce;

  late ChatRepository _chatRepository;
  Set<String> _existingMemberIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _chatRepository = getIt<ChatRepository>();
    _existingMemberIds = widget.room.members.map((m) => m.userId).toSet();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _userIdController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final results = await _chatRepository.searchUsers(query.trim());
        if (mounted) {
          setState(() {
            _searchResults = results
                .where((u) => !_existingMemberIds.contains(u.id))
                .toList();
            _isSearching = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isSearching = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('搜索失败: ${e.toString()}')),
          );
        }
      }
    });
  }

  void _toggleUserSelection(User user) {
    setState(() {
      if (_selectedUserIds.contains(user.id)) {
        _selectedUserIds.remove(user.id);
      } else {
        _selectedUserIds.add(user.id);
      }
    });
  }

  void _addManualUserId() {
    final userId = _userIdController.text.trim();
    if (userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入用户ID')),
      );
      return;
    }

    if (!userId.startsWith('@') || !userId.contains(':')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('用户ID格式错误，应为 @username:domain')),
      );
      return;
    }

    if (_existingMemberIds.contains(userId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('该用户已是群成员')),
      );
      return;
    }

    if (_manualUserIds.contains(userId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('该用户已添加到列表')),
      );
      return;
    }

    setState(() {
      _manualUserIds.add(userId);
      _userIdController.clear();
    });
  }

  void _removeManualUserId(String userId) {
    setState(() {
      _manualUserIds.remove(userId);
    });
  }

  int get _totalSelectedCount => _selectedUserIds.length + _manualUserIds.length;

  Future<void> _submitAddMembers() async {
    final allUserIds = [..._selectedUserIds, ..._manualUserIds];
    if (allUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择或输入至少一个用户')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await _chatRepository.addRoomMembers(widget.room.id, allUserIds);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('成功添加 ${allUserIds.length} 名成员')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('添加失败: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('添加群成员'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '搜索用户'),
            Tab(text: '输入ID'),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSearchTab(theme),
                _buildManualInputTab(theme),
              ],
            ),
          ),
          _buildBottomBar(theme),
        ],
      ),
    );
  }

  Widget _buildSearchTab(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '搜索用户名或邮箱...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _isSearching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onChanged: _onSearchChanged,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _buildSearchResults(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(ThemeData theme) {
    if (_searchController.text.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_search, size: 64, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              '请输入关键词搜索用户',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      );
    }

    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off, size: 64, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              '未找到匹配的用户',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        final isSelected = _selectedUserIds.contains(user.id);

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: theme.colorScheme.primaryContainer,
            backgroundImage: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                ? NetworkImage(user.avatarUrl!)
                : null,
            child: user.avatarUrl == null || user.avatarUrl!.isEmpty
                ? Text(
                    user.displayName.isNotEmpty
                        ? user.displayName[0].toUpperCase()
                        : '?',
                    style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
                  )
                : null,
          ),
          title: Text(user.displayName),
          subtitle: Text('@${user.username}'),
          trailing: Checkbox(
            value: isSelected,
            onChanged: (_) => _toggleUserSelection(user),
          ),
          onTap: () => _toggleUserSelection(user),
        );
      },
    );
  }

  Widget _buildManualInputTab(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _userIdController,
                  decoration: InputDecoration(
                    hintText: '@username:sec-chat.local',
                    labelText: '用户ID',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onSubmitted: (_) => _addManualUserId(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _addManualUserId,
                child: const Text('添加'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '提示: 用户ID格式为 @username:sec-chat.local',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 16),
          if (_manualUserIds.isNotEmpty) ...[
            Text(
              '已添加 (${_manualUserIds.length}):',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: _manualUserIds.length,
                itemBuilder: (context, index) {
                  final userId = _manualUserIds[index];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Text(
                          userId.substring(1, 2).toUpperCase(),
                          style: TextStyle(
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      title: Text(userId),
                      trailing: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => _removeManualUserId(userId),
                      ),
                    ),
                  );
                },
              ),
            ),
          ] else
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person_add_alt_1,
                      size: 64,
                      color: theme.colorScheme.outline,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '输入用户ID并点击添加',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_totalSelectedCount > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '已选择 $_totalSelectedCount 人',
                    style: TextStyle(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting || _totalSelectedCount == 0
                    ? null
                    : _submitAddMembers,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _totalSelectedCount > 0
                            ? '确定添加 ($_totalSelectedCount)'
                            : '确定添加',
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
