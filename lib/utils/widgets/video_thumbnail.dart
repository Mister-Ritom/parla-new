import 'dart:io';
import 'package:flutter/material.dart';
import 'package:parla/utils/enums/source_type.dart';
import 'package:video_player/video_player.dart';

class VideoThumbnail extends StatefulWidget {
  final String dataSource;
  final MediaSourceType type;
  final double? aspectRatio;
  final Function(VideoPlayerController controller)? onControllerReady;

  // Private constructor
  const VideoThumbnail._({
    required this.dataSource,
    required this.type,
    this.onControllerReady,
    this.aspectRatio,
  });

  // Factory for Network
  factory VideoThumbnail.network(String url, {double? aspectRatio}) {
    return VideoThumbnail._(
      dataSource: url,
      type: MediaSourceType.network,
      aspectRatio: aspectRatio,
    );
  }

  // Factory for File
  factory VideoThumbnail.file(File file, {double? aspectRatio}) {
    return VideoThumbnail._(
      dataSource: file.path,
      type: MediaSourceType.file,
      aspectRatio: aspectRatio,
    );
  }

  // Factory for Asset
  factory VideoThumbnail.asset(String path, {double? aspectRatio}) {
    return VideoThumbnail._(
      dataSource: path,
      type: MediaSourceType.asset,
      aspectRatio: aspectRatio,
    );
  }

  @override
  State<VideoThumbnail> createState() => _VideoThumbnailState();
}

class _VideoThumbnailState extends State<VideoThumbnail> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  void _initializeController() {
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

    _controller.initialize().then((_) {
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        // Ensure we are at the start of the video
        _controller.seekTo(Duration.zero);
      }
      widget.onControllerReady?.call(_controller);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    return AspectRatio(
      aspectRatio: widget.aspectRatio ?? _controller.value.aspectRatio,
      child: VideoPlayer(_controller),
    );
  }
}
