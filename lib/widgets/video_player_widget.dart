import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:provider/provider.dart';
import '../models/video.dart';
import '../services/video_service.dart';
import '../providers/video_provider.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:async';

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final String videoId;
  final bool isPaused;
  final bool shouldPreload;

  const VideoPlayerWidget({
    Key? key,
    required this.videoUrl,
    required this.videoId,
    required this.isPaused,
    this.shouldPreload = false,
  }) : super(key: key);

  @override
  _VideoPlayerWidgetState createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _isDisposed = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  Future<void> _initializeController() async {
    print('📱 Initializing controller for video: ${widget.videoId}');
    _controller = VideoPlayerController.network(
      widget.videoUrl,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    
    try {
      await _controller.initialize();
      if (!_isDisposed && mounted) {
        setState(() {
          _isInitialized = true;
          _hasError = false;
        });
        
        _controller.setLooping(true);
        
        // If this is a preload widget, we don't want to play or set as active
        if (!widget.shouldPreload) {
          if (!widget.isPaused) {
            _controller.play();
            // Set as active video only if we're actually playing
            context.read<VideoProvider>().setActiveVideo(_controller, widget.videoId);
          }
        }
      }
    } catch (e) {
      print('📱 Error initializing video controller: $e');
      if (!_isDisposed && mounted) {
        setState(() {
          _isInitialized = false;
          _hasError = true;
        });
      }
    }
  }

  Future<void> _disposeController() async {
    print('📱 Disposing controller for video: ${widget.videoId}');
    
    if (_controller.value.isPlaying) {
      await _controller.pause();
    }
    
    if (mounted && !widget.shouldPreload) {
      try {
        final videoProvider = Provider.of<VideoProvider>(context, listen: false);
        if (videoProvider.activeVideoId == widget.videoId) {
          videoProvider.clearActiveVideo();
        }
      } catch (e) {
        print('📱 Error clearing active video during disposal: $e');
      }
    }
    
    await _controller.dispose();
    print('📱 Controller disposed for video: ${widget.videoId}');
  }

  @override
  void dispose() {
    print('📱 Disposing VideoPlayerWidget for video: ${widget.videoId}');
    _isDisposed = true;
    _disposeController();
    super.dispose();
  }

  @override
  void didUpdateWidget(VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isPaused != oldWidget.isPaused && !widget.shouldPreload) {
      if (widget.isPaused) {
        _controller.pause();
        if (mounted) {
          try {
            final videoProvider = Provider.of<VideoProvider>(context, listen: false);
            if (videoProvider.activeVideoId == widget.videoId) {
              videoProvider.clearActiveVideo();
            }
          } catch (e) {
            print('📱 Error clearing active video on pause: $e');
          }
        }
      } else {
        _controller.play();
        if (mounted) {
          try {
            context.read<VideoProvider>().setActiveVideo(_controller, widget.videoId);
          } catch (e) {
            print('📱 Error setting active video on play: $e');
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return const Center(
        child: Icon(
          Icons.error_outline,
          color: Colors.white,
          size: 30,
        ),
      );
    }

    if (!_isInitialized) {
      return const Center(
        child: CircularProgressIndicator(
          color: Colors.white,
        ),
      );
    }

    if (widget.shouldPreload) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: () {
        if (_controller.value.isPlaying) {
          _controller.pause();
          if (mounted) {
            try {
              final videoProvider = Provider.of<VideoProvider>(context, listen: false);
              if (videoProvider.activeVideoId == widget.videoId) {
                videoProvider.clearActiveVideo();
              }
            } catch (e) {
              print('📱 Error clearing active video on tap pause: $e');
            }
          }
        } else {
          _controller.play();
          if (mounted) {
            try {
              context.read<VideoProvider>().setActiveVideo(_controller, widget.videoId);
            } catch (e) {
              print('📱 Error setting active video on tap play: $e');
            }
          }
        }
      },
      child: Container(
        width: double.infinity,
        height: double.infinity,
        child: FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: _controller.value.size.width,
            height: _controller.value.size.height,
            child: VideoPlayer(_controller),
          ),
        ),
      ),
    );
  }
} 