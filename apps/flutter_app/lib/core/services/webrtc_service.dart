import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// 通话类型
enum CallType { voice, video }

/// 通话状态
enum CallStatus {
  initiated,
  ringing,
  connecting,
  connected,
  ended,
  missed,
  rejected,
  failed,
}

/// 参与者状态
enum ParticipantStatus {
  invited,
  ringing,
  connected,
  left,
  rejected,
}

/// 通话信息
class CallInfo {
  final String id;
  final String? roomId;
  final String initiatorId;
  final CallType callType;
  final CallStatus status;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int? duration;
  final String? endReason;
  final List<CallParticipant> participants;
  final DateTime createdAt;

  CallInfo({
    required this.id,
    this.roomId,
    required this.initiatorId,
    required this.callType,
    required this.status,
    this.startedAt,
    this.endedAt,
    this.duration,
    this.endReason,
    required this.participants,
    required this.createdAt,
  });

  factory CallInfo.fromJson(Map<String, dynamic> json) {
    return CallInfo(
      id: json['id'] ?? '',
      roomId: json['room_id'],
      initiatorId: json['initiator_id'] ?? '',
      callType: json['call_type'] == 'video' ? CallType.video : CallType.voice,
      status: _parseStatus(json['status']),
      startedAt: json['started_at'] != null
          ? DateTime.tryParse(json['started_at'])
          : null,
      endedAt: json['ended_at'] != null
          ? DateTime.tryParse(json['ended_at'])
          : null,
      duration: json['duration'],
      endReason: json['end_reason'],
      participants: (json['participants'] as List<dynamic>?)
              ?.map((p) => CallParticipant.fromJson(p))
              .toList() ??
          [],
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  static CallStatus _parseStatus(String? status) {
    switch (status) {
      case 'initiated':
        return CallStatus.initiated;
      case 'ringing':
        return CallStatus.ringing;
      case 'connecting':
        return CallStatus.connecting;
      case 'connected':
        return CallStatus.connected;
      case 'ended':
        return CallStatus.ended;
      case 'missed':
        return CallStatus.missed;
      case 'rejected':
        return CallStatus.rejected;
      case 'failed':
        return CallStatus.failed;
      default:
        return CallStatus.initiated;
    }
  }

  bool get isActive =>
      status == CallStatus.initiated ||
      status == CallStatus.ringing ||
      status == CallStatus.connecting ||
      status == CallStatus.connected;
}

/// 通话参与者
class CallParticipant {
  final int id;
  final String callId;
  final String oderId;
  final ParticipantStatus status;
  final DateTime? joinedAt;
  final DateTime? leftAt;
  final bool isMuted;
  final bool isVideoOn;

  CallParticipant({
    required this.id,
    required this.callId,
    required this.oderId,
    required this.status,
    this.joinedAt,
    this.leftAt,
    required this.isMuted,
    required this.isVideoOn,
  });

  factory CallParticipant.fromJson(Map<String, dynamic> json) {
    return CallParticipant(
      id: json['id'] ?? 0,
      callId: json['call_id'] ?? '',
      oderId: json['user_id'] ?? '',
      status: _parseStatus(json['status']),
      joinedAt: json['joined_at'] != null
          ? DateTime.tryParse(json['joined_at'])
          : null,
      leftAt:
          json['left_at'] != null ? DateTime.tryParse(json['left_at']) : null,
      isMuted: json['is_muted'] ?? false,
      isVideoOn: json['is_video_on'] ?? true,
    );
  }

  static ParticipantStatus _parseStatus(String? status) {
    switch (status) {
      case 'invited':
        return ParticipantStatus.invited;
      case 'ringing':
        return ParticipantStatus.ringing;
      case 'connected':
        return ParticipantStatus.connected;
      case 'left':
        return ParticipantStatus.left;
      case 'rejected':
        return ParticipantStatus.rejected;
      default:
        return ParticipantStatus.invited;
    }
  }
}

/// ICE服务器配置
class IceServer {
  final List<String> urls;
  final String? username;
  final String? credential;

  IceServer({
    required this.urls,
    this.username,
    this.credential,
  });

  factory IceServer.fromJson(Map<String, dynamic> json) {
    return IceServer(
      urls: (json['urls'] as List<dynamic>?)?.cast<String>() ?? [],
      username: json['username'],
      credential: json['credential'],
    );
  }

  Map<String, dynamic> toWebRTCConfig() {
    return {
      'urls': urls,
      if (username != null) 'username': username,
      if (credential != null) 'credential': credential,
    };
  }
}

/// 信令消息
class SignalingMessage {
  final String type;
  final String callId;
  final String fromUser;
  final String? toUser;
  final dynamic payload;
  final DateTime timestamp;

  SignalingMessage({
    required this.type,
    required this.callId,
    required this.fromUser,
    this.toUser,
    this.payload,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory SignalingMessage.fromJson(Map<String, dynamic> json) {
    return SignalingMessage(
      type: json['type'] ?? '',
      callId: json['call_id'] ?? '',
      fromUser: json['from_user'] ?? '',
      toUser: json['to_user'],
      payload: json['payload'],
      timestamp:
          DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'call_id': callId,
      'from_user': fromUser,
      if (toUser != null) 'to_user': toUser,
      if (payload != null) 'payload': payload,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

/// 通话事件回调
typedef OnCallStateChanged = void Function(CallInfo call);
typedef OnRemoteStream = void Function(String oderId, MediaStream stream);
typedef OnParticipantChanged = void Function(CallParticipant participant);

/// WebRTC通话服务
class WebRTCService {
  final Dio _dio;
  final String _baseUrl;
  final String Function() _tokenProvider;

  // WebSocket信令连接
  WebSocketChannel? _signalingChannel;
  bool _isConnected = false;

  // WebRTC相关
  final Map<String, RTCPeerConnection> _peerConnections = {};
  MediaStream? _localStream;
  final Map<String, MediaStream> _remoteStreams = {};

  // ICE服务器配置
  List<IceServer> _iceServers = [];

  // 当前通话
  CallInfo? _currentCall;

  // 回调
  OnCallStateChanged? onCallStateChanged;
  OnRemoteStream? onRemoteStream;
  OnParticipantChanged? onParticipantChanged;
  void Function(String oderId)? onParticipantLeft;
  void Function(CallInfo call)? onIncomingCall;

  // 流控制器
  final _callStateController = StreamController<CallInfo?>.broadcast();
  Stream<CallInfo?> get callStateStream => _callStateController.stream;

  WebRTCService({
    required Dio dio,
    required String baseUrl,
    required String Function() tokenProvider,
  })  : _dio = dio,
        _baseUrl = baseUrl,
        _tokenProvider = tokenProvider;

  /// 初始化服务
  Future<void> initialize() async {
    await _fetchIceServers();
  }

  /// 获取ICE服务器配置
  Future<void> _fetchIceServers() async {
    try {
      final response = await _dio.get('$_baseUrl/calls/ice-servers');
      final servers = (response.data['ice_servers'] as List<dynamic>?)
              ?.map((s) => IceServer.fromJson(s))
              .toList() ??
          [];
      _iceServers = servers;
    } catch (e) {
      // 使用默认STUN服务器
      _iceServers = [
        IceServer(urls: [
          'stun:stun.l.google.com:19302',
          'stun:stun1.l.google.com:19302',
        ]),
      ];
    }
  }

  /// 连接信令服务器
  Future<void> connectSignaling() async {
    if (_isConnected) return;

    final token = _tokenProvider();
    final wsUrl = _baseUrl
        .replaceFirst('http://', 'ws://')
        .replaceFirst('https://', 'wss://');

    _signalingChannel = WebSocketChannel.connect(
      Uri.parse('$wsUrl/signaling?token=$token'),
    );

    _signalingChannel!.stream.listen(
      _handleSignalingMessage,
      onError: (error) {
        print('Signaling error: $error');
        _isConnected = false;
        _reconnectSignaling();
      },
      onDone: () {
        _isConnected = false;
        _reconnectSignaling();
      },
    );

    _isConnected = true;
  }

  /// 重连信令服务器
  void _reconnectSignaling() {
    Future.delayed(const Duration(seconds: 3), () {
      if (!_isConnected) {
        connectSignaling();
      }
    });
  }

  /// 处理信令消息
  void _handleSignalingMessage(dynamic data) {
    try {
      final message = SignalingMessage.fromJson(
        jsonDecode(data as String),
      );

      switch (message.type) {
        case 'call-invite':
          _handleCallInvite(message);
          break;
        case 'call-accept':
          _handleCallAccept(message);
          break;
        case 'call-reject':
          _handleCallReject(message);
          break;
        case 'call-end':
          _handleCallEnd(message);
          break;
        case 'offer':
          _handleOffer(message);
          break;
        case 'answer':
          _handleAnswer(message);
          break;
        case 'ice-candidate':
          _handleIceCandidate(message);
          break;
        case 'participant-joined':
          _handleParticipantJoined(message);
          break;
        case 'participant-left':
          _handleParticipantLeft(message);
          break;
        case 'mute-toggle':
        case 'video-toggle':
          _handleMediaToggle(message);
          break;
      }
    } catch (e) {
      print('Error handling signaling message: $e');
    }
  }

  /// 发送信令消息
  void _sendSignaling(SignalingMessage message) {
    if (_signalingChannel != null && _isConnected) {
      _signalingChannel!.sink.add(jsonEncode(message.toJson()));
    }
  }

  /// 发起通话
  Future<CallInfo?> initiateCall(
    List<String> targetUserIds,
    CallType callType, {
    String? roomId,
  }) async {
    try {
      // 检查是否已有通话
      if (_currentCall != null && _currentCall!.isActive) {
        throw Exception('Already in a call');
      }

      // 获取本地媒体流
      await _getUserMedia(callType == CallType.video);

      // 通过API发起通话
      final response = await _dio.post('$_baseUrl/calls', data: {
        'target_user_ids': targetUserIds,
        'call_type': callType == CallType.video ? 'video' : 'voice',
        if (roomId != null) 'room_id': roomId,
      });

      final call = CallInfo.fromJson(response.data);
      _currentCall = call;
      _callStateController.add(call);
      onCallStateChanged?.call(call);

      // 为每个目标用户创建PeerConnection并发送offer
      for (final targetId in targetUserIds) {
        await _createPeerConnectionAndOffer(call.id, targetId);
      }

      return call;
    } catch (e) {
      print('Error initiating call: $e');
      await _cleanupCall();
      rethrow;
    }
  }

  /// 接受通话
  Future<void> acceptCall(String callId) async {
    try {
      // 获取本地媒体流
      final call = _currentCall;
      if (call == null) return;

      await _getUserMedia(call.callType == CallType.video);

      // 通过API接受通话
      await _dio.post('$_baseUrl/calls/$callId/accept');

      // 发送信令
      _sendSignaling(SignalingMessage(
        type: 'call-accept',
        callId: callId,
        fromUser: '',
      ));
    } catch (e) {
      print('Error accepting call: $e');
      rethrow;
    }
  }

  /// 拒绝通话
  Future<void> rejectCall(String callId) async {
    try {
      await _dio.post('$_baseUrl/calls/$callId/reject');

      _sendSignaling(SignalingMessage(
        type: 'call-reject',
        callId: callId,
        fromUser: '',
      ));

      await _cleanupCall();
    } catch (e) {
      print('Error rejecting call: $e');
      rethrow;
    }
  }

  /// 结束通话
  Future<void> endCall({String? reason}) async {
    if (_currentCall == null) return;

    try {
      await _dio.post('$_baseUrl/calls/${_currentCall!.id}/end', data: {
        if (reason != null) 'reason': reason,
      });

      _sendSignaling(SignalingMessage(
        type: 'call-end',
        callId: _currentCall!.id,
        fromUser: '',
      ));
    } catch (e) {
      print('Error ending call: $e');
    } finally {
      await _cleanupCall();
    }
  }

  /// 切换静音
  Future<void> toggleMute(bool muted) async {
    if (_localStream == null || _currentCall == null) return;

    for (final track in _localStream!.getAudioTracks()) {
      track.enabled = !muted;
    }

    await _dio.post('$_baseUrl/calls/${_currentCall!.id}/mute', data: {
      'muted': muted,
    });
  }

  /// 切换视频
  Future<void> toggleVideo(bool videoOn) async {
    if (_localStream == null || _currentCall == null) return;

    for (final track in _localStream!.getVideoTracks()) {
      track.enabled = videoOn;
    }

    await _dio.post('$_baseUrl/calls/${_currentCall!.id}/video', data: {
      'video_on': videoOn,
    });
  }

  /// 切换摄像头
  Future<void> switchCamera() async {
    if (_localStream == null) return;

    final videoTrack = _localStream!.getVideoTracks().firstOrNull;
    if (videoTrack != null) {
      await Helper.switchCamera(videoTrack);
    }
  }

  /// 获取本地媒体流
  Future<void> _getUserMedia(bool video) async {
    final constraints = {
      'audio': true,
      'video': video
          ? {
              'facingMode': 'user',
              'width': {'ideal': 1280},
              'height': {'ideal': 720},
            }
          : false,
    };

    _localStream = await navigator.mediaDevices.getUserMedia(constraints);
  }

  /// 创建PeerConnection并发送offer
  Future<void> _createPeerConnectionAndOffer(
      String callId, String targetUserId) async {
    final pc = await _createPeerConnection(targetUserId);

    // 添加本地流
    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        await pc.addTrack(track, _localStream!);
      }
    }

    // 创建offer
    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);

    // 发送offer
    _sendSignaling(SignalingMessage(
      type: 'offer',
      callId: callId,
      fromUser: '',
      toUser: targetUserId,
      payload: {
        'type': 'offer',
        'sdp': offer.sdp,
      },
    ));
  }

  /// 创建PeerConnection
  Future<RTCPeerConnection> _createPeerConnection(String oderId) async {
    final config = {
      'iceServers': _iceServers.map((s) => s.toWebRTCConfig()).toList(),
      'sdpSemantics': 'unified-plan',
    };

    final pc = await createPeerConnection(config);
    _peerConnections[oderId] = pc;

    // ICE候选回调
    pc.onIceCandidate = (candidate) {
      if (_currentCall != null) {
        _sendSignaling(SignalingMessage(
          type: 'ice-candidate',
          callId: _currentCall!.id,
          fromUser: '',
          toUser: oderId,
          payload: {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          },
        ));
      }
    };

    // 远程流回调
    pc.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteStreams[oderId] = event.streams[0];
        onRemoteStream?.call(oderId, event.streams[0]);
      }
    };

    // 连接状态回调
    pc.onConnectionState = (state) {
      print('Connection state for $oderId: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        // 处理连接失败
      }
    };

    return pc;
  }

  /// 处理来电邀请
  void _handleCallInvite(SignalingMessage message) async {
    try {
      // 获取通话详情
      final response = await _dio.get('$_baseUrl/calls/${message.callId}');
      final call = CallInfo.fromJson(response.data);

      _currentCall = call;
      _callStateController.add(call);
      onIncomingCall?.call(call);
    } catch (e) {
      print('Error handling call invite: $e');
    }
  }

  /// 处理通话接受
  void _handleCallAccept(SignalingMessage message) async {
    // 对方已接受，可以开始建立连接
    if (_currentCall != null) {
      _currentCall = _currentCall!;
      _callStateController.add(_currentCall);
      onCallStateChanged?.call(_currentCall!);
    }
  }

  /// 处理通话拒绝
  void _handleCallReject(SignalingMessage message) async {
    if (_currentCall?.id == message.callId) {
      await _cleanupCall();
    }
  }

  /// 处理通话结束
  void _handleCallEnd(SignalingMessage message) async {
    if (_currentCall?.id == message.callId) {
      await _cleanupCall();
    }
  }

  /// 处理SDP offer
  void _handleOffer(SignalingMessage message) async {
    try {
      final pc = await _createPeerConnection(message.fromUser);

      // 添加本地流
      if (_localStream != null) {
        for (final track in _localStream!.getTracks()) {
          await pc.addTrack(track, _localStream!);
        }
      }

      // 设置远程描述
      final payload = message.payload as Map<String, dynamic>;
      await pc.setRemoteDescription(RTCSessionDescription(
        payload['sdp'],
        payload['type'],
      ));

      // 创建answer
      final answer = await pc.createAnswer();
      await pc.setLocalDescription(answer);

      // 发送answer
      _sendSignaling(SignalingMessage(
        type: 'answer',
        callId: message.callId,
        fromUser: '',
        toUser: message.fromUser,
        payload: {
          'type': 'answer',
          'sdp': answer.sdp,
        },
      ));
    } catch (e) {
      print('Error handling offer: $e');
    }
  }

  /// 处理SDP answer
  void _handleAnswer(SignalingMessage message) async {
    try {
      final pc = _peerConnections[message.fromUser];
      if (pc != null) {
        final payload = message.payload as Map<String, dynamic>;
        await pc.setRemoteDescription(RTCSessionDescription(
          payload['sdp'],
          payload['type'],
        ));
      }
    } catch (e) {
      print('Error handling answer: $e');
    }
  }

  /// 处理ICE候选
  void _handleIceCandidate(SignalingMessage message) async {
    try {
      final pc = _peerConnections[message.fromUser];
      if (pc != null) {
        final payload = message.payload as Map<String, dynamic>;
        await pc.addCandidate(RTCIceCandidate(
          payload['candidate'],
          payload['sdpMid'],
          payload['sdpMLineIndex'],
        ));
      }
    } catch (e) {
      print('Error handling ICE candidate: $e');
    }
  }

  /// 处理参与者加入
  void _handleParticipantJoined(SignalingMessage message) {
    // 刷新通话信息
    _refreshCallInfo();
  }

  /// 处理参与者离开
  void _handleParticipantLeft(SignalingMessage message) {
    final oderId = message.fromUser;

    // 关闭对应的PeerConnection
    _peerConnections[oderId]?.close();
    _peerConnections.remove(oderId);

    // 移除远程流
    _remoteStreams.remove(oderId);

    onParticipantLeft?.call(oderId);

    // 刷新通话信息
    _refreshCallInfo();
  }

  /// 处理媒体状态切换
  void _handleMediaToggle(SignalingMessage message) {
    // 更新参与者状态
    _refreshCallInfo();
  }

  /// 刷新通话信息
  Future<void> _refreshCallInfo() async {
    if (_currentCall == null) return;

    try {
      final response = await _dio.get('$_baseUrl/calls/${_currentCall!.id}');
      final call = CallInfo.fromJson(response.data);
      _currentCall = call;
      _callStateController.add(call);
      onCallStateChanged?.call(call);
    } catch (e) {
      print('Error refreshing call info: $e');
    }
  }

  /// 清理通话资源
  Future<void> _cleanupCall() async {
    // 关闭所有PeerConnection
    for (final pc in _peerConnections.values) {
      await pc.close();
    }
    _peerConnections.clear();

    // 停止本地流
    _localStream?.getTracks().forEach((track) => track.stop());
    _localStream?.dispose();
    _localStream = null;

    // 清理远程流
    _remoteStreams.clear();

    // 清理通话状态
    _currentCall = null;
    _callStateController.add(null);
  }

  /// 获取本地视频流
  MediaStream? get localStream => _localStream;

  /// 获取远程视频流
  Map<String, MediaStream> get remoteStreams => Map.unmodifiable(_remoteStreams);

  /// 获取当前通话
  CallInfo? get currentCall => _currentCall;

  /// 获取通话历史
  Future<List<CallInfo>> getCallHistory({int offset = 0, int limit = 20}) async {
    final response = await _dio.get('$_baseUrl/calls/history', queryParameters: {
      'offset': offset,
      'limit': limit,
    });

    final calls = (response.data['calls'] as List<dynamic>?)
            ?.map((c) => CallInfo.fromJson(c))
            .toList() ??
        [];
    return calls;
  }

  /// 释放资源
  Future<void> dispose() async {
    await _cleanupCall();
    _signalingChannel?.sink.close();
    _callStateController.close();
  }
}
