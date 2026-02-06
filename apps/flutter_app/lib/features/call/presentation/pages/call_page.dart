import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/services/webrtc_service.dart';
import '../bloc/call_bloc.dart';
import '../bloc/call_event.dart';
import '../bloc/call_state.dart';

/// 通话页面
class CallPage extends StatefulWidget {
  final CallInfo? call;
  final bool isIncoming;
  final List<String>? targetUserIds;
  final CallType? callType;
  final String? roomId;

  const CallPage({
    super.key,
    this.call,
    this.isIncoming = false,
    this.targetUserIds,
    this.callType,
    this.roomId,
  });

  @override
  State<CallPage> createState() => _CallPageState();
}

class _CallPageState extends State<CallPage> {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final Map<String, RTCVideoRenderer> _remoteRenderers = {};

  @override
  void initState() {
    super.initState();
    _initializeRenderers();
  }

  Future<void> _initializeRenderers() async {
    await _localRenderer.initialize();
    setState(() {});
  }

  void _setupRendererForUser(String userId, MediaStream stream) async {
    if (!_remoteRenderers.containsKey(userId)) {
      final renderer = RTCVideoRenderer();
      await renderer.initialize();
      renderer.srcObject = stream;
      setState(() {
        _remoteRenderers[userId] = renderer;
      });
    } else {
      _remoteRenderers[userId]!.srcObject = stream;
      setState(() {});
    }
  }

