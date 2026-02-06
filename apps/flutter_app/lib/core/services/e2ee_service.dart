import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 密钥类型
enum KeyType { identity, signed, oneTime }

/// 设备密钥包
class DeviceKeyBundle {
  final KeyPair identityKey;
  final SignedPreKey signedPreKey;
  final List<PreKey> oneTimePreKeys;

  DeviceKeyBundle({
    required this.identityKey,
    required this.signedPreKey,
    required this.oneTimePreKeys,
  });
}

/// 密钥对
class KeyPair {
  final String keyId;
  final Uint8List privateKey;
  final Uint8List publicKey;

  KeyPair({
    required this.keyId,
    required this.privateKey,
    required this.publicKey,
  });

  String get publicKeyBase64 => base64Encode(publicKey);
  String get privateKeyBase64 => base64Encode(privateKey);
}

/// 预密钥
class PreKey {
  final String keyId;
  final Uint8List publicKey;

  PreKey({required this.keyId, required this.publicKey});

  String get publicKeyBase64 => base64Encode(publicKey);
}

/// 签名预密钥
class SignedPreKey extends PreKey {
  final Uint8List signature;

  SignedPreKey({
    required super.keyId,
    required super.publicKey,
    required this.signature,
  });

  String get signatureBase64 => base64Encode(signature);
}

/// 远程密钥包
class RemoteKeyBundle {
  final String userId;
  final String deviceId;
  final String identityKeyId;
  final Uint8List identityPublicKey;
  final String signedPreKeyId;
  final Uint8List signedPreKeyPublic;
  final Uint8List signedPreKeySignature;
  final String? oneTimeKeyId;
  final Uint8List? oneTimeKeyPublic;

  RemoteKeyBundle({
    required this.userId,
    required this.deviceId,
    required this.identityKeyId,
    required this.identityPublicKey,
    required this.signedPreKeyId,
    required this.signedPreKeyPublic,
    required this.signedPreKeySignature,
    this.oneTimeKeyId,
    this.oneTimeKeyPublic,
  });

  factory RemoteKeyBundle.fromJson(Map<String, dynamic> json) {
    final identityKey = json['identity_key'] as Map<String, dynamic>?;
    final signedKey = json['signed_pre_key'] as Map<String, dynamic>?;
    final oneTimeKey = json['one_time_pre_key'] as Map<String, dynamic>?;

    return RemoteKeyBundle(
      userId: json['user_id'] ?? '',
      deviceId: json['device_id'] ?? '',
      identityKeyId: identityKey?['key_id'] ?? '',
      identityPublicKey: base64Decode(identityKey?['public_key'] ?? ''),
      signedPreKeyId: signedKey?['key_id'] ?? '',
      signedPreKeyPublic: base64Decode(signedKey?['public_key'] ?? ''),
      signedPreKeySignature: base64Decode(signedKey?['signature'] ?? ''),
      oneTimeKeyId: oneTimeKey?['key_id'],
      oneTimeKeyPublic: oneTimeKey != null
          ? base64Decode(oneTimeKey['public_key'] ?? '')
          : null,
    );
  }
}

/// 加密会话
class EncryptionSession {
  final String sessionId;
  final String peerUserId;
  final String peerDeviceId;
  Uint8List rootKey;
  Uint8List chainKeySend;
  Uint8List chainKeyReceive;
  int sendMessageNumber;
  int recvMessageNumber;
  Uint8List? dhRatchetPrivate;
  Uint8List? dhRatchetPublic;
  Uint8List? peerDHKey;

  EncryptionSession({
    required this.sessionId,
    required this.peerUserId,
    required this.peerDeviceId,
    required this.rootKey,
    required this.chainKeySend,
    required this.chainKeyReceive,
    this.sendMessageNumber = 0,
    this.recvMessageNumber = 0,
    this.dhRatchetPrivate,
    this.dhRatchetPublic,
    this.peerDHKey,
  });

