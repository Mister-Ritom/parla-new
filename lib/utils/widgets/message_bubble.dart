import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';
import 'package:heroicons/heroicons.dart';
import 'package:parla/models/message_model.dart';
import 'package:parla/services/color.dart';
import 'package:parla/utils/page_widgets/media_page.dart';
import 'package:parla/utils/formatter/file_formatter.dart';
import 'package:parla/utils/widgets/overlay_widget.dart';
import 'package:parla/utils/widgets/video_thumbnail.dart';
import 'package:video_player/video_player.dart';
import 'package:intl/intl.dart';

class MessageBubble extends StatelessWidget {
  final MessageModel message;
  final String currentUsername;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onReply;

  const MessageBubble({
    super.key,
    required this.message,
    required this.currentUsername,
    required this.onDelete,
    required this.onEdit,
    required this.onReply,
  });

  void _showBubbleOverlay(
    BuildContext context,
    LongPressStartDetails details,
    MessageModel message,
  ) {
    if (message.isDeleted) return;
    final overlayController = AnchoredOverlayController();

    final rect = Rect.fromLTWH(
      details.globalPosition.dx - 4,
      details.globalPosition.dy - 18,
      8,
      22,
    );

    overlayController.show(
      context: context,
      anchorRect: rect,
      child: MessageBubbleOverlay(
        onReply: onReply,
        onEdit: onEdit,
        onDelete: onDelete,
        isMe: message.senderUsername == currentUsername,
        controller: overlayController,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (message.type == MessageType.system) {
      return _SystemMessage(text: message.text ?? "System Event");
    }

    final isMe = message.senderUsername == currentUsername;
    final theme = context.theme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Text(
                message.senderUsername,
                style: theme.typography.xs.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: theme.colors.primary,
                ),
              ),
            ),
          Row(
            mainAxisAlignment: isMe
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // 1. We keep the max width constraint here (80% of screen)
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.80,
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    GestureDetector(
                      onLongPressStart: (details) {
                        HapticFeedback.mediumImpact();
                        _showBubbleOverlay(context, details, message);
                      },
                      child: _BubbleContainer(message: message, isMe: isMe),
                    ),

                    if (message.reactions != null &&
                        message.reactions!.isNotEmpty &&
                        !message.isDeleted)
                      Positioned(
                        bottom: -10,
                        right: isMe ? 0 : null,
                        left: isMe ? null : 0,
                        child: _ReactionCluster(
                          reactions: message.reactions!,
                          isMe: isMe,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (message.reactions != null && message.reactions!.isNotEmpty)
            const SizedBox(height: 12)
          else
            const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ... _SystemMessage remains the same ...
class _SystemMessage extends StatelessWidget {
  final String text;
  const _SystemMessage({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 24),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colors.secondary,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.colors.border),
        ),
        child: Text(
          text.toUpperCase(),
          style: theme.typography.xs.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: theme.colors.mutedForeground,
          ),
        ),
      ),
    );
  }
}

class _BubbleContainer extends StatelessWidget {
  final MessageModel message;
  final bool isMe;

