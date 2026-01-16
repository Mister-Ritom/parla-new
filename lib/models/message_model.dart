import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:parla/utils/logger/app_logger.dart';

enum MessageType {
  text(0),
  media(1),
  both(2),
  system(3);

  final int value;
  const MessageType(this.value);

  // Parse from int (Firestore)
  factory MessageType.fromValue(int value) {
    return MessageType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => MessageType.text,
    );
  }

  @override
  String toString() => name; // Returns 'text', 'media', etc.
}

enum MessageStatus {
  preview(-1),
  sent(0),
  delivered(1),
  read(2);

  final int value;
  const MessageStatus(this.value);

  // Parse from int (Firestore)
  factory MessageStatus.fromValue(int value) {
    return MessageStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => MessageStatus.sent,
    );
  }

  @override
  String toString() => name;
}

class MessageModel {
  final String id;
  final String conversationId;
  final String senderUsername;
  final List<String> receiverUsernames;
  final MessageModel? replyTo;
  final String? text;
  final List<FileAttachment>? files;
  final MessageType type;
  final MessageStatus status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  // E2EE Fields
  final String? ciphertext;
  final String? nonce;
  final String? mac;
  final Map<String, String>? wrappedKeys;
  final String? ephemeralPublicKey;

  // Social
  final Map<String, List<String>>? reactions;

  MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderUsername,
    required this.receiverUsernames,
    required this.type,
    required this.status,
    this.replyTo,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.text,
    this.files,
    this.ciphertext,
    this.nonce,
    this.mac,
    this.wrappedKeys,
    this.ephemeralPublicKey,
    this.reactions,
  });

  bool get isEdited =>
      updatedAt != null && createdAt != null && updatedAt!.isAfter(createdAt!);
  bool get isDeleted => deletedAt != null;

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    return MessageModel(
      id: map['id'],
      conversationId: map['cid'],
      senderUsername: map['s_un'],
      receiverUsernames: List<String>.from(map['rx_un'] ?? []),
      text: map['text'],
      replyTo: map['replyTo'] == null
          ? null
          : MessageModel.fromMap(Map<String, dynamic>.from(map['replyTo'])),

      // Using the Enum factory for parsing
      type: MessageType.fromValue(map['type'] ?? 0),
      status: MessageStatus.fromValue(map['status'] ?? 0),
      reactions: (map['reactions'] as Map?)?.map(
        (k, v) => MapEntry(k as String, List<String>.from(v)),
      ),
      files: map['files'] == null
          ? null
          : (map['files'] as List)
                .map(
                  (f) => FileAttachment.fromMap(Map<String, dynamic>.from(f)),
                )
                .toList(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
      deletedAt: (map['deletedAt'] as Timestamp?)?.toDate(),
      ciphertext: map['ctx'],
      nonce: map['nonce'],
      mac: map['mac'],
      wrappedKeys: map['wks'] == null
          ? null
          : Map<String, String>.from(map['wks']),
      ephemeralPublicKey: map['epk'],
    );
  }

  Map<String, dynamic> _toMap() {
    return {
      'id': id,
      'cid': conversationId,
      's_un': senderUsername,
      'rx_un': receiverUsernames,
      'text': null,
      'files': null,
      'type': MessageType.text.value,
      'status': MessageStatus.read.value,
      'replyTo': null,
      'ctx': ciphertext,
      'nonce': nonce,
      'mac': mac,
      'wks': wrappedKeys,
      'epk': ephemeralPublicKey,
      'reactions': null,
      'createdAt': null,
      'updatedAt': null,
      'deletedAt': null,
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cid': conversationId,
      's_un': senderUsername,
      'rx_un': receiverUsernames,
      'text': text,
      'type': type.value, // Store the int value in DB
      'status': status.value, // Store the int value in DB
      'replyTo': replyTo?._toMap(),
      'reactions': reactions,
      'files': files?.map((f) => f.toMap()).toList(),
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'deletedAt': deletedAt,
      'ctx': ciphertext,
      'nonce': nonce,
      'mac': mac,
      'wks': wrappedKeys,
      'epk': ephemeralPublicKey,
    };
  }

  static Future<void> deleteMessageDocument({required String messageId}) async {
    try {
      final Map<String, dynamic> updateData = {
        'text': "[deleted]",
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

  MessageModel copyWith({
    String? id,
    String? conversationId,
    String? senderUsername,
    List<String>? receiverUsernames,
    MessageModel? replyTo,
    String? text,
    List<FileAttachment>? files,
    MessageType? type,
    MessageStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    String? ciphertext,
    String? nonce,
    String? mac,
    Map<String, String>? wrappedKeys,
    String? ephemeralPublicKey,
    Map<String, List<String>>? reactions,
  }) {
    return MessageModel(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderUsername: senderUsername ?? this.senderUsername,
      receiverUsernames: receiverUsernames ?? this.receiverUsernames,
      replyTo: replyTo ?? this.replyTo,
      text: text ?? this.text,
      files: files ?? this.files,
      type: type ?? this.type,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      ciphertext: ciphertext ?? this.ciphertext,
      nonce: nonce ?? this.nonce,
      mac: mac ?? this.mac,
      wrappedKeys: wrappedKeys ?? this.wrappedKeys,
      ephemeralPublicKey: ephemeralPublicKey ?? this.ephemeralPublicKey,
      reactions: reactions ?? this.reactions,
    );
  }
}

class FileAttachment {
  final String? url;
  final String? path;
  final String name;
  final int size;
  final String mimeType;

  // Either url (remote) or path (local) must be provided.
  FileAttachment({
    this.url,
    this.path,
    required this.name,
    required this.size,
    required this.mimeType,
  });

  factory FileAttachment.fromMap(Map<String, dynamic> map) {
    return FileAttachment(
      url: map['url'],
      path: map['path'],
      name: map['name'],
      size: map['size'],
      mimeType: map['mimeType'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'url': url,
      'path': path,
      'name': name,
      'size': size,
      'mimeType': mimeType,
    };
  }

  FileAttachment copyWith({
    String? url,
    String? path,
    String? name,
    int? size,
    String? mimeType,
    bool pathNull = false,
  }) {
    return FileAttachment(
      url: url ?? this.url,
      path: pathNull ? null : path ?? this.path,
      name: name ?? this.name,
      size: size ?? this.size,
      mimeType: mimeType ?? this.mimeType,
    );
  }
}
