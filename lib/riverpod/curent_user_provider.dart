import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:parla/models/user_model.dart';
import 'package:parla/riverpod/auth_provider.dart';
import 'package:parla/services/firestore_service.dart';

final currentUserProvider =
    StateNotifierProvider<CurrentUserNotifier, UserModel?>(
      (ref) => CurrentUserNotifier(ref),
    );

class CurrentUserNotifier extends StateNotifier<UserModel?> {
  final Ref ref;

  CurrentUserNotifier(this.ref) : super(null) {
    ref.listen<User?>(authProvider, (_, next) {
      _onAuthChanged(next);
    }, fireImmediately: true);
  }

  Future<void> _onAuthChanged(User? user) async {
    if (user == null) {
      state = null;
      return;
    }

    final model = await FirestoreService.getUserDocument(user.uid);
    state = model;
  }
}
