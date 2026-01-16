import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';
import 'package:parla/services/color.dart';

enum ChatMenuAction {
  photos("Photos", HeroIcons.photo, [Color(0xFF8B5CF6), Color(0xFF6366F1)]),
  camera("Camera", HeroIcons.camera, [Color(0xFF3B82F6), Color(0xFF0EA5E9)]),
  location("Location", HeroIcons.mapPin, [
    Color(0xFF10B981),
    Color(0xFF059669),
  ]),
  contact("Contact", HeroIcons.user, [Color(0xFFF59E0B), Color(0xFFD97706)]),
  document("Document", HeroIcons.documentText, [
    Color(0xFFEF4444),
    Color(0xFFDC2626),
  ]),
  poll("Poll", HeroIcons.chartBar, [Color(0xFFEC4899), Color(0xFFDB2777)]),
  voice("Voice", HeroIcons.microphone, []),
  quick("Quick", HeroIcons.bolt, []),
  sticker("Sticker", HeroIcons.faceSmile, []);

  final String label;
  final HeroIcons icon;
  final List<Color> gradient;

  const ChatMenuAction(this.label, this.icon, this.gradient);
}

class AdvancedChatInput extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback? onSendPressed;
  final VoidCallback? onCameraPressed;
  final Function(ChatMenuAction action)? onMenuAction;

  const AdvancedChatInput({
    super.key,
    required this.controller,
    this.onSendPressed,
    this.onCameraPressed,
    this.onMenuAction,
  });

  @override
  State<AdvancedChatInput> createState() => _AdvancedChatInputState();
}

