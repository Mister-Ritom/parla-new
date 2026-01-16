import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:heroicons/heroicons.dart';

class SwipeToReply extends StatefulWidget {
  final Widget child;
  final bool isMe;
  final VoidCallback onReply;

  const SwipeToReply({
    super.key,
    required this.child,
    required this.isMe,
    required this.onReply,
  });

  @override
  State<SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<SwipeToReply>
    with SingleTickerProviderStateMixin {
  static const double _maxDrag = 80;
  static const double _triggerFraction = 0.6;
  static const double _velocityTrigger = 700;

  late AnimationController _controller;
  late Animation<double> _animation;

  double _dx = 0;
  bool _hapticFired = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
  }

  void _fireHaptic() {
    if (_hapticFired) return;
    HapticFeedback.mediumImpact();
    _hapticFired = true;
  }

  void _animateBack() {
    _animation =
        Tween<double>(begin: _dx, end: 0).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
        )..addListener(() {
          setState(() {
            _dx = _animation.value;
          });
        });

    _controller
      ..reset()
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_dx.abs() / _maxDrag).clamp(0.0, 1.0);

    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        final delta = details.delta.dx;

        if (widget.isMe && delta < 0) {
          _dx = max(_dx + delta, -_maxDrag);
        } else if (!widget.isMe && delta > 0) {
          _dx = min(_dx + delta, _maxDrag);
        }

        if (_dx.abs() > _maxDrag * _triggerFraction) {
          _fireHaptic();
        }

        setState(() {});
      },
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;

        final velocityTriggered = widget.isMe
            ? velocity < -_velocityTrigger
            : velocity > _velocityTrigger;

        if (_dx.abs() >= _maxDrag * _triggerFraction || velocityTriggered) {
          widget.onReply();
        }

        _hapticFired = false;
        _animateBack();
      },
      child: Stack(
        alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
        children: [
          Positioned(
            left: widget.isMe ? null : 16,
            right: widget.isMe ? 16 : null,
            child: Opacity(
              opacity: progress,
              child: Transform.translate(
                offset: Offset(widget.isMe ? 10 : -10, 0),
                child: HeroIcon(
                  widget.isMe
                      ? HeroIcons.arrowUturnRight
                      : HeroIcons.arrowUturnLeft,
                  size: 20,
                ),
              ),
            ),
          ),
          Transform.translate(offset: Offset(_dx, 0), child: widget.child),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
