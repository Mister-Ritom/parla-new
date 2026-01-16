import 'dart:io';
import 'package:flutter/material.dart';
import 'package:parla/utils/enums/source_type.dart';
import 'package:video_player/video_player.dart';

class SimpleVideoPlayer extends StatefulWidget {
  final String dataSource;
  final MediaSourceType type;
  final bool autoPlay;
  final bool looping;
  final bool showLoader;

  /// Optional: Override aspect ratio. If null, uses video's native ratio.
  final double? aspectRatio;

  /// Callback returning the controller once initialized.
  /// Use this to build your custom UI (play/pause buttons, sliders, etc.)
  final Function(VideoPlayerController controller)? onControllerReady;

  // Private constructor
  const SimpleVideoPlayer._({
    super.key,
    required this.dataSource,
    required this.type,
    this.autoPlay = true,
    this.looping = false,
    this.showLoader = true,
    this.aspectRatio,
    this.onControllerReady,
  });

  // --- Factories ---

  factory SimpleVideoPlayer.network(
    String url, {
    Key? key,
    bool autoPlay = true,
    bool looping = false,
    bool showLoader = true,
    double? aspectRatio,
    Function(VideoPlayerController)? onControllerReady,
  }) {
    return SimpleVideoPlayer._(
      key: key,
      dataSource: url,
      type: MediaSourceType.network,
      autoPlay: autoPlay,
      looping: looping,
      showLoader: showLoader,
      aspectRatio: aspectRatio,
      onControllerReady: onControllerReady,
    );
  }

  factory SimpleVideoPlayer.file(
    File file, {
    Key? key,
    bool autoPlay = true,
    bool looping = false,
    bool showLoader = true,
    double? aspectRatio,
    Function(VideoPlayerController)? onControllerReady,
  }) {
    return SimpleVideoPlayer._(
      key: key,
      dataSource: file.path,
      type: MediaSourceType.file,
      autoPlay: autoPlay,
      looping: looping,
      showLoader: showLoader,
      aspectRatio: aspectRatio,
      onControllerReady: onControllerReady,
    );
  }

  factory SimpleVideoPlayer.asset(
    String path, {
    Key? key,
    bool autoPlay = true,
    bool looping = false,
    bool showLoader = true,
    double? aspectRatio,
    Function(VideoPlayerController)? onControllerReady,
  }) {
    return SimpleVideoPlayer._(
      key: key,
      dataSource: path,
      type: MediaSourceType.asset,
      autoPlay: autoPlay,
      looping: looping,
      showLoader: showLoader,
      aspectRatio: aspectRatio,
      onControllerReady: onControllerReady,
    );
  }

  @override
  State<SimpleVideoPlayer> createState() => _SimpleVideoPlayerState();
}

class _SimpleVideoPlayerState extends State<SimpleVideoPlayer> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  // This is crucial for a Player: checks if the video source changed
  @override
  void didUpdateWidget(SimpleVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dataSource != widget.dataSource ||
        oldWidget.type != widget.type) {
      _disposeController();
      _initializeController();
    }
  }

  Future<void> _initializeController() async {
    setState(() {
      _isInitialized = false;
      _hasError = false;
    });

    try {
      switch (widget.type) {
        case MediaSourceType.network:
          _controller = VideoPlayerController.networkUrl(
            Uri.parse(widget.dataSource),
          );
          break;
        case MediaSourceType.file:
          _controller = VideoPlayerController.file(File(widget.dataSource));
          break;
        case MediaSourceType.asset:
          _controller = VideoPlayerController.asset(widget.dataSource);
          break;
      }

      await _controller!.initialize();

      if (widget.looping) await _controller!.setLooping(true);
      if (widget.autoPlay) await _controller!.play();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        // Pass the controller back to the parent for custom UI handling
        widget.onControllerReady?.call(_controller!);
      }
    } catch (e) {
      debugPrint("Error initializing video: $e");
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  void _disposeController() {
    _controller?.dispose();
    _controller = null;
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return const Center(child: Icon(Icons.error, color: Colors.red));
    }

    if (!_isInitialized || _controller == null) {
      return widget.showLoader
          ? const Center(child: CircularProgressIndicator.adaptive())
          : const SizedBox.shrink();
    }

    return AspectRatio(
      aspectRatio: widget.aspectRatio ?? _controller!.value.aspectRatio,
      child: VideoPlayer(_controller!),
    );
  }
}