  void _removeRendererForUser(String userId) {
    final renderer = _remoteRenderers.remove(userId);
    renderer?.dispose();
    setState(() {});
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    for (final renderer in _remoteRenderers.values) {
      renderer.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final bloc = getIt<CallBloc>();

        // 设置远程流回调
        bloc.webrtcService.onRemoteStream = _setupRendererForUser;
        bloc.webrtcService.onParticipantLeft = _removeRendererForUser;

        // 设置本地视频流
        if (bloc.webrtcService.localStream != null) {
          _localRenderer.srcObject = bloc.webrtcService.localStream;
        }

        // 如果是来电
        if (widget.isIncoming && widget.call != null) {
          bloc.add(IncomingCallEvent(widget.call!));
        }
        // 如果是主动发起通话
        else if (widget.targetUserIds != null && widget.callType != null) {
          bloc.add(InitiateCallEvent(
            targetUserIds: widget.targetUserIds!,
            callType: widget.callType!,
            roomId: widget.roomId,
          ));
        }

        return bloc;
      },
      child: BlocConsumer<CallBloc, CallState>(
        listener: (context, state) {
          // 更新本地渲染器
          final bloc = context.read<CallBloc>();
          if (bloc.webrtcService.localStream != null) {
            _localRenderer.srcObject = bloc.webrtcService.localStream;
          }

          // 通话结束时退出页面
          if (state is CallEnded) {
            Navigator.of(context).pop(state);
          }

          // 显示错误信息
          if (state is CallError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          return Scaffold(
            backgroundColor: Colors.black,
            body: SafeArea(
              child: Stack(
                children: [
                  // 视频/音频显示
                  _buildMainContent(context, state),

                  // 来电接听界面
                  if (state is CallIncoming) _buildIncomingCallUI(context, state),

                  // 通话控制按钮
                  if (state is CallActive) _buildCallControls(context, state),

                  // 加载中
                  if (state is CallLoading) _buildLoadingOverlay(),

                  // 通话状态信息
                  _buildCallInfo(context, state),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMainContent(BuildContext context, CallState state) {
    CallInfo? call;
    bool isVideoOn = true;

    if (state is CallActive) {
      call = state.call;
      isVideoOn = state.isVideoOn;
    } else if (state is CallIncoming) {
      call = state.call;
    }

    if (call == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    final isVideoCall = call.callType == CallType.video;

    if (isVideoCall) {
      return _buildVideoView(isVideoOn);
    } else {
      return _buildAudioView(state);
    }
  }

  Widget _buildVideoView(bool isVideoOn) {
    return Stack(
      children: [
        // 远程视频（全屏）
        if (_remoteRenderers.isNotEmpty)
          Positioned.fill(
            child: RTCVideoView(
              _remoteRenderers.values.first,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            ),
          )
        else
          const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 60,
                  child: Icon(Icons.person, size: 60),
                ),
                SizedBox(height: 16),
                Text(
                  '等待连接...',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ],
            ),
          ),

        // 本地视频（小窗口）
        Positioned(
          right: 16,
          top: 16,
          child: GestureDetector(
            onTap: () {
              context.read<CallBloc>().add(const SwitchCameraEvent());
            },
            child: Container(
              width: 120,
              height: 160,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white, width: 2),
              ),
              clipBehavior: Clip.hardEdge,
              child: isVideoOn
                  ? RTCVideoView(
                      _localRenderer,
                      mirror: true,
                      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    )
                  : Container(
                      color: Colors.grey[800],
                      child: const Center(
                        child: Icon(Icons.videocam_off, color: Colors.white),
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAudioView(CallState state) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircleAvatar(
            radius: 80,
            child: Icon(Icons.person, size: 80),
          ),
          const SizedBox(height: 24),
          Text(
            _getCallStatusText(state),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          if (state is CallActive && state.call.status == CallStatus.connected)
            _buildCallDuration(state.call),
        ],
      ),
    );
  }

  Widget _buildCallDuration(CallInfo call) {
    return StreamBuilder(
      stream: Stream.periodic(const Duration(seconds: 1)),
      builder: (context, snapshot) {
        final duration = call.startedAt != null
            ? DateTime.now().difference(call.startedAt!)
            : Duration.zero;
        return Text(
          _formatDuration(duration),
          style: const TextStyle(color: Colors.white70, fontSize: 16),
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (duration.inHours > 0) {
      final hours = duration.inHours.toString().padLeft(2, '0');
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  String _getCallStatusText(CallState state) {
    if (state is CallActive) {
      switch (state.call.status) {
        case CallStatus.initiated:
          return '呼叫中...';
        case CallStatus.ringing:
          return '响铃中...';
        case CallStatus.connecting:
          return '连接中...';
        case CallStatus.connected:
          return '通话中';
        case CallStatus.ended:
          return '通话已结束';
        default:
          return '呼叫中...';
      }
    } else if (state is CallIncoming) {
      return '来电中...';
    } else if (state is CallLoading) {
      return '连接中...';
    }
    return '准备中...';
  }

  Widget _buildIncomingCallUI(BuildContext context, CallIncoming state) {
    final isVideoCall = state.call.callType == CallType.video;

    return Container(
      color: Colors.black.withOpacity(0.8),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 60,
              child: Icon(Icons.person, size: 60),
            ),
            const SizedBox(height: 24),
            Text(
              state.callerName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isVideoCall ? '视频来电' : '语音来电',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 48),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 拒绝按钮
                Column(
                  children: [
                    FloatingActionButton(
                      heroTag: 'reject',
                      onPressed: () {
                        context.read<CallBloc>().add(RejectCallEvent(state.call.id));
                      },
                      backgroundColor: Colors.red,
                      child: const Icon(Icons.call_end),
                    ),
                    const SizedBox(height: 8),
                    const Text('拒绝', style: TextStyle(color: Colors.white)),
                  ],
                ),
                const SizedBox(width: 64),
                // 接听按钮
                Column(
                  children: [
                    FloatingActionButton(
                      heroTag: 'accept',
                      onPressed: () {
                        context.read<CallBloc>().add(AcceptCallEvent(state.call.id));
                      },
                      backgroundColor: Colors.green,
                      child: Icon(isVideoCall ? Icons.videocam : Icons.call),
                    ),
                    const SizedBox(height: 8),
                    const Text('接听', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallControls(BuildContext context, CallActive state) {
    final isVideoCall = state.call.callType == CallType.video;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 48,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // 静音按钮
          _buildControlButton(
            icon: state.isMuted ? Icons.mic_off : Icons.mic,
            label: state.isMuted ? '取消静音' : '静音',
            isActive: state.isMuted,
            onPressed: () {
              context.read<CallBloc>().add(ToggleMuteEvent(!state.isMuted));
            },
          ),

          // 视频按钮（仅视频通话）
          if (isVideoCall)
            _buildControlButton(
              icon: state.isVideoOn ? Icons.videocam : Icons.videocam_off,
              label: state.isVideoOn ? '关闭视频' : '开启视频',
              isActive: !state.isVideoOn,
              onPressed: () {
                context.read<CallBloc>().add(ToggleVideoEvent(!state.isVideoOn));
              },
            ),

          // 扬声器按钮
          _buildControlButton(
            icon: state.isSpeakerOn ? Icons.volume_up : Icons.volume_off,
            label: state.isSpeakerOn ? '扬声器' : '听筒',
            isActive: !state.isSpeakerOn,
            onPressed: () {
              context.read<CallBloc>().add(ToggleSpeakerEvent(!state.isSpeakerOn));
            },
          ),

          // 翻转摄像头（仅视频通话）
          if (isVideoCall)
            _buildControlButton(
              icon: Icons.flip_camera_ios,
              label: '翻转',
              onPressed: () {
                context.read<CallBloc>().add(const SwitchCameraEvent());
              },
            ),

          // 挂断按钮
          _buildControlButton(
            icon: Icons.call_end,
            label: '挂断',
            backgroundColor: Colors.red,
            onPressed: () {
              context.read<CallBloc>().add(const EndCallEvent());
            },
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    bool isActive = false,
    Color? backgroundColor,
    required VoidCallback onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor:
              backgroundColor ?? (isActive ? Colors.white : Colors.grey[800]),
          child: IconButton(
            icon: Icon(
              icon,
              color: isActive ? Colors.black : Colors.white,
            ),
            onPressed: onPressed,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.5),
      child: const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }

  Widget _buildCallInfo(BuildContext context, CallState state) {
    return Positioned(
      left: 16,
      top: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _getCallStatusText(state),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
          if (state is CallActive)
            Text(
              '${state.connectedParticipants.length} 名参与者',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }
}

/// 来电通知组件
class IncomingCallOverlay extends StatelessWidget {
  final CallInfo call;
  final String callerName;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const IncomingCallOverlay({
    super.key,
    required this.call,
    required this.callerName,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.9),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircleAvatar(
                radius: 60,
                child: Icon(Icons.person, size: 60),
              ),
              const SizedBox(height: 24),
              Text(
                callerName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                call.callType == CallType.video ? '视频来电' : '语音来电',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 64),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 拒绝按钮
                  Column(
                    children: [
                      FloatingActionButton(
                        heroTag: 'reject_overlay',
                        onPressed: onReject,
                        backgroundColor: Colors.red,
                        child: const Icon(Icons.call_end, size: 32),
                      ),
                      const SizedBox(height: 8),
                      const Text('拒绝', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                  const SizedBox(width: 80),
                  // 接听按钮
                  Column(
                    children: [
                      FloatingActionButton(
                        heroTag: 'accept_overlay',
                        onPressed: onAccept,
                        backgroundColor: Colors.green,
                        child: Icon(
                          call.callType == CallType.video
                              ? Icons.videocam
                              : Icons.call,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text('接听', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
