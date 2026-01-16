import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cryptography/cryptography.dart';
import 'package:easy_overlay/easy_overlay.dart';
import 'package:flutter/material.dart';
import 'package:parla/models/conversation_model.dart';
import 'package:parla/models/message_model.dart';
import 'package:parla/models/share_key.dart';
import 'package:parla/models/user_model.dart';
import 'package:parla/utils/encryption/encryption_util.dart';
import 'package:parla/utils/logger/app_logger.dart';
import 'package:parla/utils/logger/firestore_exception_format.dart';

class FirestoreService {
  static Query<ShareKeyModel> getOwnerKeys(String ownerUsername) {
    final db = FirebaseFirestore.instance.collection("ShareKeys");
    return db
        .where("ownerUsername", isEqualTo: ownerUsername)
        .where('expireAt', isGreaterThan: Timestamp.now())
        .withConverter(
          fromFirestore: (snapshot, _) =>
              ShareKeyModel.fromMap(snapshot.data()!),
          toFirestore: (key, _) => key.toMap(),
        );
  }

  static Query<MessageModel> getMessagesQuery(String conversationId) {
    return FirebaseFirestore.instance
        .collection("messages")
        .where("cid", isEqualTo: conversationId)
        .orderBy("createdAt")
        .withConverter<MessageModel>(
          fromFirestore: (snapshot, _) =>
              MessageModel.fromMap(snapshot.data()!),
          toFirestore: (message, _) => message.toMap(),
        );
  }

  static Query<MessageModel> getMessagesQueryDesc(String conversationId) {
    return FirebaseFirestore.instance
        .collection("messages")
        .where("cid", isEqualTo: conversationId)
        .orderBy("createdAt", descending: true)
        .withConverter<MessageModel>(
          fromFirestore: (snapshot, _) =>
              MessageModel.fromMap(snapshot.data()!),
          toFirestore: (message, _) => message.toMap(),
        );
  }

  static Future<void> createKeyDocument(ShareKeyModel key) async {
    try {
      final db = FirebaseFirestore.instance.collection("ShareKeys");
      AppLogger.info(
        name: "Firestore",
        message: "Creating new key document for ${key.ownerUsername}",
      );
      await db.doc().set(key.toMap());
    } catch (e, st) {
      final formatted = FirestoreExceptionFormatter.format(e);
      AppLogger.error(
        name: "Firestore",
        message: formatted.title,
        exception: e,
        stackTrace: st,
      );
      EasyOverlay.showToast(
        message: formatted.message,
        alignment: const Alignment(0, -0.8),
        duration: const Duration(seconds: 4),
      );
    }
  }

  static Future<bool> isKeyValid(
    String key,
    String ownerUsername,
    String currentUsername,
  ) async {
    try {
      final query = await getOwnerKeys(
        ownerUsername,
      ).where("shareKey", isEqualTo: key).limit(1).get();

      if (query.docs.isEmpty) return false;

      final shareKey = query.docs.first.data();

      if (shareKey.participantsUsernames.isEmpty) return true;
      return shareKey.participantsUsernames.contains(currentUsername);
    } catch (e, st) {
      AppLogger.error(
        name: "Firestore",
        message: "Share key validation failed",
        exception: e,
        stackTrace: st,
      );
      return false;
    }
  }

  static Future<UserModel?> getUserDocument(String uid) async {
    try {
      final db = FirebaseFirestore.instance.collection("Users");
      final doc = await db.doc(uid).get();
      if (!doc.exists || doc.data() == null) {
        throw Exception("User document doesn't exist");
      }
      final user = UserModel.fromMap(doc.data()!);
      return user;
    } catch (e, st) {
      final formatted = FirestoreExceptionFormatter.format(e);
      AppLogger.error(
        name: "Firestore",
        message: formatted.title,
        exception: e,
        stackTrace: st,
      );
      EasyOverlay.showToast(
        message: formatted.message,
        alignment: const Alignment(0, -0.8),
        duration: const Duration(seconds: 4),
      );
      return null;
    }
  }

  static Query<UserModel> getUserQuery(String username) {
    return FirebaseFirestore.instance
        .collection("Users")
        .where("username", isEqualTo: username)
        .limit(1)
        .withConverter(
          fromFirestore: (snap, _) => UserModel.fromMap(snap.data()!),
          toFirestore: (u, _) => u.toMap(),
        );
  }

  static Query<UserModel> getPublicUsersQuery() {
    return FirebaseFirestore.instance
        .collection("Users")
        .where("isPublic", isEqualTo: true)
        .withConverter(
          fromFirestore: (snap, _) => UserModel.fromMap(snap.data()!),
          toFirestore: (u, _) => u.toMap(),
        );
  }

  static Query<ConversationModel> getPublicConversationQuery({String? search}) {
    Query<ConversationModel> query = FirebaseFirestore.instance
        .collection("conversations")
        .where("isPublic", isEqualTo: true)
        .where("title", isNotEqualTo: null)
        .withConverter(
          fromFirestore: (snap, _) => ConversationModel.fromMap(snap.data()!),
          toFirestore: (u, _) => u.toMap(),
        );

    if (search != null && search.isNotEmpty) {
      query = query
          .where("title", isGreaterThanOrEqualTo: search)
          .where("title", isLessThanOrEqualTo: "$search\uf8ff");
    }

    return query;
  }

