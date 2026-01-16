import 'package:firebase_ui_firestore/firebase_ui_firestore.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:parla/models/conversation_model.dart';
import 'package:parla/models/user_model.dart';
import 'package:parla/screens/chat/chat_screen.dart';
import 'package:parla/services/firestore_service.dart';
import 'package:parla/utils/formatter/time_formatter.dart';
import 'package:parla/utils/logger/app_logger.dart';
import 'package:parla/utils/widgets/status.dart';

class ConversationListItem extends StatelessWidget {
  final ConversationModel conversation;
  final String currentUsername;

  const ConversationListItem({
    super.key,
    required this.conversation,
    required this.currentUsername,
  });

  @override
  Widget build(BuildContext context) {
    if (conversation.recipients.length == 2) {
      final otherUsername = _getOtherUser(
        conversation.recipients,
        currentUsername,
      );

      return FirestoreQueryBuilder<UserModel>(
        query: FirestoreService.getUserQuery(otherUsername),
        builder: (context, snapshot, _) {
          if (snapshot.isFetching) {
            return FProgress();
          }

          if (snapshot.hasError || snapshot.docs.isEmpty) {
            AppLogger.error(
              name: "Conversation screen",
              message: "Getting user data failed for user $otherUsername",
              exception: snapshot.error,
              stackTrace: snapshot.stackTrace,
            );
            return Text("Something went wrong");
          }

          final user = snapshot.docs.first.data();
          final title = conversation.title ?? user.displayName;
          final photoURL = conversation.photoURL ?? user.photoURL;

          return _tile(context, title, photoURL, uid: user.uid);
        },
      );
    }

    final title =
        conversation.title ?? "${conversation.recipients.length} Users";

    return _tile(context, title, conversation.photoURL);
  }

  String _getOtherUser(List<String> recipients, String currentUsername) {
    return recipients.firstWhere(
      (s) => s.toLowerCase() != currentUsername.toLowerCase(),
    );
  }

  FTile _tile(
    BuildContext context,
    String title,
    String? photoURL, {
    String? uid,
  }) {
    Widget avatar = FAvatar(
      image: NetworkImage(photoURL ?? ''),
      fallback: Text(title.substring(0, 1).toUpperCase()),
    );

    // If uid is provided, wrap the avatar with OnlineStatusWidget to show badge
    if (uid != null) {
      avatar = OnlineStatusWidget(
        uid: uid,
        itemBuilder: (context, status, state, lastSeen) {
          return Stack(
            children: [
              FAvatar(
                image: NetworkImage(photoURL ?? ''),
                fallback: Text(title.substring(0, 1).toUpperCase()),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: status == 0 ? Colors.green : Colors.grey,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          );
        },
      );
    }
    return FTile(
      style: (style) => style.copyWith(
        margin: EdgeInsets.zero,
        decoration: style.decoration.map(
          (d) => d?.copyWith(border: Border.all(style: BorderStyle.none)),
        ),
      ),
      prefix: avatar,
      title: Text(title, style: FTheme.of(context).typography.xl),
      subtitle: conversation.lastMessage != null
          ? Text(conversation.lastMessage!)
          : null,
      details: conversation.lastMessageAt != null
          ? SizedBox(
              width: 80,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(TimeFormatter.timeAgo(conversation.lastMessageAt!)),
                  SizedBox(height: 8),
                  if (conversation.unreadCount != 0)
                    Badge(
                      label: Text(conversation.unreadCount.toString()),
                      backgroundColor: FTheme.of(context).colors.primary,
                    ),
                ],
              ),
            )
          : null,
      onPress: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(conversationId: conversation.id),
          ),
        );
      },
    );
  }
}
