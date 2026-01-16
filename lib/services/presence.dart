import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

final presenceServiceProvider = Provider<PresenceService>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) throw Exception("User not logged in");

  final service = PresenceService(uid: user.uid);
  service.start();

  ref.onDispose(() {
    service.dispose();
  });

  return service;
});

class PresenceService {
  final String uid;
  final DatabaseReference _statusRef;
  final DatabaseReference _connectedRef;
  StreamSubscription<DatabaseEvent>? _connectionSub;
  Timer? _lastSeenTimer;

  PresenceService({required this.uid})
    : _statusRef = FirebaseDatabase.instance.ref("status/$uid"),
      _connectedRef = FirebaseDatabase.instance.ref(".info/connected");

  void start() {
    _connectionSub = _connectedRef.onValue.listen((event) async {
      final isConnected = event.snapshot.value as bool? ?? false;
      if (!isConnected) return;

      await _statusRef.onDisconnect().set({
        "state": "offline",
        "stateInt": 0,
        "lastSeen": ServerValue.timestamp,
      });

      await _statusRef.set({
        "state": "online",
        "stateInt": 1,
        "lastSeen": ServerValue.timestamp,
      });

      _startLastSeenUpdater();
    });
  }

  void _startLastSeenUpdater() {
    _lastSeenTimer?.cancel();
    _lastSeenTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _statusRef.update({"lastSeen": ServerValue.timestamp});
    });
  }

  void dispose() {
    _connectionSub?.cancel();
    _lastSeenTimer?.cancel();
  }
}
