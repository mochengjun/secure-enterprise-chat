import 'package:equatable/equatable.dart';
import '../../../../core/services/webrtc_service.dart';

/// 通话事件基类
abstract class CallEvent extends Equatable {
  const CallEvent();

  @override
  List<Object?> get props => [];
}

/// 发起通话事件
class InitiateCallEvent extends CallEvent {
  final List<String> targetUserIds;
  final CallType callType;
  final String? roomId;

  const InitiateCallEvent({
    required this.targetUserIds,
    required this.callType,
    this.roomId,
  });

  @override
  List<Object?> get props => [targetUserIds, callType, roomId];
}

/// 接收来电事件
class IncomingCallEvent extends CallEvent {
  final CallInfo call;

  const IncomingCallEvent(this.call);

  @override
  List<Object?> get props => [call];
}

/// 接受通话事件
class AcceptCallEvent extends CallEvent {
  final String callId;

  const AcceptCallEvent(this.callId);

  @override
  List<Object?> get props => [callId];
}

/// 拒绝通话事件
class RejectCallEvent extends CallEvent {
  final String callId;

  const RejectCallEvent(this.callId);

  @override
  List<Object?> get props => [callId];
}

/// 结束通话事件
class EndCallEvent extends CallEvent {
  final String? reason;

  const EndCallEvent({this.reason});

  @override
  List<Object?> get props => [reason];
}

/// 切换静音事件
class ToggleMuteEvent extends CallEvent {
  final bool muted;

  const ToggleMuteEvent(this.muted);

  @override
  List<Object?> get props => [muted];
}

/// 切换视频事件
class ToggleVideoEvent extends CallEvent {
  final bool videoOn;

  const ToggleVideoEvent(this.videoOn);

  @override
  List<Object?> get props => [videoOn];
}

/// 切换扬声器事件
class ToggleSpeakerEvent extends CallEvent {
  final bool useSpeaker;

  const ToggleSpeakerEvent(this.useSpeaker);

  @override
  List<Object?> get props => [useSpeaker];
}

/// 切换摄像头事件
class SwitchCameraEvent extends CallEvent {
  const SwitchCameraEvent();
}

/// 通话状态变更事件(内部使用)
class CallStateChangedEvent extends CallEvent {
  final CallInfo? call;

  const CallStateChangedEvent(this.call);

  @override
  List<Object?> get props => [call];
}

/// 远程流更新事件
class RemoteStreamUpdatedEvent extends CallEvent {
  final String userId;

  const RemoteStreamUpdatedEvent(this.userId);

  @override
  List<Object?> get props => [userId];
}

/// 参与者离开事件
class ParticipantLeftEvent extends CallEvent {
  final String userId;

  const ParticipantLeftEvent(this.userId);

  @override
  List<Object?> get props => [userId];
}