  static Query<UserModel> getPublicUsersQueryCurrent(String currentUsername) {
    return getPublicUsersQuery().where(
      "username",
      isNotEqualTo: currentUsername,
    );
  }

  static Query<ConversationModel> getUserConversationsQuery(
    String currentUsername,
  ) {
    return FirebaseFirestore.instance
        .collection("conversations")
        .where("recipients", arrayContains: currentUsername)
        .withConverter<ConversationModel>(
          fromFirestore: (snapshot, _) =>
              ConversationModel.fromMap(snapshot.data()!),
          toFirestore: (conversation, _) => conversation.toMap(),
        );
  }

  static Future<List<ConversationModel>> getUserConversations(
    String currentUsername,
  ) async {
    try {
      final query = getUserConversationsQuery(currentUsername);
      final snapshot = await query.get();

      return snapshot.docs.map((e) => e.data()).toList();
    } catch (e, st) {
      final formatted = FirestoreExceptionFormatter.format(e);
      AppLogger.error(
        name: "Firestore",
        message: formatted.title,
        exception: e,
        stackTrace: st,
      );
      return [];
    }
  }

  static bool _sameRecipients(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    final aa = [...a]..sort();
    final bb = [...b]..sort();
    for (int i = 0; i < aa.length; i++) {
      if (aa[i] != bb[i]) return false;
    }
    return true;
  }

  static Future<String?> createConversationDocument(
    Map<String, ConversationMap> recipients,
    String creatorUsername, {
    String? title,
    String? photoURL,
  }) async {
    try {
      final userConvos = await getUserConversations(creatorUsername);
      final existing = userConvos
          .where((c) => _sameRecipients(c.recipients, recipients.keys.toList()))
          .toList();

      if (existing.isNotEmpty) return existing.first.id;

      final db = FirebaseFirestore.instance.collection("conversations");
      final doc = db.doc();

      final conversation = ConversationModel(
        id: doc.id,
        recipientsMap: recipients,
        recipients: recipients.keys.toList(),
        creatorUsername: creatorUsername,
        title: title,
        photoURL: photoURL,
      );

      await doc.set(conversation.toMap());
      return doc.id;
    } catch (e, st) {
      final formatted = FirestoreExceptionFormatter.format(e);
      AppLogger.error(
        name: "Firestore",
        message: formatted.title,
        exception: e,
        stackTrace: st,
      );
      EasyOverlay.showToast(
        message: 'Creating chat failed',
        alignment: const Alignment(0, -0.8),
        duration: const Duration(seconds: 4),
      );
      return null;
    }
  }

  // Updated createMessageDocument with isPreview parameter
  static Future<String?> createMessageDocument({
    required ConversationModel conversation,
    required String senderUsername,
    required String messageString,
    required List<FileAttachment> files,
    required SimpleKeyPair senderPrivateKey,
    MessageModel? replyTo,
    bool isPreview = false, // Added parameter
  }) async {
    try {
      final recipients = conversation.recipients;
      final recipientsMap = conversation.recipientsMap;

      final pubKeys = <String, SimplePublicKey>{};
      final allUids = <String>[];

      for (final username in recipients) {
        final info = recipientsMap[username];
        if (info == null) continue;

        final publicKey = SimplePublicKey(
          base64Decode(info.publicKey),
          type: KeyPairType.x25519,
        );

        pubKeys[info.uid] = publicKey;
        allUids.add(info.uid);
      }

      final messageId = FirebaseFirestore.instance
          .collection("messages")
          .doc()
          .id;

      final encrypted = await EncryptionUtil.encryptTextMessage(
        message: messageString,
        senderPrivateKey: senderPrivateKey,
        recipientsPublicKeys: pubKeys,
        messageId: messageId,
        conversationId: conversation.id,
        senderUsername: senderUsername,
        allParticipantsUids: allUids,
      );

      if (encrypted == null) return null;

      // If preview, we still save the local files reference so the UI can show them
      // immediately while uploading, or we save null and let the UI handle it.
      // Usually, for preview, we save what we have.
      final model = encrypted.copyWith(
        files: files.isEmpty ? null : files,
        replyTo: replyTo,
        status: isPreview ? MessageStatus.preview : MessageStatus.sent,
      );

      await FirebaseFirestore.instance
          .collection("messages")
          .doc(messageId)
          .set(model.toMap());

      return messageId;
    } catch (e, st) {
      AppLogger.error(
        name: "Firestore",
        message: "Failed to create message document",
        exception: e,
        stackTrace: st,
      );
      return null;
    }
  }

