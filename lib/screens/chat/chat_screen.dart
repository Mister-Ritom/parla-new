import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:firebase_ui_firestore/firebase_ui_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:heroicons/heroicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:parla/models/conversation_model.dart';
import 'package:parla/models/message_model.dart';
import 'package:parla/models/user_model.dart';
import 'package:parla/riverpod/curent_user_provider.dart';
import 'package:parla/riverpod/storage_provider.dart';
import 'package:parla/screens/navigation_child/profile_screen.dart';
import 'package:parla/services/firestore_service.dart';
import 'package:parla/utils/encryption/encryption_util.dart';
import 'package:parla/utils/encryption/key_generator.dart';
import 'package:parla/utils/file_picker/media_utils.dart';
import 'package:parla/utils/formatter/file_formatter.dart';
import 'package:parla/utils/formatter/time_formatter.dart';
import 'package:parla/utils/logger/app_logger.dart';
import 'package:parla/utils/overlay/overlay_util.dart';
import 'package:parla/utils/page_widgets/camera_view.dart';
import 'package:parla/utils/widgets/chat_input.dart';
import 'package:parla/utils/widgets/cycling_text.dart';
import 'package:parla/utils/widgets/message_bubble.dart';
import 'package:parla/utils/widgets/status.dart';
import 'package:parla/utils/widgets/swipe.dart';
import 'package:parla/utils/widgets/video_thumbnail.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String conversationId;
  const ChatScreen({super.key, required this.conversationId});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() {
    return _ChatScreenState();
  }
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _textController = TextEditingController();
  SimpleKeyPair? _privateKey;
  final _scrollController = ScrollController();

  final _uploadedFilesProvider = StateProvider<List<FileAttachment>>(
    (ref) => [],
  );
  final _replyingToProvider = StateProvider<MessageModel?>((ref) => null);
  final _editingProvider = StateProvider<MessageModel?>((ref) => null);

  @override
  void initState() {
    super.initState();
    _loadPrivateKey();
  }

  void _startReply(MessageModel msg) {
    if (ref.watch(_editingProvider) != null) {
      return; // Can't replt while editing
    }
    ref.read(_replyingToProvider.notifier).state = msg;
  }

  void _clearReply() {
    ref.read(_replyingToProvider.notifier).state = null;
  }

  void _startEdit(MessageModel message) {
    if (ref.watch(_replyingToProvider) != null) {
      return; // Can't edit while replying
    }
    ref.read(_editingProvider.notifier).state = message;
    _textController.text = message.text ?? "";
  }

  void _clearEdit() {
    ref.read(_editingProvider.notifier).state = null;
    _textController.text = "";
  }

  Future<void> _loadPrivateKey() async {
    final key = await KeyGenerator.getKey();
    if (!mounted) return;
    if (key == null) {
      AppLogger.error(name: "ChatScreen", message: "No private key found");
    }
    setState(() {
      _privateKey = key;
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Widget getChatHeader(ConversationModel convo, String currentUsername) {
    if (convo.recipients.length == 2) {
      final otherUsername = getOtherUser(convo.recipients, currentUsername);
      return FirestoreQueryBuilder<UserModel>(
        query: FirestoreService.getUserQuery(otherUsername),
        builder: (context, snapshot, _) {
          if (snapshot.isFetching) return FProgress();
          if (snapshot.hasError || snapshot.docs.isEmpty) {
            AppLogger.error(
              name: "Chat screen",
              message: "Getting user data failed $otherUsername",
              exception: snapshot.error,
              stackTrace: snapshot.stackTrace,
            );
            return Text("Something went wrong");
          }
          final user = snapshot.docs[0].data();
          final title = convo.title ?? user.displayName;
          final photoURL = convo.photoURL ?? user.photoURL;
          return header(title, photoURL, uid: user.uid, bio: user.bio);
        },
      );
    } else {
      final title = convo.title ?? "${convo.recipients.length} Users";
      return header(title, convo.photoURL, convoId: convo.id);
    }
  }

  String getOtherUser(List<String> recipients, String currentUsername) {
    return recipients.firstWhere(
      (s) => s.toLowerCase() != currentUsername.toLowerCase(),
    );
  }

  Widget header(
    String title,
    String? photoURL, {
    String? uid,
    String? bio,
    String? convoId,
  }) {
    // If uid is null → fallback to normal header
    if (uid == null) {
      return FHeader.nested(
        prefixes: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: HeroIcon(HeroIcons.chevronLeft),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: FAvatar(
              image: NetworkImage(photoURL ?? ''),
              fallback: Text(title.substring(0, 2)),
            ),
          ),
        ],
        title: InkWell(
          onTap: () {
            if (convoId != null) {
              // TODO: go to convo screen
            }
          },
          child: Text(title),
        ),
        titleAlignment: Alignment.centerLeft,
        suffixes: [
          IconButton(onPressed: () {}, icon: HeroIcon(HeroIcons.videoCamera)),
          IconButton(onPressed: () {}, icon: HeroIcon(HeroIcons.phone)),
        ],
      );
    }

    // If uid is provided → wrap header in a single OnlineStatusWidget
    return OnlineStatusWidget(
      uid: uid,
      itemBuilder: (context, status, state, lastSeen) {
        final lastSeenDate = DateTime.fromMillisecondsSinceEpoch(lastSeen);
        final aboutItems = [
          "Last seen: ${TimeFormatter.timeAgo(lastSeenDate)}",
          status == 0 ? "Online" : "Offline",
          bio ?? "",
        ];

        return FHeader.nested(
          prefixes: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: HeroIcon(HeroIcons.chevronLeft),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Stack(
                children: [
                  FAvatar(
                    image: NetworkImage(photoURL ?? ''),
                    fallback: Text(title.substring(0, 2)),
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
              ),
            ),
          ],
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ProfileScreen(uid: uid)),
                  );
                },
                child: Text(title),
              ),
              const SizedBox(height: 2),
              CyclingText(items: aboutItems),
            ],
          ),
          titleAlignment: Alignment.centerLeft,
          suffixes: [
            IconButton(onPressed: () {}, icon: HeroIcon(HeroIcons.videoCamera)),
            IconButton(onPressed: () {}, icon: HeroIcon(HeroIcons.phone)),
          ],
        );
      },
    );
  }

  Future<void> _sendMessage(
    ConversationModel convo,
    String currentUsername,
  ) async {
    if (_privateKey == null) return;
    final text = _textController.text.trim();
    final editing = ref.read(_editingProvider);

    if (editing != null) {
      if (text.isEmpty) {
        _clearEdit();
        return;
      }
      FirestoreService.updateMessageDocumentText(
        oldModel: editing,
        conversation: convo,
        newText: text,
        senderPrivateKey: _privateKey!,
      );
      _clearEdit();
      return;
    }

    // Capture current files before clearing the provider
    final localFiles = ref.read(_uploadedFilesProvider);
    final replyTo = ref.read(_replyingToProvider);

    if (localFiles.isEmpty && text.isEmpty) return;

    // Clear UI immediately for optimistic feeling
    _textController.clear();
    ref.read(_uploadedFilesProvider.notifier).state = [];

    // 1. Create the initial document
    // If we have files, this is a PREVIEW. If no files, it is SENT.
    final bool hasFiles = localFiles.isNotEmpty;

    final String? messageId = await FirestoreService.createMessageDocument(
      conversation: convo,
      senderUsername: currentUsername,
      messageString: text,
      files: localFiles, // These contain local paths initially
      senderPrivateKey: _privateKey!,
      isPreview: hasFiles, // true if files exist, false otherwise
      replyTo: replyTo,
    );

    if (messageId == null) {
      OverlayUtil.showTopOverlay("Failed to send message");
      return;
    }

    _clearReply();

    // 2. If we have files, handle upload and update
    if (hasFiles) {
      final fileObjects = localFiles.map((f) => File(f.path!)).toList();

      // Use the fileUploadProvider notifier logic
      ref
          .read(fileUploadProvider.notifier)
          .uploadMultiple(
            files: fileObjects,
            path: "chat_media/${convo.id}/$messageId", // Organized path
            customFileNames: localFiles.map((e) => e.name).toList(),
            onAllUploadsComplete: (maps) async {
              // 3. Map the Uploaded URLs back to FileAttachment objects
              // We assume the order of 'urls' matches the order of 'localFiles'
              List<FileAttachment> uploadedAttachments = [];
              for (int i = 0; i < localFiles.length; i++) {
                final map = maps[i];
                final url = map["downloadUrl"];
                final size = map["size"];
                final name = map["name"];
                if (i < maps.length) {
                  uploadedAttachments.add(
                    localFiles[i].copyWith(
                      url: url,
                      size: size,
                      name: name,
                      path: null,
                      pathNull: true, // Clear local path now that we have URL
                    ),
                  );
                }
              }

              // 4. Update the document with URLs and set status to SENT
              await FirestoreService.updateMessageDocument(
                messageId: messageId,
                files: uploadedAttachments,
              );
            },
          );
    }
  }

  Widget bubble(String decrypted, MessageModel msg, String currentUsername) {
    final message = msg.copyWith(text: decrypted);
    final isMe = msg.senderUsername == currentUsername;

    return SwipeToReply(
      isMe: isMe,
      onReply: () => _startReply(message),
      child: Column(
        children: [
          MessageBubble(
            message: message,
            currentUsername: currentUsername,
            onDelete: () async {
              final shouldDelete = await showDialog<bool>(
                context: context,
                barrierDismissible: true,
                builder: (context) {
                  return AlertDialog(
                    title: const Text("Delete message?"),
                    content: const Text(
                      "This message will be marked as deleted for everyone.",
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text("Cancel"),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text(
                          "Delete",
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  );
                },
              );

              if (shouldDelete == true) {
                await FirestoreService.deleteMessageDocument(
                  messageId: message.id,
                );
              }
            },

            onEdit: () => _startEdit(message),
            onReply: () => _startReply(message),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Future<String> _decryptMessage(MessageModel msg) async {
    if (_privateKey == null) return "[no key]";
    if (msg.ciphertext == null ||
        msg.nonce == null ||
        msg.mac == null ||
        msg.wrappedKeys == null ||
        msg.ephemeralPublicKey == null) {
      return msg.text ?? "";
    }

    try {
      final pub = SimplePublicKey(
        base64Decode(msg.ephemeralPublicKey!),
        type: KeyPairType.x25519,
      );

      final decrypted = await EncryptionUtil.decryptMessage(
        payload: {
          "ciphertext": msg.ciphertext,
          "nonce": msg.nonce,
          "mac": msg.mac,
          "wrappedKeys": msg.wrappedKeys,
        },
        recipientPrivateKey: _privateKey!,
        senderEphemeralPublicKey: pub,
        recipientUid: ref.read(currentUserProvider)!.uid,
      );

      return decrypted ?? "[decrypt failed]";
    } catch (_) {
      return "[decrypt failed]";
    }
  }

  Widget filePreview(FileAttachment f) {
    if (f.path == null) {
      return SizedBox.shrink();
    }
    final file = File(f.path!);
    if (f.mimeType.startsWith("image/")) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(file, width: 100, height: 100, fit: BoxFit.cover),
      );
    }

    if (f.mimeType.startsWith("video/")) {
      return SizedBox(
        width: 120,
        height: 120,
        child: VideoThumbnail.file(file),
      );
    }

    return Container(
      padding: const EdgeInsets.all(8),
      width: 120,
      height: 50,
      child: Column(
        children: [
          FItem(
            title: HeroIcon(FileFormatter.heroIconForMime(f.mimeType)),
            subtitle: Text(f.name),
          ),
        ],
      ),
    );
  }

  int remainingSlots() {
    final existing = ref.read(_uploadedFilesProvider.notifier).state;
    final existingCount = existing.length;

    // 1. Immediate exit if already at limit
    if (existingCount >= 10) {
      OverlayUtil.showTopOverlay("Maximum 10 files allowed");
      return 0;
    }
    final remainingSlots = 10 - existingCount;
    return remainingSlots;
  }

  void _addFiles(List<XFile>? files) {
    if (files == null || files.isEmpty) return;
    final existing = ref.read(_uploadedFilesProvider.notifier).state;
    final fileAttachments = files.map(
      (f) => FileFormatter.attachmentFromXFile(f),
    );
    ref.read(_uploadedFilesProvider.notifier).state = [
      ...existing,
      ...fileAttachments,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);

    if (currentUser == null || _privateKey == null) {
      return Center(child: CircularProgressIndicator());
    }

    return FirestoreQueryBuilder(
      query: FirestoreService.getConversationQuery(widget.conversationId),
      builder: (context, snapshot, _) {
        if (snapshot.isFetching) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError || snapshot.docs.isEmpty) {
          AppLogger.error(
            name: "Chat Screen",
            message: "Couldn't get conversation ${widget.conversationId}",
            exception: snapshot.error,
            stackTrace: snapshot.stackTrace,
          );
          return SizedBox.shrink();
        }

        final convo = snapshot.docs[0].data();

        return Scaffold(
          body: FScaffold(
            resizeToAvoidBottomInset: true,
            scaffoldStyle: (style) => style.copyWith(
              footerDecoration: style.footerDecoration.copyWith(
                border: Border(
                  top: BorderSide(
                    color: FTheme.of(context).colors.mutedForeground,
                    width: 0.2,
                  ),
                ),
              ),
            ),
            header: getChatHeader(convo, currentUser.username),

            footer: Consumer(
              builder: (context, ref, _) {
                final uploadedFiles = ref.watch(_uploadedFilesProvider);
                final replyingTo = ref.watch(_replyingToProvider);
                final editing = ref.watch(_editingProvider);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (uploadedFiles.isNotEmpty)
                        SizedBox(
                          height: 120,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: uploadedFiles.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (_, i) =>
                                  filePreview(uploadedFiles[i]),
                            ),
                          ),
                        ),
                      if (editing != null)
                        Container(
                          padding: const EdgeInsets.all(8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Editing message"),
                              IconButton(
                                onPressed: _clearEdit,
                                icon: const HeroIcon(HeroIcons.xMark),
                              ),
                            ],
                          ),
                        ),
                      if (replyingTo != null)
                        Container(
                          padding: const EdgeInsets.all(8),

                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      replyingTo.senderUsername,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      (replyingTo.text != null &&
                                              replyingTo.text!.isNotEmpty)
                                          ? replyingTo.text!
                                          : "[media]",
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: _clearReply,
                                icon: const HeroIcon(HeroIcons.xMark),
                              ),
                            ],
                          ),
                        ),

                      AdvancedChatInput(
                        controller: _textController,
                        onSendPressed: () async {
                          await _sendMessage(convo, currentUser.username);
                        },
                        onCameraPressed: () async {
                          final List<XFile>? files = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  CameraView(limit: remainingSlots()),
                            ),
                          );
                          _addFiles(files);
                        },
                        onMenuAction: (action) async {
                          log("something new $action");
                          List<XFile>? files;
                          switch (action) {
                            case ChatMenuAction.photos:
                              files =
                                  await MediaUtils.pickMultiMediaFromFileSystem();
                              break;

                            case ChatMenuAction.camera:
                              files =
                                  await MediaUtils.pickMultiMediaFromGallery(
                                    limit: remainingSlots(),
                                  );
                              break;

                            case ChatMenuAction.document:
                              files = await MediaUtils.pickMultiDocuments();
                              break;

                            default:
                              //TODO other actions
                              return;
                          }
                          _addFiles(files);
                        },
                      ),
                    ],
                  ),
                );
              },
            ),

            child: FirestoreListView<MessageModel>(
              padding: EdgeInsets.zero,
              reverse: true,
              controller: _scrollController,
              query: FirestoreService.getMessagesQueryDesc(
                widget.conversationId,
              ),
              errorBuilder: (context, error, stackTrace) {
                AppLogger.error(
                  name: "Chat Screen",
                  message: "Couldn't get messages for ${widget.conversationId}",
                  exception: error,
                  stackTrace: stackTrace,
                );
                return Text("Something went wrong");
              },
              itemBuilder: (context, doc) {
                final msg = doc.data();
                // if user deletes a message the text changes to [deleted]
                if (msg.text != null && msg.text!.isNotEmpty) {
                  return bubble(msg.text!, msg, currentUser.username);
                }
                return FutureBuilder<String>(
                  future: _decryptMessage(msg),
                  builder: (context, snap) {
                    final text = snap.data ?? "[decrypting]";

                    // Decrypt replyTo if it exists
                    if (msg.replyTo != null) {
                      return FutureBuilder<String>(
                        future: _decryptMessage(msg.replyTo!),
                        builder: (context, replySnap) {
                          final decryptedReply =
                              replySnap.data ?? "[decrypting]";
                          final decryptedMsg = msg.copyWith(
                            text: text,
                            replyTo: msg.replyTo!.copyWith(
                              text: decryptedReply,
                            ),
                          );
                          return bubble(
                            decryptedMsg.text ?? "",
                            decryptedMsg,
                            currentUser.username,
                          );
                        },
                      );
                    } else {
                      return bubble(text, msg, currentUser.username);
                    }
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }
}
