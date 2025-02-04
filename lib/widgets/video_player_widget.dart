import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/video.dart';
import '../services/video_service.dart';

class VideoPlayerWidget extends StatefulWidget {
  final Video video;
  final bool autoPlay;
  final bool shouldInitialize;

  const VideoPlayerWidget({
    super.key,
    required this.video,
    this.autoPlay = true,
    this.shouldInitialize = true,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasViewBeenCounted = false;
  final _videoService = VideoService();

  @override
  void initState() {
    super.initState();
    if (widget.shouldInitialize) {
      _initializeVideo();
    }
  }

  @override
  void didUpdateWidget(VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.shouldInitialize != oldWidget.shouldInitialize) {
      if (widget.shouldInitialize) {
        _initializeVideo();
      } else {
        _disposeController();
      }
    }
    
    if (_controller != null && widget.autoPlay != oldWidget.autoPlay) {
      if (widget.autoPlay) {
        _controller?.play();
      } else {
        _controller?.pause();
      }
    }
  }

  Future<void> _initializeVideo() async {
    if (_controller != null) return;

    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.video.videoUrl),
    );

    try {
      await _controller?.initialize();
      if (_controller != null) {
        _controller!.setLooping(true);
        _controller!.addListener(_videoListener);
        if (widget.autoPlay && mounted) {
          _controller!.play();
        }
        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
        }
      }
    } catch (e) {
      print('Error initializing video: $e');
      _disposeController();
    }
  }

  void _videoListener() {
    if (_controller == null || !_controller!.value.isPlaying || _hasViewBeenCounted) {
      return;
    }

    // Count view as soon as the video starts playing
    _countView();
  }

  Future<void> _countView() async {
    if (!_hasViewBeenCounted) {
      _hasViewBeenCounted = true;
      await _videoService.incrementViews(widget.video.id);
    }
  }

  void _disposeController() {
    _controller?.pause();
    _controller?.dispose();
    _controller = null;
    if (mounted) {
      setState(() {
        _isInitialized = false;
      });
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_videoListener);
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.shouldInitialize) {
      return Container(
        color: Colors.black,
        child: widget.video.thumbnailUrl != null
            ? Image.network(
                widget.video.thumbnailUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Icon(
                      Icons.image_not_supported,
                      color: Colors.white54,
                      size: 48,
                    ),
                  );
                },
              )
            : const Center(
                child: Icon(
                  Icons.video_library,
                  color: Colors.white54,
                  size: 48,
                ),
              ),
      );
    }

    if (!_isInitialized || _controller == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          if (_controller!.value.isPlaying) {
            _controller!.pause();
          } else {
            _controller!.play();
          }
        });
      },
      child: AspectRatio(
        aspectRatio: _controller!.value.aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: [
            VideoPlayer(_controller!),
            if (!_controller!.value.isPlaying)
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                ),
                child: const Icon(
                  Icons.play_arrow,
                  size: 64,
                  color: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }
} 