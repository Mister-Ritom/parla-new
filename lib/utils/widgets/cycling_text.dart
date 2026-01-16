import 'dart:async';
import 'package:flutter/material.dart';

class CyclingText extends StatefulWidget {
  final List<String> items;
  final Duration interval;

  const CyclingText({
    super.key,
    required this.items,
    this.interval = const Duration(seconds: 3),
  });

  @override
  State<CyclingText> createState() => _CyclingTextState();
}

class _CyclingTextState extends State<CyclingText> {
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.items.length > 1) {
      _timer = Timer.periodic(widget.interval, (_) {
        setState(() {
          _index = (_index + 1) % widget.items.length;
        });
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      transitionBuilder: (child, animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      switchInCurve: Curves.easeIn,
      switchOutCurve: Curves.easeOut,
      layoutBuilder: (currentChild, previousChildren) {
        // Prevent first-child centering by always aligning top-left
        return Align(alignment: Alignment.centerLeft, child: currentChild);
      },
      child: Text(
        widget.items[_index],
        key: ValueKey<int>(_index),
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
    );
  }
}
