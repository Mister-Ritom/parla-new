import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:parla/utils/logger/app_logger.dart';

final authProvider = StateNotifierProvider<AuthProvider, User?>(
  (ref) => AuthProvider(),
);

class AuthProvider extends StateNotifier<User?> {
  AuthProvider() : super(null) {
    _init();
  }
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final googleSignIn = GoogleSignIn.instance;

  void _init() {
    _auth.authStateChanges().listen((User? user) {
      state = user;
    });
  }

  Future<User?> signInWithEmail(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user;
    if (user == null) throw Exception("User sign in failed");
    return user;
  }

  Future<User> createUserWithEmail(String email, String password) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user;
    if (user == null) throw Exception("User creation failed");
    return user;
  }

  Future<UserCredential> signInWithGoogle() async {
    final googleUser = await googleSignIn.authenticate();
    final googleAuth = googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );
    return FirebaseAuth.instance.signInWithCredential(credential);
  }

  Future<bool> isUsernameAvailable(String username) async {
    final db = FirebaseFirestore.instance.collection('users');
    try {
      final query = await db
          .where('username', isEqualTo: username.trim().toLowerCase())
          .limit(1)
          .get();

      return query.docs.isEmpty;
    } catch (e, st) {
      AppLogger.error(
        name: "Auth Provider",
        message: 'username_check_error',
        exception: e,
        stackTrace: st,
      );
      return false;
    }
  }

  Future<List<String>> generateSuggestions(String base) async {
    final random = Random();
    final suggestions = <String>[];
    while (suggestions.length < 3) {
      final s = '$base${random.nextInt(9999)}';
      if (await isUsernameAvailable(s)) {
        suggestions.add(s);
      } else {
        continue;
      }
    }
    return suggestions;
  }

  Future<void> signOut() async {
    await _auth.signOut();
    //sign out from google
    googleSignIn.signOut();
  }
}
