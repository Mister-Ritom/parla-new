import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

typedef StatusItemBuilder =
    Widget Function(
      BuildContext context,
      int status,
      String state,
      int lastSeen,
    );

class OnlineStatusWidget extends StatelessWidget {
  final String uid;
  final StatusItemBuilder itemBuilder;
  final Widget Function(BuildContext context)? loadingBuilder;
  final Widget Function(BuildContext context, Object error, StackTrace stack)?
  errorBuilder;

  const OnlineStatusWidget({
    super.key,
    required this.uid,
    required this.itemBuilder,
    this.loadingBuilder,
    this.errorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseDatabase.instance.ref("status/$uid");

    return StreamBuilder<DatabaseEvent>(
      stream: ref.onValue,
      builder: (context, snapshot) {
        // Error handling
        if (snapshot.hasError) {
          if (errorBuilder != null) {
            return errorBuilder!(
              context,
              snapshot.error!,
              snapshot.stackTrace ?? StackTrace.current,
            );
          }
          return const SizedBox.shrink();
        }

        // Loading state
        if (!snapshot.hasData) {
          if (loadingBuilder != null) {
            return loadingBuilder!(context);
          }
          return const SizedBox.shrink();
        }

        final data = snapshot.data?.snapshot.value as Map<dynamic, dynamic>?;

        // Node doesn't exist → treat as offline
        final state = data?["state"] as String? ?? "offline";
        final lastSeen = data?["lastSeen"] as int? ?? 0;
        final status = state == "online" ? 0 : 1;

        return itemBuilder(context, status, state, lastSeen);
      },
    );
  }
}
