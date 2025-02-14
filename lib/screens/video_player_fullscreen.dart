import 'package:flutter/material.dart';
import '../models/video.dart';
import '../widgets/video_card.dart';

class VideoPlayerFullscreen extends StatefulWidget {
  final Video video;
  final int initialIndex;
  final List<Video> videos;

  const VideoPlayerFullscreen({
    super.key,
    required this.video,
    required this.initialIndex,
    required this.videos,
  });

  @override
  State<VideoPlayerFullscreen> createState() => _VideoPlayerFullscreenState();
}

class _VideoPlayerFullscreenState extends State<VideoPlayerFullscreen> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: widget.videos.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              final video = widget.videos[index];
              return VideoCard(
                video: video,
                autoPlay: index == _currentIndex,
                shouldInitialize: (index - _currentIndex).abs() <= 1,
                fit: BoxFit.cover,
              );
            },
          ),
          // Back button overlay
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
} 