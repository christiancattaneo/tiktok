import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../models/video.dart';
import '../services/video_service.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class VideoPlayerWidget extends StatefulWidget {
  final Video video;
  final bool autoPlay;
  final bool shouldInitialize;
  final BoxFit fit;
  final bool preloadOnly;

  const VideoPlayerWidget({
    super.key,
    required this.video,
    this.autoPlay = true,
    this.shouldInitialize = true,
    this.fit = BoxFit.contain,
    this.preloadOnly = false,
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
  
  // Custom cache configuration
  static const int _maxCacheSize = 500 * 1024 * 1024; // 500MB
  static const Duration _maxAge = Duration(hours: 1);
  static final _videoCache = DefaultCacheManager();
  
  // Keep track of preloaded videos
  static final Map<String, bool> _preloadedVideos = {};

  @override
  void initState() {
    super.initState();
    if (widget.shouldInitialize) {
      if (widget.preloadOnly) {
        _preloadVideo();
      } else {
        _initializeVideo();
      }
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

  Future<void> _preloadVideo() async {
    if (_preloadedVideos[widget.video.id] == true) return;

    try {
      // Only preload first 5 seconds
      final videoFile = await _videoCache.getSingleFile(
        widget.video.videoUrl,
        key: '${widget.video.id}_preload',
      );
      
      if (!mounted) return;

      // Initialize controller just to verify the file
      final tempController = VideoPlayerController.file(videoFile);
      await tempController.initialize();
      
      // Mark as preloaded
      _preloadedVideos[widget.video.id] = true;
      
      // Clean up
      await tempController.dispose();
      
      print('Preloaded video: ${widget.video.id}');
    } catch (e) {
      print('Error preloading video: $e');
    }
  }

  Future<void> _cleanupOldCache() async {
    try {
      final cacheDir = await getTemporaryDirectory();
      final videoCacheDir = Directory('${cacheDir.path}/libCachedVideoPlayer');
      if (await videoCacheDir.exists()) {
        final files = await videoCacheDir.list().toList();
        int totalSize = 0;
        for (var file in files) {
          if (file is File) {
            totalSize += await file.length();
          }
        }
        
        // If cache exceeds max size, clear old files
        if (totalSize > _maxCacheSize) {
          print('Cache size exceeded, cleaning up old files');
          await _videoCache.emptyCache();
        }
      }
    } catch (e) {
      print('Error cleaning cache: $e');
    }
  }

  Future<void> _initializeVideo() async {
    if (_controller != null) return;

    setState(() {
      _errorMessage = null;
    });

    try {
      await _cleanupOldCache();
      
      print('Initializing video: ${widget.video.id}');
      
      // Try to get from cache first
      final cacheKey = widget.video.id;
      final fileInfo = await _videoCache.getFileFromCache(cacheKey);
      
      File videoFile;
      if (fileInfo != null) {
        print('Using cached video: ${widget.video.id}');
        videoFile = fileInfo.file;
      } else {
        print('Downloading video: ${widget.video.id}');
        videoFile = await _videoCache.getSingleFile(
          widget.video.videoUrl,
          key: cacheKey,
        );
      }

      if (!mounted) return;

      _controller = VideoPlayerController.file(videoFile);

      _controller!.addListener(() {
        if (!mounted) return;
        
        final error = _controller!.value.errorDescription;
        if (error != null && error.isNotEmpty) {
          print('Video player error: $error');
          setState(() {
            _errorMessage = 'Video playback error: $error';
          });
        }
      });

      await _controller!.initialize();
      
      if (!mounted) return;

      _controller!.setLooping(true);
      _controller!.addListener(_videoListener);
      
      setState(() {
        _isInitialized = true;
        if (widget.autoPlay) {
          _controller!.play();
        }
      });
      
      // Remove preload version if it exists
      _videoCache.removeFile('${widget.video.id}_preload');
      
    } catch (e, stackTrace) {
      print('Error initializing video: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load video: ${e.toString()}';
          _isInitialized = false;
        });
        _disposeController();
      }
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