  Map<String, dynamic> toJson() => {
        'session_id': sessionId,
        'peer_user_id': peerUserId,
        'peer_device_id': peerDeviceId,
        'root_key': base64Encode(rootKey),
        'chain_key_send': base64Encode(chainKeySend),
        'chain_key_receive': base64Encode(chainKeyReceive),
        'send_message_number': sendMessageNumber,
        'recv_message_number': recvMessageNumber,
        if (dhRatchetPrivate != null)
          'dh_ratchet_private': base64Encode(dhRatchetPrivate!),
        if (dhRatchetPublic != null)
          'dh_ratchet_public': base64Encode(dhRatchetPublic!),
        if (peerDHKey != null) 'peer_dh_key': base64Encode(peerDHKey!),
      };

  factory EncryptionSession.fromJson(Map<String, dynamic> json) {
    return EncryptionSession(
      sessionId: json['session_id'],
      peerUserId: json['peer_user_id'],
      peerDeviceId: json['peer_device_id'],
      rootKey: base64Decode(json['root_key']),
      chainKeySend: base64Decode(json['chain_key_send']),
      chainKeyReceive: base64Decode(json['chain_key_receive']),
      sendMessageNumber: json['send_message_number'] ?? 0,
      recvMessageNumber: json['recv_message_number'] ?? 0,
      dhRatchetPrivate: json['dh_ratchet_private'] != null
          ? base64Decode(json['dh_ratchet_private'])
          : null,
      dhRatchetPublic: json['dh_ratchet_public'] != null
          ? base64Decode(json['dh_ratchet_public'])
          : null,
      peerDHKey: json['peer_dh_key'] != null
          ? base64Decode(json['peer_dh_key'])
          : null,
    );
  }
}

/// 加密消息
class EncryptedMessage {
  final String messageId;
  final String sessionId;
  final Uint8List cipherText;
  final int messageNumber;
  final int previousChainLength;
  final Uint8List dhPublicKey;
  final Uint8List iv;
  final Uint8List authTag;

  EncryptedMessage({
    required this.messageId,
    required this.sessionId,
    required this.cipherText,
    required this.messageNumber,
    required this.previousChainLength,
    required this.dhPublicKey,
    required this.iv,
    required this.authTag,
  });

  Map<String, dynamic> toJson() => {
        'message_id': messageId,
        'session_id': sessionId,
        'cipher_text': base64Encode(cipherText),
        'message_number': messageNumber,
        'previous_chain_length': previousChainLength,
        'dh_public_key': base64Encode(dhPublicKey),
        'iv': base64Encode(iv),
        'auth_tag': base64Encode(authTag),
      };

  factory EncryptedMessage.fromJson(Map<String, dynamic> json) {
    return EncryptedMessage(
      messageId: json['message_id'],
      sessionId: json['session_id'],
      cipherText: base64Decode(json['cipher_text']),
      messageNumber: json['message_number'],
      previousChainLength: json['previous_chain_length'],
      dhPublicKey: base64Decode(json['dh_public_key']),
      iv: base64Decode(json['iv']),
      authTag: base64Decode(json['auth_tag']),
    );
  }
}

/// E2EE服务
class E2EEService {
  final Dio _dio;
  final String _baseUrl;
  final FlutterSecureStorage _storage;
  final Random _random = Random.secure();

  // 本地密钥缓存
  KeyPair? _identityKeyPair;
  final Map<String, EncryptionSession> _sessions = {};

  E2EEService({
    required Dio dio,
    required String baseUrl,
    FlutterSecureStorage? storage,
  })  : _dio = dio,
        _baseUrl = baseUrl,
        _storage = storage ?? const FlutterSecureStorage();

  /// 初始化服务
  Future<void> initialize() async {
    await _loadIdentityKey();
    await _loadSessions();
  }

  /// 生成设备密钥包
  Future<DeviceKeyBundle> generateDeviceKeys({int oneTimeKeysCount = 100}) async {
    // 生成身份密钥对
    final identityKey = _generateKeyPair('identity_${_generateKeyId()}');
    _identityKeyPair = identityKey;

    // 生成签名预密钥
    final signedPreKey = _generateSignedPreKey(identityKey);

    // 生成一次性预密钥
    final oneTimePreKeys = List.generate(
      oneTimeKeysCount,
      (_) => PreKey(
        keyId: 'otk_${_generateKeyId()}',
        publicKey: _generateRandomBytes(32),
      ),
    );

    // 保存身份密钥
    await _saveIdentityKey(identityKey);

    return DeviceKeyBundle(
      identityKey: identityKey,
      signedPreKey: signedPreKey,
      oneTimePreKeys: oneTimePreKeys,
    );
  }