  const _BubbleContainer({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    const violetPrimary = Color(0xFF7C3AED);

    final isDark = theme.colors.brightness == Brightness.dark;
    final bubbleColor = isMe
        ? violetPrimary
        : (isDark ? const Color(0xFF1F2937) : theme.colors.background);

    final textColor = isMe ? Colors.white : theme.colors.foreground;
    final metaColor = isMe
        ? Colors.white.opacityAlpha(0.7)
        : theme.colors.mutedForeground;

    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: isMe ? const Radius.circular(18) : Radius.zero,
      bottomRight: isMe ? Radius.zero : const Radius.circular(18),
    );

    // Check if we have visual media (Images/Videos)
    final hasMedia =
        message.files?.any(
          (f) =>
              f.mimeType.startsWith('image/') ||
              f.mimeType.startsWith('video/'),
        ) ??
        false;
    final hasVisualMedia =
        hasMedia && (message.status != MessageStatus.preview || isMe);

    String? replyToText;
    if (message.replyTo != null) {
      if (message.replyTo!.text == null || message.replyTo!.text!.isEmpty) {
        replyToText = "[Media]";
      } else {
        replyToText = message.replyTo!.text!;
      }
    }

    // BUILDER: The content of the bubble
    Widget bubbleContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (message.replyTo != null && replyToText != null)
          _ReplyPreview(text: replyToText, isMe: isMe, textColor: textColor),
        if (message.files != null &&
            message.files!.isNotEmpty &&
            !message.isDeleted)
          (message.status != MessageStatus.preview || isMe)
              ? _MediaAndDocsGrid(files: message.files!, isMe: isMe)
              : const SizedBox.shrink(),
        Padding(
          padding: const EdgeInsets.only(
            left: 12,
            right: 12,
            top: 8,
            bottom: 4,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.isDeleted)
                _DeletedPlaceholder(textColor: textColor)
              else if (message.ciphertext != null && message.text == null)
                _EncryptedPlaceholder(textColor: textColor)
              else if (message.text != null && message.text!.isNotEmpty)
                Text(
                  message.text!,
                  style: theme.typography.sm.copyWith(
                    color: textColor,
                    height: 1.5,
                  ),
                ),
              const SizedBox(height: 4),
              // Meta Row (Time, Status)
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // This spacer pushes time to right only if container is wide.
                  // In IntrinsicWidth, it does nothing effectively, which is fine.
                  if (hasVisualMedia) const Spacer(),

                  if (message.isEdited && !message.isDeleted) ...[
                    Text(
                      "EDITED",
                      style: theme.typography.xs.copyWith(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        color: metaColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    message.createdAt != null
                        ? DateFormat.jm().format(message.createdAt!)
                        : "",
                    style: theme.typography.xs.copyWith(
                      fontWeight: FontWeight.w600,
                      color: metaColor,
                      fontSize: 10,
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    _StatusIcon(status: message.status),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );

    // CRITICAL FIX:
    // If we have images, we DO NOT use IntrinsicWidth. We let the bubble
    // fill the parent constraints (80% screen) so images look big and nice.
    // If we have text only, we USE IntrinsicWidth so the bubble shrinks nicely.
    if (!hasVisualMedia) {
      bubbleContent = IntrinsicWidth(child: bubbleContent);
    }

    return Container(
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: borderRadius,
        border: isMe ? null : Border.all(color: theme.colors.border),
        boxShadow: [
          BoxShadow(
            color: isMe
                ? violetPrimary.opacityAlpha(0.15)
                : Colors.black.opacityAlpha(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      // We use Clip to ensure images adhere to bubble border radius
      clipBehavior: Clip.hardEdge,
      child: bubbleContent,
    );
  }
}

class MessageBubbleOverlay extends StatelessWidget {
  final VoidCallback onReply;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final AnchoredOverlayController controller;
  final bool isMe;

  const MessageBubbleOverlay({
    super.key,
    required this.onReply,
    required this.onEdit,
    required this.onDelete,
    required this.isMe,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _OverlayButton(
          icon: HeroIcons.arrowUturnLeft,
          label: 'Reply',
          onTap: onReply,
          controller: controller,
        ),
        SizedBox(height: 8),
        if (isMe) ...[
          _OverlayButton(
            icon: HeroIcons.pencil,
            label: 'Edit',
            onTap: onEdit,
            controller: controller,
          ),
          SizedBox(height: 4),
          _OverlayButton(
            icon: HeroIcons.trash,
            label: 'Delete',
            onTap: onDelete,
            controller: controller,
          ),
        ],
      ],
    );
  }
}

class _OverlayButton extends StatelessWidget {
  final HeroIcons icon;
  final String label;
  final VoidCallback onTap;
  final AnchoredOverlayController controller;

  const _OverlayButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return GestureDetector(
      onTap: () {
        controller.hide();
        onTap();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
        child: Row(
          children: [
            HeroIcon(icon, size: 16, color: theme.colors.foreground),
            const SizedBox(width: 4),
            Text(
              label,
              style: theme.typography.xs.copyWith(
                color: theme.colors.foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReplyPreview extends StatelessWidget {
  final String text;
  final bool isMe;
  final Color textColor;

  const _ReplyPreview({
    required this.text,
    required this.isMe,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final bgColor = isMe
        ? Colors.black.opacityAlpha(0.1)
        : theme.colors.secondary;
    final borderColor = isMe
        ? Colors.white.opacityAlpha(0.5)
        : theme.colors.primary;

    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: borderColor, width: 3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min, // Shrink to fit content
        children: [
          // Changed Expanded to Flexible so it doesn't force full width
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.xs.copyWith(
                fontStyle: FontStyle.italic,
                color: textColor.opacityAlpha(0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaAndDocsGrid extends StatelessWidget {
  final List<FileAttachment> files;
  final bool isMe;

  const _MediaAndDocsGrid({required this.files, required this.isMe});

  @override
  Widget build(BuildContext context) {
    // 1. Filter media types
    final visualMedia = files
        .where(
          (f) =>
              f.mimeType.startsWith('image/') ||
              f.mimeType.startsWith('video/'),
        )
        .toList();

    final documents = files
        .where(
          (f) =>
              !f.mimeType.startsWith('image/') &&
              !f.mimeType.startsWith('video/'),
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (visualMedia.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              // 2. Logic to handle single item vs Grid
              child: visualMedia.length > 1
                  ? GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 2,
                            mainAxisSpacing: 2,
                            childAspectRatio: 1.0,
                          ),
                      // Clamp count to 4 max
                      itemCount: visualMedia.length > 4
                          ? 4
                          : visualMedia.length,
                      itemBuilder: (ctx, idx) {
                        final file = visualMedia[idx];
                        final isOverflowTile =
                            idx == 3 && visualMedia.length > 4;

                        // Base content (Image or Video thumbnail)
                        Widget content = _MediaThumbnail(file: file);

                        // 3. If this is the 4th tile AND we have overflow
                        if (isOverflowTile) {
                          final remaining = visualMedia.length - 3;
                          return GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => MediaPage(files: visualMedia),
                                ),
                              );
                            },
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                content, // The image/video background
                                // Dark Overlay
                                Container(
                                  color: Colors.black.opacityAlpha(0.5),
                                ),
                                // The Counter Text
                                Center(
                                  child: Text(
                                    '+$remaining',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        // Normal Tile
                        return GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => MediaPage(files: [file]),
                              ),
                            );
                          },
                          child: content,
                        );
                      },
                    )
                  : ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxHeight: 300,
                        minWidth: 200,
                      ),
                      child: _MediaThumbnail(file: visualMedia.first),
                    ),
            ),
          ),

        // Document List Logic (Unchanged)
        if (documents.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Column(
              children: documents
                  .map((doc) => _DocumentTile(file: doc, isMe: isMe))
                  .toList(),
            ),
          ),
      ],
    );
  }
}

// ... _MediaThumbnail, _SimpleVideoPlayer, _DocumentTile, _ReactionCluster, _StatusIcon remain same ...
// Including _MediaThumbnail for context of the fix:

class _MediaThumbnail extends StatelessWidget {
  final FileAttachment file;
  const _MediaThumbnail({required this.file});

  @override
  Widget build(BuildContext context) {
    if (file.url == null && file.path == null) {
      throw Exception("FileAttachment must have either a URL or a local path.");
    }
    Widget content;
    if (file.mimeType.startsWith('video/')) {
      if (file.path != null) {
        content = VideoThumbnail.file(File(file.path!), aspectRatio: 1);
      } else {
        content = VideoThumbnail.network(file.url!, aspectRatio: 1);
      }
    } else {
      if (file.path != null) {
        content = Image.file(
          File(file.path!),
          fit: BoxFit.cover,
          width: double.infinity, // Force image to fill the grid cell/container
          height: double.infinity,
          errorBuilder: (ctx, err, stack) => Container(
            color: Colors.grey.shade300,
            child: const Center(
              child: HeroIcon(HeroIcons.photo, color: Colors.grey),
            ),
          ),
        );
      } else {
        content = Image.network(
          file.url!,
          fit: BoxFit.cover,
          width: double.infinity, // Force image to fill the grid cell/container
          height: double.infinity,
          loadingBuilder: (ctx, child, loading) => loading == null
              ? child
              : const Center(child: CircularProgressIndicator.adaptive()),
          errorBuilder: (ctx, err, stack) => Container(
            color: Colors.grey.shade300,
            child: const Center(
              child: HeroIcon(HeroIcons.photo, color: Colors.grey),
            ),
          ),
        );
      }
    }
    return Stack(children: [content, _indicatorIcon(file)]);
  }

  Widget _indicatorIcon(FileAttachment file) {
    if (file.path != null || file.url == null) {
      //A icon to indicate local file
      return Center(
        child: CircularProgressIndicator.adaptive(
          backgroundColor: Colors.white,
          strokeWidth: 3,
        ),
      );
    } else {
      return file.mimeType.startsWith('video/')
          ? Center(
              child: HeroIcon(
                HeroIcons.playCircle,
                size: 24,
                color: Colors.white,
              ),
            )
          : SizedBox.shrink();
    }
  }
}

// ... Rest of the file (_SimpleVideoPlayer, _DocumentTile, etc.) ...
// Just ensure you copy the _BubbleContainer logic primarily.
class _SimpleVideoPlayer extends StatefulWidget {
  final String url;
  const _SimpleVideoPlayer({required this.url});
  @override
  State<_SimpleVideoPlayer> createState() => _SimpleVideoPlayerState();
}

class _SimpleVideoPlayerState extends State<_SimpleVideoPlayer> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _controller == null || _controller!.value.isInitialized
      ? const Center(
          child: CircularProgressIndicator(backgroundColor: Colors.white),
        )
      : AspectRatio(
          aspectRatio: _controller!.value.aspectRatio,
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(_controller!),
              IconButton(
                onPressed: () {
                  if (_controller!.value.isPlaying) {
                    _controller!.pause();
                  } else {
                    _controller!.play();
                  }
                  setState(() {});
                },

                icon: Icon(
                  _controller!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        );
}

class _DocumentTile extends StatelessWidget {
  final FileAttachment file;
  final bool isMe;
  const _DocumentTile({required this.file, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final icon = FileFormatter.heroIconForMime(file.mimeType);
    final sizeStr = FileFormatter.formatBytes(file.size);

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isMe ? Colors.black.opacityAlpha(0.1) : theme.colors.secondary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: HeroIcon(icon, size: 20, color: theme.colors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.sm.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isMe ? Colors.white : theme.colors.foreground,
                  ),
                ),
                Text(
                  "${FileFormatter.fileTypeName(file.mimeType)} • $sizeStr",
                  style: theme.typography.xs.copyWith(
                    color: isMe
                        ? Colors.white.opacityAlpha(0.7)
                        : theme.colors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReactionCluster extends StatelessWidget {
  final Map<String, List<String>> reactions;
  final bool isMe;
  const _ReactionCluster({required this.reactions, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: reactions.entries.map((entry) {
        if (entry.value.isEmpty) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.only(right: 4),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: theme.colors.background,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.colors.border),
          ),
          child: Row(
            children: [
              Text(entry.key, style: const TextStyle(fontSize: 12)),
              if (entry.value.length > 1) ...[
                const SizedBox(width: 4),
                Text(
                  entry.value.length.toString(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: theme.colors.primary,
                  ),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _DeletedPlaceholder extends StatelessWidget {
  final Color textColor;
  const _DeletedPlaceholder({required this.textColor});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      HeroIcon(HeroIcons.trash, size: 14, color: textColor.opacityAlpha(0.6)),
      const SizedBox(width: 6),
      Text(
        "Message deleted",
        style: TextStyle(
          fontSize: 13,
          fontStyle: FontStyle.italic,
          color: textColor.opacityAlpha(0.6),
        ),
      ),
    ],
  );
}

class _EncryptedPlaceholder extends StatelessWidget {
  final Color textColor;
  const _EncryptedPlaceholder({required this.textColor});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      HeroIcon(
        HeroIcons.lockClosed,
        size: 14,
        color: textColor.opacityAlpha(0.6),
      ),
      const SizedBox(width: 6),
      Text(
        "Encrypted payload",
        style: TextStyle(
          fontSize: 13,
          fontStyle: FontStyle.italic,
          color: textColor.opacityAlpha(0.6),
        ),
      ),
    ],
  );
}

class _StatusIcon extends StatelessWidget {
  final MessageStatus status;
  const _StatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = status == MessageStatus.read ? Colors.white : Colors.white60;
    if (status == MessageStatus.sent) {
      return const HeroIcon(HeroIcons.check, size: 12, color: Colors.white38);
    }
    return Stack(
      children: [
        const HeroIcon(HeroIcons.check, size: 12, color: Colors.white60),
        Padding(
          padding: const EdgeInsets.only(left: 5),
          child: HeroIcon(HeroIcons.check, size: 12, color: color),
        ),
      ],
    );
  }
}
