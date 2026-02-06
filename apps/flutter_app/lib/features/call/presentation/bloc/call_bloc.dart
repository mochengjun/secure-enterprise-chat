import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/services/webrtc_service.dart';
import '../../services/audio_session_manager.dart';
import 'call_event.dart';
import 'call_state.dart';

/// 通话BLoC
/// 统一管理通话状态和业务逻辑
class CallBloc extends Bloc<CallEvent, CallState> {
  final WebRTCService _webrtcService;
  final AudioSessionManager _audioSessionManager;

  StreamSubscription? _callStateSubscription;
  StreamSubscription? _remoteStreamSubscription;

  CallBloc({
    required WebRTCService webrtcService,
    required AudioSessionManager audioSessionManager,
  })  : _webrtcService = webrtcService,
        _audioSessionManager = audioSessionManager,
        super(const CallInitial()) {
    // 注册事件处理器
    on<InitiateCallEvent>(_onInitiateCall);
    on<IncomingCallEvent>(_onIncomingCall);
    on<AcceptCallEvent>(_onAcceptCall);
    on<RejectCallEvent>(_onRejectCall);
    on<EndCallEvent>(_onEndCall);
    on<ToggleMuteEvent>(_onToggleMute);
    on<ToggleVideoEvent>(_onToggleVideo);
    on<ToggleSpeakerEvent>(_onToggleSpeaker);
    on<SwitchCameraEvent>(_onSwitchCamera);
    on<CallStateChangedEvent>(_onCallStateChanged);
    on<RemoteStreamUpdatedEvent>(_onRemoteStreamUpdated);
    on<ParticipantLeftEvent>(_onParticipantLeft);

    // 设置WebRTC回调
    _setupWebRTCCallbacks();
  }

  void _setupWebRTCCallbacks() {
    // 监听通话状态变化
    _webrtcService.onCallStateChanged = (call) {
      add(CallStateChangedEvent(call));
    };

    // 监听来电
    _webrtcService.onIncomingCall = (call) {
      add(IncomingCallEvent(call));
    };

    // 监听远程流
    _webrtcService.onRemoteStream = (userId, stream) {
      add(RemoteStreamUpdatedEvent(userId));
    };

    // 监听参与者离开
    _webrtcService.onParticipantLeft = (userId) {
      add(ParticipantLeftEvent(userId));
    };

    // 监听音频中断
    _audioSessionManager.onAudioInterrupted = (interrupted) {
      if (interrupted && state is CallActive) {
        // 被中断时自动静音
        add(const ToggleMuteEvent(true));
      }
    };
  }

  /// 发起通话
  Future<void> _onInitiateCall(
    InitiateCallEvent event,
    Emitter<CallState> emit,
  ) async {
    emit(const CallLoading());

    try {
      // 激活音频会话
      await _audioSessionManager.activate();

      // 发起通话
      final call = await _webrtcService.initiateCall(
        event.targetUserIds,
        event.callType,
        roomId: event.roomId,
      );

      if (call != null) {
        emit(CallActive(
          call: call,
          isVideoOn: event.callType == CallType.video,
          isSpeakerOn: event.callType == CallType.video, // 视频通话默认使用扬声器
        ));

        // 视频通话默认开启扬声器
        if (event.callType == CallType.video) {
          await _audioSessionManager.toggleSpeaker(true);
        }
      } else {
        await _audioSessionManager.deactivate();
        emit(const CallError(message: '发起通话失败'));
      }
    } catch (e) {
      await _audioSessionManager.deactivate();
      emit(CallError(message: '发起通话失败: ${e.toString()}'));
    }
  }

  /// 处理来电
  void _onIncomingCall(
    IncomingCallEvent event,
    Emitter<CallState> emit,
  ) {
    // 获取来电者名称
    final callerName = event.call.participants
            .firstWhere(
              (p) => p.oderId == event.call.initiatorId,
              orElse: () => CallParticipant(
                id: 0,
                callId: '',
                oderId: event.call.initiatorId,
                status: ParticipantStatus.connected,
                isMuted: false,
                isVideoOn: true,
              ),
            )
            .oderId;

    emit(CallIncoming(
      call: event.call,
      callerName: callerName,
    ));
  }

  /// 接受通话
  Future<void> _onAcceptCall(
    AcceptCallEvent event,
    Emitter<CallState> emit,
  ) async {
    final currentState = state;
    if (currentState is! CallIncoming) return;

    emit(const CallLoading());

    try {
      // 激活音频会话
      await _audioSessionManager.activate();

      // 接受通话
      await _webrtcService.acceptCall(event.callId);

      emit(CallActive(
        call: currentState.call,
        isVideoOn: currentState.call.callType == CallType.video,
        isSpeakerOn: currentState.call.callType == CallType.video,
      ));

      // 视频通话默认开启扬声器
      if (currentState.call.callType == CallType.video) {
        await _audioSessionManager.toggleSpeaker(true);
      }
    } catch (e) {
      await _audioSessionManager.deactivate();
      emit(CallError(message: '接听失败: ${e.toString()}'));
    }
  }