  /// 注册设备密钥到服务器
  Future<void> registerDeviceKeys(String deviceId, DeviceKeyBundle keys) async {
    await _dio.post('$_baseUrl/e2ee/keys', data: {
      'device_id': deviceId,
      'identity_key': {
        'key_id': keys.identityKey.keyId,
        'public_key': keys.identityKey.publicKeyBase64,
      },
      'signed_pre_key': {
        'key_id': keys.signedPreKey.keyId,
        'public_key': keys.signedPreKey.publicKeyBase64,
        'signature': keys.signedPreKey.signatureBase64,
      },
      'one_time_pre_keys': keys.oneTimePreKeys
          .map((k) => {
                'key_id': k.keyId,
                'public_key': k.publicKeyBase64,
              })
          .toList(),
    });
  }

  /// 获取对方的密钥包
  Future<RemoteKeyBundle> fetchKeyBundle(String userId,
      {String? deviceId}) async {
    final path = deviceId != null
        ? '$_baseUrl/e2ee/keys/$userId/$deviceId'
        : '$_baseUrl/e2ee/keys/$userId';

    final response = await _dio.get(path);
    return RemoteKeyBundle.fromJson(response.data);
  }

  /// 建立加密会话（X3DH）
  Future<EncryptionSession> establishSession(
    String targetUserId, {
    String? targetDeviceId,
  }) async {
    // 获取对方密钥包
    final remoteBundle =
        await fetchKeyBundle(targetUserId, deviceId: targetDeviceId);

    // 验证签名预密钥
    // 实际实现中应该验证签名
    
    // 生成临时密钥对
    final ephemeralKey = _generateKeyPair('eph_${_generateKeyId()}');

    // 执行X3DH密钥协商
    // DH1 = DH(IK_A, SPK_B) - 我们的身份密钥与对方签名预密钥
    // DH2 = DH(EK_A, IK_B) - 我们的临时密钥与对方身份密钥
    // DH3 = DH(EK_A, SPK_B) - 我们的临时密钥与对方签名预密钥
    // DH4 = DH(EK_A, OPK_B) - 我们的临时密钥与对方一次性密钥（如果有）

    // 简化实现：使用HKDF派生共享密钥
    final sharedSecret = _deriveSharedSecret([
      _identityKeyPair!.privateKey,
      ephemeralKey.privateKey,
      remoteBundle.identityPublicKey,
      remoteBundle.signedPreKeyPublic,
      if (remoteBundle.oneTimeKeyPublic != null) remoteBundle.oneTimeKeyPublic!,
    ]);

    // 派生根密钥和链密钥
    final keys = _hkdfExpand(sharedSecret, 96, info: utf8.encode('E2EE_KEYS'));
    final rootKey = keys.sublist(0, 32);
    final chainKeySend = keys.sublist(32, 64);
    final chainKeyReceive = keys.sublist(64, 96);

    // 创建会话
    final sessionId = _generateKeyId();
    final session = EncryptionSession(
      sessionId: sessionId,
      peerUserId: targetUserId,
      peerDeviceId: remoteBundle.deviceId,
      rootKey: rootKey,
      chainKeySend: chainKeySend,
      chainKeyReceive: chainKeyReceive,
    );

    // 发送密钥交换消息到服务器
    await _dio.post('$_baseUrl/e2ee/sessions', data: {
      'target_user_id': targetUserId,
      'target_device_id': remoteBundle.deviceId,
      'ephemeral_public_key': ephemeralKey.publicKeyBase64,
      'identity_public_key': _identityKeyPair!.publicKeyBase64,
      'used_signed_key_id': remoteBundle.signedPreKeyId,
      'used_one_time_key_id': remoteBundle.oneTimeKeyId,
      'initial_cipher_text': '', // 可以包含初始消息
    });

    // 保存会话
    _sessions[session.sessionId] = session;
    await _saveSessions();

    return session;
  }