class _AdvancedChatInputState extends State<AdvancedChatInput>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _menuScaleAnimation;
  late Animation<double> _barWidthAnimation;
  late Animation<double> _rotationAnimation;

  bool _isOpen = false;
  bool _isTyping = false;
  OverlayEntry? _overlayEntry; // 1. Add OverlayEntry reference
  final LayerLink _layerLink = LayerLink(); // 2. Add LayerLink to anchor menu

  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      reverseDuration: const Duration(milliseconds: 300),
    );

    _menuScaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeIn,
    );

    _barWidthAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOutCubic,
    );

    _rotationAnimation = Tween<double>(begin: 0, end: 3 * math.pi / 4).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOutBack),
    );
  }

  void _onTextChanged() {
    final hasText = widget.controller.text.trim().isNotEmpty;
    if (_isTyping != hasText) {
      setState(() {
        _isTyping = hasText;
      });
    }
  }

  @override
  void dispose() {
    // 3. Clean up overlay on dispose
    _removeOverlay();
    widget.controller.removeListener(_onTextChanged);
    _animController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // 4. Create and Insert Overlay
  void _showOverlay() {
    if (_overlayEntry != null) return;

    final overlayState = Overlay.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            // 1. Backdrop
            Positioned.fill(
              child: GestureDetector(
                onTap: _toggleMenu,
                behavior: HitTestBehavior.opaque,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 200),
                  builder: (context, value, child) {
                    return Container(
                      color: (isDark ? Colors.black : Colors.white)
                          .opacityAlpha(0.6 * value),
                    );
                  },
                ),
              ),
            ),

            // 2. Menu Grid (Positioned Relative to Input)
            Positioned(
              width: size.width, // Match the width of the input bar
              child: CompositedTransformFollower(
                link: _layerLink,
                showWhenUnlinked: false,
                // THIS IS THE FIX:
                // Anchor the "Bottom Left" of the Menu...
                followerAnchor: Alignment.bottomLeft,
                // ...to the "Top Left" of the Input Bar.
                targetAnchor: Alignment.topLeft,
                // Add a small gap (negative Y moves it UP)
                offset: const Offset(0, -12),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      // Prevent menu from going off top of screen
                      maxHeight: MediaQuery.of(context).size.height - 150,
                    ),
                    child: ScaleTransition(
                      scale: _menuScaleAnimation,
                      alignment: Alignment.bottomLeft,
                      child: Material(
                        type: MaterialType.transparency,
                        child: _buildMenuGrid(isDark),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    overlayState.insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _toggleMenu() async {
    if (_isOpen) {
      // Close
      await _animController.reverse();
      _removeOverlay();
      _focusNode.requestFocus();
    } else {
      // Open
      _focusNode.unfocus();
      _showOverlay(); // Insert overlay first
      _animController.forward();
    }

    if (mounted) {
      setState(() {
        _isOpen = !_isOpen;
      });
    }
  }

  void _handleSend() {
    if (widget.onSendPressed != null) {
      widget.onSendPressed!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    // 5. Wrap the root in CompositedTransformTarget
    return CompositedTransformTarget(
      link: _layerLink,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          // REMOVED: Internal Backdrop & Menu Grid (Now in Overlay)

          // The Full Width Input Bar
          AnimatedBuilder(
            animation: _animController,
            builder: (context, child) {
              final double slideOffset = 56.0 * _barWidthAnimation.value;
              final double currentWidth = screenWidth - slideOffset;

              return Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomLeft,
                children: [
                  // A. The Background Container
                  Transform.translate(
                    offset: Offset(slideOffset, 0),
                    child: Container(
                      width: currentWidth,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF121212) : Colors.white,
                        border: Border(
                          top: BorderSide(
                            color: isDark
                                ? Colors.grey[800]!
                                : Colors.grey[200]!,
                            width: 1,
                          ),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.opacityAlpha(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          SizedBox(width: 48 * (1 - _barWidthAnimation.value)),
                          Expanded(
                            child: TextField(
                              controller: widget.controller,
                              focusNode: _focusNode,
                              // enabled: !_isOpen, // KEEP ENABLED so context menu works if needed, usually better UX
                              maxLines: 5,
                              minLines: 1,
                              style: TextStyle(
                                fontSize: 16,
                                color: isDark ? Colors.white : Colors.grey[800],
                              ),
                              decoration: InputDecoration(
                                hintText: _isOpen
                                    ? "Choose an option..."
                                    : "Message...",
                                hintStyle: TextStyle(
                                  color: isDark
                                      ? Colors.grey[500]
                                      : Colors.grey[400],
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildCameraButton(isDark),
                                const SizedBox(width: 4),
                                _buildSendButton(isDark),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // B. The Arrow / Menu Trigger Button
                  Positioned(
                    left: 0,
                    bottom: 0,
                    child: GestureDetector(
                      onTap: _toggleMenu,
                      child: Transform.rotate(
                        angle: _rotationAnimation.value,
                        child: Container(
                          width: 48,
                          height: 48,
                          margin: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Color.lerp(
                              Colors.transparent,
                              isDark ? Colors.grey[700] : Colors.grey[200],
                              _barWidthAnimation.value,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: HeroIcon(
                              HeroIcons.arrowUp,
                              style: HeroIconStyle.solid,
                              size: 24,
                              color: isDark ? Colors.white : Colors.grey[700],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ... keep _buildCameraButton, _buildSendButton, _buildMenuGrid, _buildMiniAction, _MenuActionButton exactly as they were ...
  // (Just make sure _buildMenuGrid and helpers are inside the class)
  // --- Sub-Widgets ---

  Widget _buildCameraButton(bool isDark) {
    final bool showCamera = !_isTyping && !_isOpen;

    return AnimatedScale(
      scale: showCamera ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: showCamera
          ? SizedBox(
              width: 40,
              child: IconButton(
                onPressed: widget.onCameraPressed,
                icon: HeroIcon(
                  HeroIcons.camera,
                  style: HeroIconStyle.outline,
                  size: 24,
                  color: isDark ? Colors.grey[400] : Colors.grey[500],
                ),
                splashRadius: 20,
              ),
            )
          : const SizedBox(width: 0),
    );
  }

  Widget _buildSendButton(bool isDark) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: _isTyping
            ? const Color(0xFF4F46E5) // Indigo 600
            : (isDark ? Colors.grey[800] : Colors.grey[100]),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: HeroIcon(
          HeroIcons.paperAirplane,
          style: HeroIconStyle.solid,
          size: 20,
          color: _isTyping
              ? Colors.white
              : (isDark ? Colors.grey[500] : Colors.grey[400]),
        ),
        onPressed: (_isTyping) ? _handleSend : null,
      ),
    );
  }

  Widget _buildMenuGrid(bool isDark) {
    // Only use the actions that belong in the main grid
    final gridActions = [
      ChatMenuAction.photos,
      ChatMenuAction.camera,
      ChatMenuAction.location,
      ChatMenuAction.contact,
      ChatMenuAction.document,
      ChatMenuAction.poll,
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: (isDark ? const Color(0xFF1F2937) : Colors.white).opacityAlpha(
          0.9,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.opacityAlpha(0.1)
              : Colors.white.opacityAlpha(0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.opacityAlpha(0.1),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 20,
              childAspectRatio: 0.85,
            ),
            itemCount: gridActions.length,
            itemBuilder: (context, index) {
              final action = gridActions[index];
              final animation = CurvedAnimation(
                parent: _animController,
                curve: Interval(
                  index * 0.1,
                  (index * 0.1 + 0.4).clamp(0.0, 1.0),
                  curve: Curves.elasticOut,
                ),
              );

              return ScaleTransition(
                scale: animation,
                child: FadeTransition(
                  opacity: animation,
                  child: _MenuActionButton(
                    action: action,
                    isDark: isDark,
                    onTap: () async {
                      _toggleMenu();
                      widget.onMenuAction?.call(action);
                    },
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          Divider(color: isDark ? Colors.grey[700] : Colors.grey[200]),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMiniAction(ChatMenuAction.voice, isDark),
              _buildMiniAction(ChatMenuAction.quick, isDark),
              _buildMiniAction(ChatMenuAction.sticker, isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniAction(ChatMenuAction action, bool isDark) {
    return GestureDetector(
      onTap: () {
        _toggleMenu();
        widget.onMenuAction?.call(action);
      },
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[700] : Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: HeroIcon(
              action.icon, // Accessing icon from Enum
              size: 20,
              color: isDark ? Colors.grey[300] : Colors.grey[600],
              style: HeroIconStyle.mini,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            action.label, // Accessing label from Enum
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.grey[400] : Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuActionButton extends StatelessWidget {
  final ChatMenuAction action;
  final bool isDark;
  final VoidCallback onTap;

  const _MenuActionButton({
    required this.action,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: action.gradient, // Accessing gradient from Enum
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: action.gradient.last.opacityAlpha(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: HeroIcon(action.icon, color: Colors.white, size: 26),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            action.label, // Accessing label from Enum
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
