import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:parla/utils/logger/app_logger.dart';
import 'package:parla/models/message_model.dart';

class EncryptionUtil {
  static final aes = AesGcm.with256bits();
  static final curve = X25519();

  static Future<MessageModel?> encryptTextMessage({
    required String message,
    required SimpleKeyPair senderPrivateKey,
    required Map<String, SimplePublicKey> recipientsPublicKeys,
    required String messageId,
    required String conversationId,
    required String senderUsername,
    required List<String> allParticipantsUids,
  }) async {
    try {
      final symmetricKey = SecretKeyData.random(length: 32);
      final nonce = aes.newNonce();

      final encrypted = await aes.encrypt(
        utf8.encode(message),
        secretKey: symmetricKey,
        nonce: nonce,
      );

      final senderPublicKey = await senderPrivateKey.extractPublicKey();

      final wrappedKeys = <String, String>{};

      for (final entry in recipientsPublicKeys.entries) {
        final sharedSecret = await curve.sharedSecretKey(
          keyPair: senderPrivateKey,
          remotePublicKey: entry.value,
        );

        final sharedHash = await Sha256().hash(
          await sharedSecret.extractBytes(),
        );

        final keyBytes = symmetricKey.bytes;
        final encryptedKey = List<int>.generate(keyBytes.length, (i) {
          return keyBytes[i] ^ sharedHash.bytes[i];
        });

        wrappedKeys[entry.key] = base64Encode(encryptedKey);
      }

      final model = MessageModel(
        id: messageId,
        conversationId: conversationId,
        senderUsername: senderUsername,
        receiverUsernames: allParticipantsUids, // all participants incl. sender
        status: MessageStatus.sent,
        type: MessageType.text,
        text: null,
        files: null,
        ciphertext: base64Encode(encrypted.cipherText),
        nonce: base64Encode(nonce),
        mac: base64Encode(encrypted.mac.bytes),
        wrappedKeys: wrappedKeys,
        ephemeralPublicKey: base64Encode(senderPublicKey.bytes),
      );

      return model;
    } catch (e, st) {
      AppLogger.error(
        name: "Encryption",
        message: "Failed to encrypt",
        exception: e,
        stackTrace: st,
      );
      return null;
    }
  }

  static Future<String?> decryptMessage({
    required Map<String, dynamic> payload,
    required SimpleKeyPair recipientPrivateKey,
    required SimplePublicKey senderEphemeralPublicKey,
    required String recipientUid,
  }) async {
    try {
      final wrappedKeys = payload['wrappedKeys'] as Map<String, dynamic>;
      final wrappedKeyBase64 = wrappedKeys[recipientUid];
      if (wrappedKeyBase64 == null) {
        throw Exception("Key not encrypted for this user");
      }

      final encryptedKey = base64Decode(wrappedKeyBase64);

      final sharedSecret = await curve.sharedSecretKey(
        keyPair: recipientPrivateKey,
        remotePublicKey: senderEphemeralPublicKey,
      );

      final sharedHash = await Sha256().hash(await sharedSecret.extractBytes());

      final symmetricKeyBytes = Uint8List.fromList(
        List<int>.generate(encryptedKey.length, (i) {
          return encryptedKey[i] ^ sharedHash.bytes[i];
        }),
      );

      final secretKey = SecretKey(symmetricKeyBytes);

      final nonce = base64Decode(payload['nonce']);
      final ciphertext = base64Decode(payload['ciphertext']);
      final mac = Mac(base64Decode(payload['mac']));

      final decrypted = await aes.decrypt(
        SecretBox(ciphertext, nonce: nonce, mac: mac),
        secretKey: secretKey,
      );

      return utf8.decode(decrypted);
    } catch (e, st) {
      AppLogger.error(
        name: "Decryption",
        message: "Failed to decrypt",
        exception: e,
        stackTrace: st,
      );
      return null;
    }
  }
}
