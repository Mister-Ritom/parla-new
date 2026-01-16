import 'package:cloud_firestore/cloud_firestore.dart';

class ShareKeyModel {
  final String shareKey;
  final String ownerUid;
  final String ownerUsername;
  final List<String> participantsUsernames;
  final DateTime? createdAt;
  final DateTime expireAt;
  ShareKeyModel({
    required this.shareKey,
    required this.ownerUid,
    required this.ownerUsername,
    required this.participantsUsernames,
    this.createdAt,
    required this.expireAt,
  });
  factory ShareKeyModel.fromMap(Map<String, dynamic> map) {
    return ShareKeyModel(
      shareKey: map['shareKey'] as String,
      ownerUid: map['ownerUid'] as String,
      ownerUsername: map['ownerUsername'] as String,
      participantsUsernames: List<String>.from(
        map['participantsUids'] as List<dynamic>,
      ),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      expireAt: (map['expireAt'] as Timestamp).toDate(),
    );
  }
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'shareKey': shareKey,
      'ownerUid': ownerUid,
      'ownerUsername': ownerUsername,
      'participantsUids': participantsUsernames,
      'createdAt': createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(createdAt!),
      'expireAt': Timestamp.fromDate(expireAt),
    };
  }
}
