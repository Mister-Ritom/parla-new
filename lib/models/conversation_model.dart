import 'package:cloud_firestore/cloud_firestore.dart';

class ConversationModel {
  final String id;
  final String? title;
  final Map<String, ConversationMap> recipientsMap;
  final bool isPublic;
  final List<String> recipients;
  final DateTime? lastMessageAt;
  final String? lastMessage;
  final String? lastMessageSender;
  final String? photoURL;
  final int unreadCount;
  final String? creatorUsername;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ConversationModel({
    required this.id,
    required this.recipients,
    required this.recipientsMap,
    this.isPublic = false,
    this.title,
    this.photoURL,
    this.lastMessageAt,
    this.lastMessageSender,
    this.lastMessage,
    this.unreadCount = 0,
    this.creatorUsername,
    this.createdAt,
    this.updatedAt,
  });

  factory ConversationModel.fromMap(Map<String, dynamic> map) {
    final raw = Map<String, dynamic>.from(map['recipientsMap'] ?? {});

    final parsedRecipientsMap = <String, ConversationMap>{};

    raw.forEach((key, value) {
      parsedRecipientsMap[key] = ConversationMap.fromMap(
        Map<String, dynamic>.from(value),
      );
    });

    return ConversationModel(
      id: map['id'] ?? '',
      recipients: List<String>.from(map['recipients'] ?? []),
      recipientsMap: parsedRecipientsMap,
      lastMessageAt: map['lastMessageAt']?.toDate(),
      lastMessage: map['lastMessage'],
      unreadCount: map['unreadCount'] ?? 0,
      lastMessageSender: map['lastMessageSender'],
      title: map['title'],
      photoURL: map['photoURL'],
      creatorUsername: map['creatorUsername'],
      createdAt: map['createdAt']?.toDate(),
      updatedAt: map['updatedAt']?.toDate(),
      isPublic: map['isPublic'],
    );
  }

  Map<String, dynamic> toMap() {
    final recipientsMapRaw = <String, dynamic>{};

    recipientsMap.forEach((key, value) {
      recipientsMapRaw[key] = value.toMap();
    });

    return {
      'id': id,
      'recipients': recipients,
      'recipientsMap': recipientsMapRaw,
      'lastMessageAt': lastMessageAt == null
          ? null
          : Timestamp.fromDate(lastMessageAt!),
      'lastMessage': lastMessage,
      'unreadCount': unreadCount,
      'lastMessageSender': lastMessageSender,
      'title': title,
      'photoURL': photoURL,
      'creatorUsername': creatorUsername,
      'isPublic': isPublic,
      'createdAt': createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(createdAt!),
      'updatedAt': updatedAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(updatedAt!),
    };
  }
}

enum UserRole {
  memeber(0),
  admin(1);

  final int value;

  const UserRole(this.value);

  static UserRole parse(int value) {
    switch (value) {
      case 0:
        return UserRole.memeber;
      case 1:
        return UserRole.admin;
      default:
        return UserRole.memeber;
    }
  }
}

class ConversationMap {
  final String username;
  final String uid;
  final String publicKey;
  final UserRole role;

  ConversationMap({
    required this.username,
    required this.uid,
    required this.publicKey,
    required this.role,
  });
  factory ConversationMap.fromMap(Map<String, dynamic> map) {
    return ConversationMap(
      username: map['username'],
      uid: map['uid'],
      publicKey: map['publicKey'],
      role: UserRole.parse(map['role'] ?? UserRole.memeber.value),
    );
  }
  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'uid': uid,
      'publicKey': publicKey,
      'role': role,
    };
  }
}
