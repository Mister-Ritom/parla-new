import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:parla/services/color.dart';
import 'package:parla/utils/enums/source_type.dart';
import 'package:parla/utils/widgets/simple_video.dart';
import 'package:video_player/video_player.dart';

import 'package:heroicons/heroicons.dart';

// Import your custom player file
// import 'simple_video_player.dart';

class VideoPage extends StatefulWidget {
  final String dataSource;
  final MediaSourceType sourceType;
  final String? videoTitle;

  const VideoPage({
    super.key,
    required this.dataSource,
    required this.sourceType,
    this.videoTitle,
  });

  @override
  State<VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<VideoPage> {
  VideoPlayerController? _controller;

  // State variables for UI
  bool _showControls = true;
  bool _isPlaying = false;
  bool _isLandscape = false;

  // Time tracking
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  // Auto-hide timer
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    // Hide system UI for immersive experience initially
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    // Reset Orientation and System UI when leaving the page
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    _hideTimer?.cancel();
    super.dispose();
  }

  // --- Logic Helpers ---

  void _onControllerReady(VideoPlayerController controller) {
    _controller = controller;
    _totalDuration = controller.value.duration;

    // Listen to updates for the slider
    controller.addListener(_videoListener);

    // 1. Determine initial orientation based on aspect ratio
    // If width > height (e.g. 16:9), force landscape.
    if (controller.value.aspectRatio > 1.0) {
      _toggleOrientation(forceLandscape: true);
    }

    setState(() {
      _isPlaying = controller.value.isPlaying;
    });

    _startHideTimer();
  }

  void _videoListener() {
    if (_controller == null) return;

    // Sync UI state with controller state
    final bool isPlaying = _controller!.value.isPlaying;
    final Duration position = _controller!.value.position;

    if (isPlaying != _isPlaying ||
        position.inSeconds != _currentPosition.inSeconds) {
      setState(() {
        _isPlaying = isPlaying;
        _currentPosition = position;
        // Keep total duration updated (sometimes it loads async)
        _totalDuration = _controller!.value.duration;
      });
    }
  }

  void _togglePlayPause() {
    if (_controller == null) return;
    if (_controller!.value.isPlaying) {
      _controller!.pause();
      _showControls = true; // Keep controls visible when paused
      _hideTimer?.cancel();
    } else {
      _controller!.play();
      _startHideTimer();
    }
    setState(() {});
  }

  void _seekRelative(int seconds) {
    if (_controller == null) return;
    final newPos = _controller!.value.position + Duration(seconds: seconds);
    _controller!.seekTo(newPos);
    _startHideTimer(); // Reset timer on interaction
  }

  void _seekTo(double value) {
    if (_controller == null) return;
    _controller!.seekTo(Duration(seconds: value.toInt()));
    _startHideTimer();
  }

  void _toggleOrientation({bool? forceLandscape}) {
    if (forceLandscape != null) {
      _isLandscape = forceLandscape;
    } else {
      _isLandscape = !_isLandscape;
    }

    if (_isLandscape) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
    setState(() {});
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls && _isPlaying) {
      _startHideTimer();
    } else {
      _hideTimer?.cancel();
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _isPlaying) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  // --- UI Building Blocks ---

  @override
  Widget build(BuildContext context) {
    // Determine the SimpleVideoPlayer factory based on type
    Widget playerWidget;
    switch (widget.sourceType) {
      case MediaSourceType.network:
        playerWidget = SimpleVideoPlayer.network(
          widget.dataSource,
          onControllerReady: _onControllerReady,
          autoPlay: true,
        );
        break;
      case MediaSourceType.file:
        playerWidget = SimpleVideoPlayer.file(
          File(widget.dataSource),
          onControllerReady: _onControllerReady,
          autoPlay: true,
        );
        break;
      case MediaSourceType.asset:
        playerWidget = SimpleVideoPlayer.asset(
          widget.dataSource,
          onControllerReady: _onControllerReady,
          autoPlay: true,
        );
        break;
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 1. The Video Layer
            Center(child: playerWidget),

            // 2. The Dark Overlay (for contrast)
            if (_showControls) Container(color: Colors.black.opacityAlpha(0.4)),

            // 3. The Controls UI
            AnimatedOpacity(
              opacity: _showControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: IgnorePointer(
                ignoring: !_showControls,
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildTopBar(context),
                      _buildCenterControls(),
                      _buildBottomBar(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const HeroIcon(
              HeroIcons.xMark,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          if (widget.videoTitle != null)
            Expanded(
              child: Text(
                widget.videoTitle!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          // Placeholder for "More options" or settings
          const HeroIcon(HeroIcons.ellipsisVertical, color: Colors.white),
        ],
      ),
    );
  }

  Widget _buildCenterControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Rewind 10s
        IconButton(
          onPressed: () => _seekRelative(-10),
          icon: const HeroIcon(
            HeroIcons.backward,
            color: Colors.white,
            size: 32,
          ),
        ),
        const SizedBox(width: 40),

        // Play / Pause (Large)
        GestureDetector(
          onTap: _togglePlayPause,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.opacityAlpha(0.5),
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(16),
            child: HeroIcon(
              _isPlaying ? HeroIcons.pause : HeroIcons.play,
              style: HeroIconStyle.solid,
              color: Colors.white,
              size: 48,
            ),
          ),
        ),

        const SizedBox(width: 40),

        // Forward 10s
        IconButton(
          onPressed: () => _seekRelative(10),
          icon: const HeroIcon(
            HeroIcons.forward,
            color: Colors.white,
            size: 32,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black.opacityAlpha(0.8), Colors.transparent],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                _formatDuration(_currentPosition),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const Spacer(),
              Text(
                _formatDuration(_totalDuration),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                // Using FSlider from ForUI if available, otherwise standard Slider
                // Here simulating standard slider styled to look like custom UI
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: Colors.redAccent,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: Colors.redAccent,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                    trackHeight: 2,
                  ),
                  child: Slider(
                    value: _currentPosition.inSeconds.toDouble().clamp(
                      0.0,
                      _totalDuration.inSeconds.toDouble(),
                    ),
                    min: 0.0,
                    max: _totalDuration.inSeconds.toDouble(),
                    onChanged: (v) {
                      // Optional: Pause while dragging
                      _startHideTimer(); // Prevent hide while dragging
                    },
                    onChangeEnd: (v) => _seekTo(v),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => _toggleOrientation(),
                child: const HeroIcon(
                  HeroIcons.arrowsPointingOut,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