  /// 加密消息
  Future<EncryptedMessage> encryptMessage(
    String sessionId,
    String plainText,
  ) async {
    final session = _sessions[sessionId];
    if (session == null) {
      throw Exception('Session not found');
    }

    // 生成消息密钥
    final messageKey = _deriveMessageKey(
      session.chainKeySend,
      session.sendMessageNumber,
    );

    // 生成IV
    final iv = _generateRandomBytes(12);

    // 加密消息
    final plainBytes = utf8.encode(plainText);
    final encrypted = _aesGcmEncrypt(plainBytes, messageKey, iv);

    // 更新链密钥
    session.chainKeySend = _advanceChainKey(session.chainKeySend);
    session.sendMessageNumber++;
    await _saveSessions();

    return EncryptedMessage(
      messageId: _generateKeyId(),
      sessionId: sessionId,
      cipherText: encrypted['ciphertext']!,
      messageNumber: session.sendMessageNumber - 1,
      previousChainLength: 0,
      dhPublicKey: session.dhRatchetPublic ?? Uint8List(32),
      iv: iv,
      authTag: encrypted['tag']!,
    );
  }

  /// 解密消息
  Future<String> decryptMessage(EncryptedMessage message) async {
    final session = _sessions[message.sessionId];
    if (session == null) {
      throw Exception('Session not found');
    }

    // 派生消息密钥
    final messageKey = _deriveMessageKey(
      session.chainKeyReceive,
      message.messageNumber,
    );

    // 解密消息
    final plainBytes = _aesGcmDecrypt(
      message.cipherText,
      messageKey,
      message.iv,
      message.authTag,
    );

    // 更新接收计数
    if (message.messageNumber >= session.recvMessageNumber) {
      session.recvMessageNumber = message.messageNumber + 1;
      session.chainKeyReceive = _advanceChainKey(session.chainKeyReceive);
      await _saveSessions();
    }

    return utf8.decode(plainBytes);
  }

  /// 获取会话
  EncryptionSession? getSession(String sessionId) => _sessions[sessionId];

  /// 获取与用户的会话
  EncryptionSession? getSessionWithUser(String userId) {
    return _sessions.values.firstWhere(
      (s) => s.peerUserId == userId,
      orElse: () => throw Exception('No session with user'),
    );
  }

  /// 列出所有会话
  List<EncryptionSession> listSessions() => _sessions.values.toList();

  /// 终止会话
  Future<void> terminateSession(String sessionId) async {
    _sessions.remove(sessionId);
    await _saveSessions();

    try {
      await _dio.delete('$_baseUrl/e2ee/sessions/$sessionId');
    } catch (_) {}
  }

  // ==================== 私有方法 ====================

  /// 生成密钥对
  KeyPair _generateKeyPair(String keyId) {
    // 简化实现：生成随机密钥
    // 实际应使用X25519
    final privateKey = _generateRandomBytes(32);
    final publicKey = _generateRandomBytes(32); // 实际应从私钥派生

    return KeyPair(
      keyId: keyId,
      privateKey: privateKey,
      publicKey: publicKey,
    );
  }

  /// 生成签名预密钥
  SignedPreKey _generateSignedPreKey(KeyPair identityKey) {
    final keyId = 'spk_${_generateKeyId()}';
    final publicKey = _generateRandomBytes(32);

    // 使用身份密钥签名
    final signature = _sign(publicKey, identityKey.privateKey);

    return SignedPreKey(
      keyId: keyId,
      publicKey: publicKey,
      signature: signature,
    );
  }

  /// 签名
  Uint8List _sign(Uint8List data, Uint8List privateKey) {
    // 简化实现：使用HMAC作为签名
    final hmac = Hmac(sha256, privateKey);
    return Uint8List.fromList(hmac.convert(data).bytes);
  }

  /// 派生共享密钥
  Uint8List _deriveSharedSecret(List<Uint8List> inputs) {
    // 简化实现：连接所有输入并哈希
    final combined = inputs.expand((x) => x).toList();
    return Uint8List.fromList(sha256.convert(combined).bytes);
  }

  /// HKDF扩展
  Uint8List _hkdfExpand(Uint8List key, int length, {List<int>? info}) {
    final hmac = Hmac(sha256, key);
    final result = <int>[];
    List<int> previous = <int>[];
    var counter = 1;

    while (result.length < length) {
      final List<int> input = [...previous, ...(info ?? <int>[]), counter];
      previous = hmac.convert(input).bytes.toList();
      result.addAll(previous);
      counter++;
    }

    return Uint8List.fromList(result.sublist(0, length));
  }

