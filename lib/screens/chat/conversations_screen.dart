import 'package:firebase_ui_firestore/firebase_ui_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:parla/models/conversation_model.dart';
import 'package:parla/riverpod/curent_user_provider.dart';
import 'package:parla/services/firestore_service.dart';
import 'package:parla/utils/widgets/convo.dart';

class ConversationsList extends ConsumerWidget {
  const ConversationsList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);

    if (currentUser == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [FCircularProgress(), Text("Gettng user data")],
        ),
      );
    }

    return FirestoreListView<ConversationModel>(
      query: FirestoreService.getUserConversationsQuery(currentUser.username),
      padding: EdgeInsets.zero,
      emptyBuilder: (context) => Center(child: Text('No Chats yet')),
      itemBuilder: (context, doc) {
        return ConversationListItem(
          conversation: doc.data(),
          currentUsername: currentUser.username,
        );
      },
    );
  }
}
