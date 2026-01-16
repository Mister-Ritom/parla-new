import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:parla/models/conversation_model.dart';
import 'package:parla/models/user_model.dart';
import 'package:parla/riverpod/curent_user_provider.dart';
import 'package:parla/screens/chat/chat_screen.dart';
import 'package:parla/services/firestore_service.dart';
import 'package:parla/utils/logger/app_logger.dart';

class AddContact extends ConsumerStatefulWidget {
  const AddContact({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() {
    return _AddContactState();
  }
}

class _AddContactState extends ConsumerState<AddContact> {
  final _usernameController = TextEditingController();
  final _keyController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  void _createChat() async {
    final username = _usernameController.text.trim();
    final currentUser = ref.read(currentUserProvider);
    final key = _keyController.text.trim();

    if (!_validateCurrentUser(currentUser)) return;

    final valid = await FirestoreService.isKeyValid(
      key,
      username,
      currentUser!.username,
    );

    if (!valid) return;

    final users = await _loadUsers([currentUser.username, username]);
    if (users.isEmpty) return;

    final recipients = _buildRecipientMap(users);

    final convoId = await FirestoreService.createConversationDocument(
      recipients,
      currentUser.username,
    );

    if (!mounted || !context.mounted) return;
    if (convoId == null) {
      Navigator.pop(context);
      return;
    }

    _openChat(convoId);
  }

  bool _validateCurrentUser(UserModel? user) {
    if (user == null) {
      AppLogger.warn(
        name: "AddContact screen",
        message: 'Current user is null,returning...',
      );
      return false;
    }
    return true;
  }

  Future<List<UserModel>> _loadUsers(List<String> usernames) async {
    final List<UserModel> users = [];

    for (final name in usernames) {
      final snap = await FirestoreService.getUserQuery(name).get();
      if (snap.docs.isEmpty) return [];
      users.add(snap.docs.first.data());
    }

    return users;
  }

  Map<String, ConversationMap> _buildRecipientMap(List<UserModel> users) {
    final map = <String, ConversationMap>{};

    for (final user in users) {
      map[user.username] = ConversationMap(
        username: user.username,
        uid: user.uid,
        publicKey: user.publicKey,
        role: UserRole.admin,
      );
    }

    return map;
  }

  void _openChat(String convoId) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => ChatScreen(conversationId: convoId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return FCircularProgress();
    }
    return SafeArea(
      child: AnimatedPadding(
        duration: Duration(milliseconds: 180),
        padding: EdgeInsets.only(
          bottom: bottom + 36,
        ), // 👈 pushes sheet above keyboard
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Add Contact'),
              SizedBox(height: 12),
              FTextField(
                controller: _usernameController,
                label: Text("Contact username"),
              ),
              SizedBox(height: 8),
              FTextField(
                controller: _keyController,
                label: Text("Contact ShareKey"),
              ),
              SizedBox(height: 24),
              FButton(onPress: _createChat, child: Text("Add Contact")),
            ],
          ),
        ),
      ),
    );
  }
}
