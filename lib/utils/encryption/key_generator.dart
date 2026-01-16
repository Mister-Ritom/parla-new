import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:parla/utils/logger/app_logger.dart';

class KeyGenerator {
  static const _keyName = 'private_key';
  static final _algo = X25519();
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static Future<String> generateAndStoreKey() async {
    AppLogger.info(name: "KeyGenerator", message: "Generating new key pair");
    final keyPair = await generateKey();
    await savePrivateKey(keyPair);
    final publicKey = await keyPair.extractPublicKey();
    return base64Encode(publicKey.bytes);
  }

  static Future<SimpleKeyPair> generateKey() async {
    return await _algo.newKeyPair();
  }

  static Future<void> savePrivateKey(SimpleKeyPair keyPair) async {
    final bytes = await keyPair.extractPrivateKeyBytes();
    await _storage.write(key: _keyName, value: base64Encode(bytes));
  }

  static Future<SimpleKeyPair?> getKey() async {
    final stored = await _storage.read(key: _keyName);
    if (stored == null) return null;

    final privateBytes = base64Decode(stored);

    // Rebuild full keypair (private + public) from seed
    return await X25519().newKeyPairFromSeed(privateBytes);
  }

  static Future<bool> keyExists() async {
    return (await _storage.read(key: _keyName)) != null;
  }
}
