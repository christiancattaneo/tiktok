import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/video.dart';
import '../services/video_service.dart';

class VideoPlayerWidget extends StatefulWidget {
  final Video video;
  final bool autoPlay;
  final bool shouldInitialize;
  final BoxFit fit;

  const VideoPlayerWidget({
    super.key,
    required this.video,
    this.autoPlay = true,
    this.shouldInitialize = true,
    this.fit = BoxFit.contain,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasViewBeenCounted = false;
  String? _errorMessage;
  final _videoService = VideoService();
  ImageProvider? _thumbnailImage;

  @override
  void initState() {
    super.initState();
    if (widget.shouldInitialize) {
      _initializeVideo();
    } else {
      _loadThumbnail();
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

    setState(() {
      _errorMessage = null;
    });

    try {
      print('Initializing video from URL: ${widget.video.videoUrl}');
      
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.video.videoUrl),
      );

      // Add error listener before initialization
      _controller!.addListener(() {
        final error = _controller!.value.errorDescription;
        if (error != null && error.isNotEmpty) {
          print('Video player error: $error');
          if (mounted) {
            setState(() {
              _errorMessage = 'Video playback error: $error';
            });
          }
        }
      });

      await _controller?.initialize();
      
      if (_controller != null) {
        print('Video initialized successfully');
        print('Video duration: ${_controller!.value.duration}');
        print('Video size: ${_controller!.value.size}');
        
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
    } catch (e, stackTrace) {
      print('Error initializing video: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load video: ${e.toString()}';
          _isInitialized = false;
        });
      }
      _disposeController();
    }
  }

  Future<void> _loadThumbnail() async {
    if (widget.video.thumbnailUrl != null && widget.video.thumbnailUrl!.isNotEmpty) {
      setState(() {
        _thumbnailImage = NetworkImage(widget.video.thumbnailUrl!);
      });
    } else {
      // For videos without thumbnails, show a placeholder with video duration
      setState(() {
        _isInitialized = false;
        _thumbnailImage = null;
      });

      // Initialize video just to get metadata if needed
      final tempController = VideoPlayerController.networkUrl(
        Uri.parse(widget.video.videoUrl),
      );
      try {
        await tempController.initialize();
        if (mounted) {
          setState(() {
            _controller = tempController;
            _isInitialized = true;
          });
        }
      } catch (e) {
        print('Error loading video metadata: $e');
        await tempController.dispose();
      }
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
        child: _controller != null && _isInitialized
            ? Center(
                child: SizedBox.expand(
                  child: FittedBox(
                    fit: widget.fit,
                    child: SizedBox(
                      width: _controller!.value.size.width,
                      height: _controller!.value.size.height,
                      child: VideoPlayer(_controller!),
                    ),
                  ),
                ),
              )
            : _thumbnailImage != null
                ? Image(
                    image: _thumbnailImage!,
                    fit: widget.fit,
                    width: double.infinity,
                    height: double.infinity,
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

    if (_errorMessage != null) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _initializeVideo,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!_isInitialized || _controller == null) {
      return Container(
        color: Colors.black,
        child: _thumbnailImage != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image(
                    image: _thumbnailImage!,
                    fit: widget.fit,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                  const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ],
              )
            : const Center(
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
      child: Container(
        color: Colors.black,
        child: Center(
          child: SizedBox.expand(
            child: FittedBox(
              fit: widget.fit,
              child: SizedBox(
                width: _controller!.value.size.width,
                height: _controller!.value.size.height,
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
            ),
          ),
        ),
      ),
    );
  }
} 