  /// 拒绝通话
  Future<void> _onRejectCall(
    RejectCallEvent event,
    Emitter<CallState> emit,
  ) async {
    try {
      await _webrtcService.rejectCall(event.callId);
      emit(const CallEnded(reason: 'rejected'));
    } catch (e) {
      emit(CallError(message: '拒绝失败: ${e.toString()}'));
    }
  }

  /// 结束通话
  Future<void> _onEndCall(
    EndCallEvent event,
    Emitter<CallState> emit,
  ) async {
    final currentState = state;
    int? duration;

    if (currentState is CallActive) {
      // 计算通话时长
      if (currentState.call.startedAt != null) {
        duration = DateTime.now()
            .difference(currentState.call.startedAt!)
            .inSeconds;
      }
    }

    try {
      await _webrtcService.endCall(reason: event.reason);
      await _audioSessionManager.deactivate();

      emit(CallEnded(
        reason: event.reason ?? 'ended',
        durationSeconds: duration,
      ));
    } catch (e) {
      await _audioSessionManager.deactivate();
      emit(CallEnded(
        reason: 'error',
        durationSeconds: duration,
      ));
    }
  }

  /// 切换静音
  Future<void> _onToggleMute(
    ToggleMuteEvent event,
    Emitter<CallState> emit,
  ) async {
    final currentState = state;
    if (currentState is! CallActive) return;

    try {
      await _webrtcService.toggleMute(event.muted);
      emit(currentState.copyWith(isMuted: event.muted));
    } catch (e) {
      emit(CallError(
        message: '切换静音失败: ${e.toString()}',
        call: currentState.call,
      ));
    }
  }

  /// 切换视频
  Future<void> _onToggleVideo(
    ToggleVideoEvent event,
    Emitter<CallState> emit,
  ) async {
    final currentState = state;
    if (currentState is! CallActive) return;

    try {
      await _webrtcService.toggleVideo(event.videoOn);
      emit(currentState.copyWith(isVideoOn: event.videoOn));
    } catch (e) {
      emit(CallError(
        message: '切换视频失败: ${e.toString()}',
        call: currentState.call,
      ));
    }
  }

  /// 切换扬声器
  Future<void> _onToggleSpeaker(
    ToggleSpeakerEvent event,
    Emitter<CallState> emit,
  ) async {
    final currentState = state;
    if (currentState is! CallActive) return;

    try {
      final success = await _audioSessionManager.toggleSpeaker(event.useSpeaker);
      if (success) {
        emit(currentState.copyWith(isSpeakerOn: event.useSpeaker));
      } else {
        emit(CallError(
          message: '切换扬声器失败',
          call: currentState.call,
        ));
      }
    } catch (e) {
      emit(CallError(
        message: '切换扬声器失败: ${e.toString()}',
        call: currentState.call,
      ));
    }
  }

  /// 切换摄像头
  Future<void> _onSwitchCamera(
    SwitchCameraEvent event,
    Emitter<CallState> emit,
  ) async {
    try {
      await _webrtcService.switchCamera();
    } catch (e) {
      final currentState = state;
      if (currentState is CallActive) {
        emit(CallError(
          message: '切换摄像头失败: ${e.toString()}',
          call: currentState.call,
        ));
      }
    }
  }

  /// 处理通话状态变更
  void _onCallStateChanged(
    CallStateChangedEvent event,
    Emitter<CallState> emit,
  ) {
    final currentState = state;

    if (event.call == null) {
      // 通话结束
      _audioSessionManager.deactivate();
      emit(const CallEnded());
    } else if (currentState is CallActive) {
      // 更新通话信息
      emit(currentState.copyWith(call: event.call));
    } else if (currentState is CallIncoming) {
      // 来电状态更新
      emit(CallIncoming(
        call: event.call!,
        callerName: currentState.callerName,
      ));
    }
  }

  /// 处理远程流更新
  void _onRemoteStreamUpdated(
    RemoteStreamUpdatedEvent event,
    Emitter<CallState> emit,
  ) {
    final currentState = state;
    if (currentState is CallActive) {
      final participants = Set<String>.from(currentState.connectedParticipants)
        ..add(event.userId);
      emit(currentState.copyWith(connectedParticipants: participants));
    }
  }

  /// 处理参与者离开
  void _onParticipantLeft(
    ParticipantLeftEvent event,
    Emitter<CallState> emit,
  ) {
    final currentState = state;
    if (currentState is CallActive) {
      final participants = Set<String>.from(currentState.connectedParticipants)
        ..remove(event.userId);

      // 如果所有参与者都离开了,结束通话
      if (participants.isEmpty) {
        add(const EndCallEvent(reason: 'all_participants_left'));
      } else {
        emit(currentState.copyWith(connectedParticipants: participants));
      }
    }
  }

  /// 获取WebRTC服务(用于UI层访问渲染器)
  WebRTCService get webrtcService => _webrtcService;

  @override
  Future<void> close() {
    _webrtcService.onCallStateChanged = null;
    _webrtcService.onIncomingCall = null;
    _webrtcService.onRemoteStream = null;
    _webrtcService.onParticipantLeft = null;
    _audioSessionManager.onAudioInterrupted = null;
    _callStateSubscription?.cancel();
    _remoteStreamSubscription?.cancel();
    return super.close();
  }
}
