import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String username;
  final String email;
  final String displayName;

  final String publicKey; // Public key for encryption
  final String? bio;
  final bool isPublic;
  final String? photoURL;
  final String? coverURL;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserModel({
    required this.uid,
    required this.username,
    required this.email,
    required this.displayName,
    required this.publicKey,
    this.isPublic = false,
    this.createdAt,
    this.updatedAt,
    this.bio,
    this.photoURL,
    this.coverURL,
  });
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] as String,
      username: map['username'] as String,
      email: map['email'] as String,
      displayName: map['displayName'] as String,
      bio: map['bio'] as String?,
      isPublic: map['isPublic'] ?? false,
      photoURL: map['photoURL'],
      coverURL: map['coverURL'],
      publicKey: map['publicKey'] as String,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'username': username,
      'email': email,
      'displayName': displayName,
      'bio': bio,
      'photoURL': photoURL,
      'coverURL': coverURL,
      'publicKey': publicKey,
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
