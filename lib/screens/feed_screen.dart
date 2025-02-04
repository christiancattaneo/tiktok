import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/video_service.dart';
import '../models/video.dart';
import '../widgets/video_card.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final _videoService = VideoService();
  late PageController _pageController;
  List<Video> _videos = [];
  int _currentPage = 0;
  StreamSubscription<List<Video>>? _videoSubscription;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadVideos();
  }

  void _loadVideos() {
    _videoSubscription = _videoService.getVideoFeed().listen(
      (videos) {
        if (mounted) {
          setState(() {
            _videos = videos;
            _isLoading = false;
          });
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $error')),
          );
        }
      },
    );
  }

  @override
  void dispose() {
    _videoSubscription?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            else if (_videos.isEmpty)
              const Center(
                child: Text(
                  'No videos available\nTry uploading one!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              )
            else
              PageView.builder(
                scrollDirection: Axis.vertical,
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: _videos.length,
                itemBuilder: (context, index) {
                  final shouldInitialize = (index >= _currentPage - 1) && 
                                        (index <= _currentPage + 1);
                  
                  return VideoCard(
                    key: ValueKey(_videos[index].id),
                    video: _videos[index],
                    autoPlay: index == _currentPage,
                    shouldInitialize: shouldInitialize,
                  );
                },
              ),
            
            // Overlay buttons in top-right
            Positioned(
              top: 8,
              right: 8,
              child: Row(
                children: [
                  if (kDebugMode) // Only show in debug mode
                    IconButton(
                      icon: const Icon(Icons.cleaning_services, color: Colors.white),
                      onPressed: () async {
                        try {
                          await _videoService.deleteSampleVideos();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Sample videos cleaned up!')),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: ${e.toString()}')),
                            );
                          }
                        }
                      },
                    ),
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.white),
                    onPressed: () {
                      context.read<AuthProvider>().signOut();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
} 