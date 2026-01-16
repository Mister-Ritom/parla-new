import 'package:firebase_ui_firestore/firebase_ui_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:heroicons/heroicons.dart';
import 'package:parla/riverpod/curent_user_provider.dart';
import 'package:parla/services/firestore_service.dart';
import 'package:parla/utils/logger/app_logger.dart';
import 'package:parla/utils/widgets/convo.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _textController = TextEditingController();
  String _searchQuery = "";

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _setSearch() {
    setState(() {
      _searchQuery = _textController.text.trim();
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    if (currentUser == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [FCircularProgress(), Text("Getting user data")],
        ),
      );
    }

    return FScaffold(
      header: FHeader.nested(title: Text("Search")),
      footer: FTextField(
        controller: _textController,
        hint: "Search public communities",
        suffixBuilder: (context, style, states) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FButton.icon(
              onPress: _setSearch,
              style: FButtonStyle.ghost(),
              child: HeroIcon(HeroIcons.arrowUp),
            ),
          );
        },
      ),
      child: FirestoreListView(
        query: FirestoreService.getPublicConversationQuery(
          search: _searchQuery,
        ),
        errorBuilder: (context, error, stackTrace) {
          AppLogger.error(
            name: "SearchScreen",
            message: "Error when getting public conversations",
            exception: error,
            stackTrace: stackTrace,
          );
          return Center(child: Text("Something went wrong"));
        },
        emptyBuilder: (context) {
          return Center(child: Text("No cummunities found"));
        },
        itemBuilder: (context, snapshot) {
          final convo = snapshot.data();
          return ConversationListItem(
            conversation: convo,
            currentUsername: currentUser.username,
          );
        },
      ),
    );
  }
}
