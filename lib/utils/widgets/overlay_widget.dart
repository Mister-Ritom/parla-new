import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:parla/services/color.dart';

class AnchoredOverlayController {
  OverlayEntry? _entry;

  void show({
    required BuildContext context,
    required Rect anchorRect,
    required Widget child,
  }) {
    if (_entry != null) return;

    final overlay = Overlay.of(context);

    _entry = OverlayEntry(
      builder: (_) {
        return _AnchoredOverlay(
          anchorRect: anchorRect,
          onDismiss: hide,
          child: child,
        );
      },
    );

    overlay.insert(_entry!);
  }

  void hide() {
    _entry?.remove();
    _entry = null;
  }
}

class _AnchoredOverlay extends StatelessWidget {
  final Rect anchorRect;
  final Widget child;
  final VoidCallback onDismiss;

  const _AnchoredOverlay({
    required this.anchorRect,
    required this.child,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onTap: onDismiss,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(color: Colors.black.opacityAlpha(0.25)),
          ),
        ),
        Positioned.fromRect(
          rect: anchorRect.inflate(4),
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.transparent,
              ),
            ),
          ),
        ),
        _OverlayCard(anchorRect: anchorRect, child: child),
      ],
    );
  }
}

class _OverlayCard extends StatefulWidget {
  final Rect anchorRect;
  final Widget child;

  const _OverlayCard({required this.anchorRect, required this.child});

  @override
  State<_OverlayCard> createState() => _OverlayCardState();
}

class _OverlayCardState extends State<_OverlayCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  )..forward();

  double _overlayHeight = 0;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final screen = media.size;
    final padding = media.padding;

    const gap = 10.0;

    final spaceBelow =
        screen.height - padding.bottom - widget.anchorRect.bottom;

    final canShowBelow =
        _overlayHeight > 0 && spaceBelow >= _overlayHeight + gap;

    final double top = _overlayHeight == 0
        ? widget.anchorRect.top
        : canShowBelow
        ? widget.anchorRect.bottom + gap
        : (widget.anchorRect.top - _overlayHeight - gap).clamp(
            padding.top + 8,
            double.infinity,
          );

    final left = (widget.anchorRect.center.dx - 140).clamp(
      16.0,
      screen.width - 296,
    );

    return Positioned(
      top: top,
      left: left,
      child: FadeTransition(
        opacity: CurvedAnimation(parent: _controller, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: Tween(begin: 0.96, end: 1.0).animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeOut),
          ),
          child: Material(
            color: Colors.transparent,
            child: _MeasureSize(
              onChange: (size) {
                if (_overlayHeight != size.height) {
                  setState(() {
                    _overlayHeight = size.height;
                  });
                }
              },
              child: Container(
                width: 280,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: Theme.of(context).cardColor,
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                      color: Colors.black.opacityAlpha(0.25),
                    ),
                  ],
                ),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MeasureSize extends StatefulWidget {
  final Widget child;
  final ValueChanged<Size> onChange;

  const _MeasureSize({required this.child, required this.onChange});

  @override
  State<_MeasureSize> createState() => _MeasureSizeState();
}

class _MeasureSizeState extends State<_MeasureSize> {
  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final box = context.findRenderObject() as RenderBox?;
      if (box != null) {
        widget.onChange(box.size);
      }
    });
    return widget.child;
  }
}
