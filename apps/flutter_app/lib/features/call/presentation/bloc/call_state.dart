import 'package:equatable/equatable.dart';
import '../../../../core/services/webrtc_service.dart';

/// 通话状态基类
abstract class CallState extends Equatable {
  const CallState();

  @override
  List<Object?> get props => [];
}

/// 初始状态
class CallInitial extends CallState {
  const CallInitial();
}

/// 加载中状态
class CallLoading extends CallState {
  const CallLoading();
}

/// 来电状态
class CallIncoming extends CallState {
  final CallInfo call;
  final String callerName;

  const CallIncoming({
    required this.call,
    required this.callerName,
  });

  @override
  List<Object?> get props => [call, callerName];
}

/// 通话进行中状态
class CallActive extends CallState {
  final CallInfo call;
  final bool isMuted;
  final bool isVideoOn;
  final bool isSpeakerOn;
  final Set<String> connectedParticipants;

  const CallActive({
    required this.call,
    this.isMuted = false,
    this.isVideoOn = true,
    this.isSpeakerOn = false,
    this.connectedParticipants = const {},
  });

  CallActive copyWith({
    CallInfo? call,
    bool? isMuted,
    bool? isVideoOn,
    bool? isSpeakerOn,
    Set<String>? connectedParticipants,
  }) {
    return CallActive(
      call: call ?? this.call,
      isMuted: isMuted ?? this.isMuted,
      isVideoOn: isVideoOn ?? this.isVideoOn,
      isSpeakerOn: isSpeakerOn ?? this.isSpeakerOn,
      connectedParticipants: connectedParticipants ?? this.connectedParticipants,
    );
  }

  @override
  List<Object?> get props => [
        call,
        isMuted,
        isVideoOn,
        isSpeakerOn,
        connectedParticipants,
      ];
}

/// 通话结束状态
class CallEnded extends CallState {
  final String? reason;
  final int? durationSeconds;

  const CallEnded({
    this.reason,
    this.durationSeconds,
  });

  @override
  List<Object?> get props => [reason, durationSeconds];
}

/// 错误状态
class CallError extends CallState {
  final String message;
  final CallInfo? call;

  const CallError({
    required this.message,
    this.call,
  });

  @override
  List<Object?> get props => [message, call];
}
