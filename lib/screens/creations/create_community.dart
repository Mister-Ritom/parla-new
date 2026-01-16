import 'dart:io';

import 'package:firebase_ui_firestore/firebase_ui_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:image_picker/image_picker.dart';
import 'package:parla/models/conversation_model.dart';
import 'package:parla/models/user_model.dart';
import 'package:parla/riverpod/curent_user_provider.dart';
import 'package:parla/riverpod/storage_provider.dart';
import 'package:parla/screens/chat/chat_screen.dart';
import 'package:parla/services/firestore_service.dart';
import 'package:parla/utils/file_picker/media_utils.dart';

class CreateCommunityScreen extends ConsumerStatefulWidget {
  const CreateCommunityScreen({super.key});

  @override
  ConsumerState<CreateCommunityScreen> createState() =>
      _CreateCommunityScreenState();
}

class _CreateCommunityScreenState extends ConsumerState<CreateCommunityScreen> {
  final _titleController = TextEditingController();
  bool _loading = false;

  XFile? _pendingCoverPhoto;

  final List<UserModel> _selectedUsers = [];

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickCoverImage() async {
    final XFile? image = await MediaUtils.pickImageFromGallery();
    if (image != null) setState(() => _pendingCoverPhoto = image);
  }

  Future<void> _createCommunity() async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    setState(() {
      _loading = true;
    });

    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final users = [
      currentUser,
      ..._selectedUsers.where((u) => u.username != currentUser.username),
    ];

    final recipients = _buildRecipientMap(users, currentUser.username);

    if (_pendingCoverPhoto == null) {
      final convoId = await FirestoreService.createConversationDocument(
        recipients,
        currentUser.username,
        title: title,
      );
      if (!mounted || convoId == null) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ChatScreen(conversationId: convoId)),
      );
    }

    ref
        .read(fileUploadProvider.notifier)
        .uploadMultiple(
          files: [_pendingCoverPhoto!],
          path: "conversations/${currentUser.uid}",
          customFileNames: [
            "community_${DateTime.now().millisecondsSinceEpoch}",
          ],
          onAllUploadsComplete: (maps) async {
            final photoURL = maps.first["downloadUrl"] as String?;

            final convoId = await FirestoreService.createConversationDocument(
              recipients,
              currentUser.username,
              title: title,
              photoURL: photoURL,
            );

            if (!mounted) return;
            Navigator.pop(context, convoId);
          },
        );
  }

  Map<String, ConversationMap> _buildRecipientMap(
    List<UserModel> users,
    String currentUsername,
  ) {
    final map = <String, ConversationMap>{};

    for (final user in users) {
      map[user.username] = ConversationMap(
        username: user.username,
        uid: user.uid,
        publicKey: user.publicKey,
        role: user.username == currentUsername
            ? UserRole.admin
            : UserRole.memeber,
      );
    }

    return map;
  }

  void _toggleTempUser(String username) async {
    final exists = _selectedUsers.any((u) => u.username == username);

    if (exists) {
      _selectedUsers.removeWhere((u) => u.username == username);
    } else {
      final snap = await FirestoreService.getUserQuery(username).get();
      if (snap.docs.isEmpty) return;
      _selectedUsers.add(snap.docs.first.data());
    }

    setState(() {});
  }

  String _getOtherUser(List<String> recipients, String currentUsername) {
    return recipients.firstWhere(
      (s) => s.toLowerCase() != currentUsername.toLowerCase(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    if (currentUser == null) {
      return Center(child: Text("Not authtenticated"));
    }
    return FScaffold(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Create Community'),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _pickCoverImage,
              child: CircleAvatar(
                radius: 36,
                backgroundImage: _pendingCoverPhoto != null
                    ? FileImage(File(_pendingCoverPhoto!.path))
                    : null,
                child: _pendingCoverPhoto == null
                    ? const Icon(Icons.camera_alt)
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            FTextField(
              controller: _titleController,
              label: const Text('Community name'),
            ),
            const SizedBox(height: 24),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Add users'),
            ),
            const SizedBox(height: 8),
            FirestoreListView(
              query: FirestoreService.getUserConversationsQuery(
                currentUser.username,
              ),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, snapshot) {
                final convo = snapshot.data();
                final username = _getOtherUser(
                  convo.recipients,
                  currentUser.username,
                );
                final selected = _selectedUsers.any(
                  (u) => u.username == username,
                );
                return ListTile(
                  title: Text(username),
                  trailing: Icon(
                    selected ? Icons.check_circle : Icons.add_circle_outline,
                  ),
                  onTap: () => _toggleTempUser(username),
                );
              },
            ),
            const SizedBox(height: 24),
            const ListTile(
              leading: Icon(Icons.link),
              title: Text('Join via link'),
              subtitle: Text('Anyone with the link can join'),
            ),
            const SizedBox(height: 24),
            FButton(
              onPress: _loading ? null : _createCommunity,
              child: _loading
                  ? const FCircularProgress()
                  : const Text('Create Community'),
            ),
          ],
        ),
      ),
    );
  }
}