  // New updateMessageDocument function
  static Future<void> updateMessageDocument({
    required String messageId,
    List<FileAttachment>? files,
    // We force status to sent here
  }) async {
    try {
      final Map<String, dynamic> data = {
        // Assuming MessageStatus is stored as a string or handled by your model's enum serialization
        // Adjust 'sent' to match your enum serialization (e.g., 'sent' or 1)
        'status': MessageStatus.sent.value,
      };

      if (files != null) {
        data['files'] = files.map((e) => e.toMap()).toList();
      }

      await FirebaseFirestore.instance
          .collection("messages")
          .doc(messageId)
          .update(data);
    } catch (e, st) {
      AppLogger.error(
        name: "Firestore",
        message: "Failed to update message document with files change",
        exception: e,
        stackTrace: st,
      );
    }
  }

  static Future<void> updateMessageDocumentText({
    required MessageModel oldModel,
    required ConversationModel conversation,
    required String newText,
    required SimpleKeyPair senderPrivateKey,
  }) async {
    try {
      final recipients = conversation.recipients;
      final recipientsMap = conversation.recipientsMap;

      final pubKeys = <String, SimplePublicKey>{};
      final allUids = <String>[];

      for (final username in recipients) {
        final info = recipientsMap[username];
        if (info == null) continue;

        final publicKey = SimplePublicKey(
          base64Decode(info.publicKey),
          type: KeyPairType.x25519,
        );

        pubKeys[info.uid] = publicKey;
        allUids.add(info.uid);
      }

      // Encrypt the new text
      final newModel = await EncryptionUtil.encryptTextMessage(
        message: newText,
        senderPrivateKey: senderPrivateKey,
        recipientsPublicKeys: pubKeys,
        messageId: oldModel.id,
        conversationId: conversation.id,
        senderUsername: oldModel.senderUsername,
        allParticipantsUids: allUids,
      );

      if (newModel == null) return;

      final Map<String, dynamic> updateData = {
        'status': MessageStatus.sent.value, // always
        'text': newModel.text,
        'ctx': newModel.ciphertext,
        'nonce': newModel.nonce,
        'mac': newModel.mac,
        'wks': newModel.wrappedKeys,
        'epk': newModel.ephemeralPublicKey,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection("messages")
          .doc(oldModel.id)
          .update(updateData);
    } catch (e, st) {
      AppLogger.error(
        name: "Firestore",
        message: "Failed to update message document with text change",
        exception: e,
        stackTrace: st,
      );
    }
  }

  static Future<void> deleteMessageDocument({required String messageId}) async {
    try {
      final Map<String, dynamic> updateData = {
        'replyTo': null,
        'deletedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection("messages")
          .doc(messageId)
          .update(updateData);
    } catch (e, st) {
      AppLogger.error(
        name: "Firestore",
        message: "Failed to delete message document",
        exception: e,
        stackTrace: st,
      );
    }
  }

  static Future<void> createUserDocument({
    required String uid,
    required String email,
    required String username,
    required String publicKey,
    String? displayName,
    String? photoURL,
    S,
  }) async {
    try {
      final db = FirebaseFirestore.instance.collection("Users");
      final model = UserModel(
        uid: uid,
        username: username,
        email: email,
        displayName: displayName ?? username,
        photoURL: photoURL,
        publicKey: publicKey,
      );

      await db.doc(uid).set(model.toMap());
      AppLogger.info(name: "Firestore", message: "User document created: $uid");
    } catch (e, st) {
      final formatted = FirestoreExceptionFormatter.format(e);
      AppLogger.error(
        name: "Firestore",
        message: formatted.title,
        exception: e,
        stackTrace: st,
      );
      EasyOverlay.showToast(
        message: formatted.message,
        alignment: const Alignment(0, -0.8),
        duration: const Duration(seconds: 4),
      );
    }
  }

  static Future<void> updateUserProfile({
    required String uid,
    String? username,
    String? displayName,
    String? bio,
    String? photoURL,
    String? coverURL, // Fixed typo from 'converURL' in your model
  }) async {
    try {
      final db = FirebaseFirestore.instance.collection("Users");

      // Prepare a map of fields to update
      final Map<String, dynamic> updateData = {
        "updatedAt": FieldValue.serverTimestamp(),
      };

      // Only add fields to the map if they are not null
      if (username != null) updateData["username"] = username;
      if (displayName != null) updateData["displayName"] = displayName;
      if (bio != null) updateData["bio"] = bio;
      if (photoURL != null) updateData["photoURL"] = photoURL;
      if (coverURL != null) updateData["coverURL"] = coverURL;

      await db.doc(uid).update(updateData);

      AppLogger.info(name: "Firestore", message: "User document updated: $uid");
    } catch (e, st) {
      final formatted = FirestoreExceptionFormatter.format(e);
      AppLogger.error(
        name: "Firestore",
        message: formatted.title,
        exception: e,
        stackTrace: st,
      );
      EasyOverlay.showToast(
        message: formatted.message,
        alignment: const Alignment(0, -0.8),
        duration: const Duration(seconds: 4),
      );
    }
  }

  static Query<ConversationModel> getConversationQuery(String id) {
    final db = FirebaseFirestore.instance.collection("conversations");
    return db
        .where("id", isEqualTo: id)
        .limit(1)
        .withConverter(
          fromFirestore: (snapshot, _) =>
              ConversationModel.fromMap(snapshot.data()!),
          toFirestore: (model, _) => model.toMap(),
        );
  }
}
