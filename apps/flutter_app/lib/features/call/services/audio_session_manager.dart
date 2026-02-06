import 'dart:io';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// 音频路由类型
enum AudioRoute {
  earpiece, // 听筒
  speaker, // 扬声器
  bluetooth, // 蓝牙
  wired, // 有线耳机
}

/// 音频设备信息
class AudioDeviceInfo {
  final String id;
  final String name;
  final AudioRoute route;
  final bool isDefault;

  AudioDeviceInfo({
    required this.id,
    required this.name,
    required this.route,
    this.isDefault = false,
  });
}

/// 音频会话管理器
/// 统一管理iOS/Android音频会话,处理音频焦点和路由
class AudioSessionManager {
  AudioSession? _audioSession;
  AudioRoute _currentRoute = AudioRoute.earpiece;
  List<AudioDeviceInfo> _availableDevices = [];
  bool _isActive = false;

  // 回调
  void Function(AudioRoute route)? onAudioRouteChanged;
  void Function(List<AudioDeviceInfo> devices)? onDevicesChanged;
  void Function(bool interrupted)? onAudioInterrupted;

  /// 是否已激活
  bool get isActive => _isActive;

  /// 当前音频路由
  AudioRoute get currentRoute => _currentRoute;

  /// 可用设备列表
  List<AudioDeviceInfo> get availableDevices =>
      List.unmodifiable(_availableDevices);

  /// 初始化音频会话
  Future<void> initialize() async {
    try {
      _audioSession = await AudioSession.instance;

      // 配置音频会话
      await _audioSession!.configure(AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.allowBluetooth |
                AVAudioSessionCategoryOptions.defaultToSpeaker,
        avAudioSessionMode: AVAudioSessionMode.voiceChat,
        avAudioSessionRouteSharingPolicy:
            AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
        androidAudioAttributes: const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          flags: AndroidAudioFlags.none,
          usage: AndroidAudioUsage.voiceCommunication,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: true,
      ));

      // 监听音频中断(来电等)
      _audioSession!.interruptionEventStream.listen((event) {
        debugPrint('Audio interruption: ${event.type}');
        if (event.begin) {
          // 音频被中断(如来电)
          onAudioInterrupted?.call(true);
        } else {
          // 中断结束
          onAudioInterrupted?.call(false);
          // 尝试恢复
          if (_isActive) {
            activate();
          }
        }
      });

      // 监听音频路由变化(耳机拔出等)
      _audioSession!.becomingNoisyEventStream.listen((_) {
        debugPrint('Audio becoming noisy (headphones unplugged)');
        // 耳机拔出,切换到听筒
        _currentRoute = AudioRoute.earpiece;
        onAudioRouteChanged?.call(_currentRoute);
      });

      // 监听设备变化
      _audioSession!.devicesChangedEventStream.listen((event) {
        _updateAvailableDevices();
      });

      // 初始加载设备列表
      await _updateAvailableDevices();

      debugPrint('AudioSessionManager initialized successfully');
    } catch (e) {
      debugPrint('Error initializing audio session: $e');
    }
  }

  /// 激活音频会话(通话开始时调用)
  Future<void> activate() async {
    try {
      await _audioSession?.setActive(true);
      _isActive = true;
      debugPrint('Audio session activated');
    } catch (e) {
      debugPrint('Error activating audio session: $e');
    }
  }

  /// 停用音频会话(通话结束时调用)
  Future<void> deactivate() async {
    try {
      await _audioSession?.setActive(false);
      _isActive = false;
      _currentRoute = AudioRoute.earpiece;
      debugPrint('Audio session deactivated');
    } catch (e) {
      debugPrint('Error deactivating audio session: $e');
    }
  }

  /// 设置音频路由
  Future<bool> setAudioRoute(AudioRoute route) async {
    try {
      bool success = false;

      if (Platform.isIOS) {
        success = await _setIOSAudioRoute(route);
      } else if (Platform.isAndroid) {
        success = await _setAndroidAudioRoute(route);
      }

      if (success) {
        _currentRoute = route;
        onAudioRouteChanged?.call(route);
      }

      return success;
    } catch (e) {
      debugPrint('Error setting audio route: $e');
      return false;
    }
  }

  /// iOS音频路由设置
  Future<bool> _setIOSAudioRoute(AudioRoute route) async {
    try {
      switch (route) {
        case AudioRoute.speaker:
          await Helper.setSpeakerphoneOn(true);
          return true;

        case AudioRoute.earpiece:
          await Helper.setSpeakerphoneOn(false);
          return true;

        case AudioRoute.bluetooth:
        case AudioRoute.wired:
          // iOS会自动路由到已连接的蓝牙/有线设备
          await Helper.setSpeakerphoneOn(false);
          return true;
      }
    } catch (e) {
      debugPrint('Error setting iOS audio route: $e');
      return false;
    }
  }

  /// Android音频路由设置
  Future<bool> _setAndroidAudioRoute(AudioRoute route) async {
    try {
      switch (route) {
        case AudioRoute.speaker:
          await Helper.setSpeakerphoneOn(true);
          return true;

        case AudioRoute.earpiece:
          await Helper.setSpeakerphoneOn(false);
          return true;

        case AudioRoute.bluetooth:
        case AudioRoute.wired:
          // Android会自动路由到已连接的设备
          await Helper.setSpeakerphoneOn(false);
          return true;
      }
    } catch (e) {
      debugPrint('Error setting Android audio route: $e');
      return false;
    }
  }

  /// 切换扬声器开关
  Future<bool> toggleSpeaker(bool enable) async {
    return await setAudioRoute(
      enable ? AudioRoute.speaker : AudioRoute.earpiece,
    );
  }

  /// 检查是否使用扬声器
  bool get isSpeakerOn => _currentRoute == AudioRoute.speaker;

  /// 更新可用设备列表
  Future<void> _updateAvailableDevices() async {
    try {
      final devices = <AudioDeviceInfo>[];

      // 始终添加听筒和扬声器
      devices.add(AudioDeviceInfo(
        id: 'earpiece',
        name: '听筒',
        route: AudioRoute.earpiece,
        isDefault: _currentRoute == AudioRoute.earpiece,
      ));

      devices.add(AudioDeviceInfo(
        id: 'speaker',
        name: '扬声器',
        route: AudioRoute.speaker,
        isDefault: _currentRoute == AudioRoute.speaker,
      ));

      // 获取系统音频设备
      try {
        final sessionDevices = await _audioSession?.getDevices();
        if (sessionDevices != null) {
          for (final device in sessionDevices) {
            if (device.isOutput) {
              AudioRoute? route;
              if (device.type == AudioDeviceType.bluetoothA2dp ||
                  device.type == AudioDeviceType.bluetoothSco ||
                  device.type == AudioDeviceType.bluetoothLe) {
                route = AudioRoute.bluetooth;
              } else if (device.type == AudioDeviceType.wiredHeadphones ||
                  device.type == AudioDeviceType.wiredHeadset) {
                route = AudioRoute.wired;
              }

              if (route != null) {
                devices.add(AudioDeviceInfo(
                  id: device.id,
                  name: device.name,
                  route: route,
                  isDefault: false,
                ));
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Error getting audio devices: $e');
      }

      _availableDevices = devices;
      onDevicesChanged?.call(devices);
    } catch (e) {
      debugPrint('Error updating devices: $e');
    }
  }

  /// 释放资源
  Future<void> dispose() async {
    await deactivate();
    onAudioRouteChanged = null;
    onDevicesChanged = null;
    onAudioInterrupted = null;
  }
}