  /// 派生消息密钥
  Uint8List _deriveMessageKey(Uint8List chainKey, int messageNumber) {
    final hmac = Hmac(sha256, chainKey);
    final input = utf8.encode('MSG_KEY_$messageNumber');
    return Uint8List.fromList(hmac.convert(input).bytes);
  }

  /// 推进链密钥
  Uint8List _advanceChainKey(Uint8List chainKey) {
    final hmac = Hmac(sha256, chainKey);
    final input = utf8.encode('CHAIN_KEY');
    return Uint8List.fromList(hmac.convert(input).bytes);
  }

  /// AES-GCM加密
  Map<String, Uint8List> _aesGcmEncrypt(
      Uint8List plaintext, Uint8List key, Uint8List iv) {
    // 简化实现：使用AES-CTR + HMAC模拟GCM
    // 实际应使用pointycastle的AES-GCM
    final hmac = Hmac(sha256, key);

    // 简单XOR加密（仅演示，生产环境应使用真正的AES-GCM）
    final ciphertext = Uint8List(plaintext.length);
    final keyStream = _hkdfExpand(key, plaintext.length, info: iv);
    for (var i = 0; i < plaintext.length; i++) {
      ciphertext[i] = plaintext[i] ^ keyStream[i];
    }

    // 计算认证标签
    final tag = Uint8List.fromList(hmac.convert([...iv, ...ciphertext]).bytes.sublist(0, 16));

    return {'ciphertext': ciphertext, 'tag': tag};
  }

  /// AES-GCM解密
  Uint8List _aesGcmDecrypt(
      Uint8List ciphertext, Uint8List key, Uint8List iv, Uint8List tag) {
    // 验证标签
    final hmac = Hmac(sha256, key);
    final expectedTag = hmac.convert([...iv, ...ciphertext]).bytes.sublist(0, 16);
    
    var valid = true;
    for (var i = 0; i < 16; i++) {
      if (tag[i] != expectedTag[i]) valid = false;
    }
    if (!valid) {
      throw Exception('Authentication failed');
    }

    // 解密
    final plaintext = Uint8List(ciphertext.length);
    final keyStream = _hkdfExpand(key, ciphertext.length, info: iv);
    for (var i = 0; i < ciphertext.length; i++) {
      plaintext[i] = ciphertext[i] ^ keyStream[i];
    }

    return plaintext;
  }

  /// 生成随机字节
  Uint8List _generateRandomBytes(int length) {
    return Uint8List.fromList(
      List.generate(length, (_) => _random.nextInt(256)),
    );
  }

  /// 生成密钥ID
  String _generateKeyId() {
    final bytes = _generateRandomBytes(16);
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  /// 加载身份密钥
  Future<void> _loadIdentityKey() async {
    final data = await _storage.read(key: 'e2ee_identity_key');
    if (data != null) {
      final json = jsonDecode(data);
      _identityKeyPair = KeyPair(
        keyId: json['key_id'],
        privateKey: base64Decode(json['private_key']),
        publicKey: base64Decode(json['public_key']),
      );
    }
  }

  /// 保存身份密钥
  Future<void> _saveIdentityKey(KeyPair key) async {
    await _storage.write(
      key: 'e2ee_identity_key',
      value: jsonEncode({
        'key_id': key.keyId,
        'private_key': key.privateKeyBase64,
        'public_key': key.publicKeyBase64,
      }),
    );
  }

  /// 加载会话
  Future<void> _loadSessions() async {
    final data = await _storage.read(key: 'e2ee_sessions');
    if (data != null) {
      final List<dynamic> list = jsonDecode(data);
      for (final item in list) {
        final session = EncryptionSession.fromJson(item);
        _sessions[session.sessionId] = session;
      }
    }
  }

  /// 保存会话
  Future<void> _saveSessions() async {
    final list = _sessions.values.map((s) => s.toJson()).toList();
    await _storage.write(key: 'e2ee_sessions', value: jsonEncode(list));
  }
}
