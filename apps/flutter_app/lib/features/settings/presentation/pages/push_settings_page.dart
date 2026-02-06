import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../../../core/services/push_notification_service.dart';

class PushSettingsPage extends StatefulWidget {
  const PushSettingsPage({super.key});

  @override
  State<PushSettingsPage> createState() => _PushSettingsPageState();
}

class _PushSettingsPageState extends State<PushSettingsPage> {
  late PushNotificationService _pushService;
  PushSettings _settings = PushSettings();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _pushService = GetIt.instance<PushNotificationService>();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await _pushService.getSettings();
      setState(() {
        _settings = settings;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('加载设置失败')),
        );
      }
    }
  }

  Future<void> _updateSettings(PushSettings newSettings) async {
    setState(() => _settings = newSettings);
    try {
      await _pushService.updateSettings(newSettings);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存设置失败')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('推送通知设置'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // 主开关
                _buildSection(
                  title: '通知开关',
                  children: [
                    SwitchListTile(
                      title: const Text('启用推送通知'),
                      subtitle: const Text('关闭后将不会收到任何推送'),
                      value: _settings.enablePush,
                      onChanged: (value) {
                        _updateSettings(_settings.copyWith(enablePush: value));
                      },
                    ),
                  ],
                ),

                // 通知样式
                _buildSection(
                  title: '通知样式',
                  children: [
                    SwitchListTile(
                      title: const Text('通知声音'),
                      subtitle: const Text('收到消息时播放提示音'),
                      value: _settings.enableSound,
                      onChanged: _settings.enablePush
                          ? (value) {
                              _updateSettings(
                                  _settings.copyWith(enableSound: value));
                            }
                          : null,
                    ),
                    SwitchListTile(
                      title: const Text('振动'),
                      subtitle: const Text('收到消息时振动提示'),
                      value: _settings.enableVibration,
                      onChanged: _settings.enablePush
                          ? (value) {
                              _updateSettings(
                                  _settings.copyWith(enableVibration: value));
                            }
                          : null,
                    ),
                    SwitchListTile(
                      title: const Text('消息预览'),
                      subtitle: const Text('在通知中显示消息内容'),
                      value: _settings.enablePreview,
                      onChanged: _settings.enablePush
                          ? (value) {
                              _updateSettings(
                                  _settings.copyWith(enablePreview: value));
                            }
                          : null,
                    ),
                  ],
                ),

                // 免打扰
                _buildSection(
                  title: '免打扰时段',
                  children: [
                    ListTile(
                      title: const Text('设置免打扰时段'),
                      subtitle: Text(
                        _settings.quietHoursStart != null &&
                                _settings.quietHoursEnd != null
                            ? '${_settings.quietHoursStart}:00 - ${_settings.quietHoursEnd}:00'
                            : '未设置',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _settings.enablePush ? _showQuietHoursDialog : null,
                    ),
                  ],
                ),

                // 静音房间
                _buildSection(
                  title: '静音群组',
                  children: [
                    ListTile(
                      title: const Text('管理静音群组'),
                      subtitle: Text(
                        _settings.mutedRooms.isEmpty
                            ? '无静音群组'
                            : '${_settings.mutedRooms.length} 个群组已静音',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _settings.enablePush ? _showMutedRoomsDialog : null,
                    ),
                  ],
                ),

                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        ...children,
        const Divider(height: 1),
      ],
    );
  }

  Future<void> _showQuietHoursDialog() async {
    int startHour = _settings.quietHoursStart ?? 22;
    int endHour = _settings.quietHoursEnd ?? 8;

    final result = await showDialog<Map<String, int>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('设置免打扰时段'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Text('开始时间: '),
                      DropdownButton<int>(
                        value: startHour,
                        items: List.generate(24, (i) => i)
                            .map((h) => DropdownMenuItem(
                                  value: h,
                                  child: Text('$h:00'),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => startHour = value);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('结束时间: '),
                      DropdownButton<int>(
                        value: endHour,
                        items: List.generate(24, (i) => i)
                            .map((h) => DropdownMenuItem(
                                  value: h,
                                  child: Text('$h:00'),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => endHour = value);
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context, {'clear': 0});
                  },
                  child: const Text('清除'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(context, {'start': startHour, 'end': endHour});
                  },
                  child: const Text('确定'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      if (result.containsKey('clear')) {
        _updateSettings(_settings.copyWith(
          quietHoursStart: null,
          quietHoursEnd: null,
        ));
      } else {
        _updateSettings(_settings.copyWith(
          quietHoursStart: result['start'],
          quietHoursEnd: result['end'],
        ));
      }
    }
  }

  Future<void> _showMutedRoomsDialog() async {
    // TODO: 实现静音群组管理界面
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('静音群组管理功能开发中')),
    );
  }
}
