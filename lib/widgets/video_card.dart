import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/video.dart';
import '../providers/auth_provider.dart';
import '../services/video_service.dart';
import '../screens/user_profile_screen.dart';
import 'video_player_widget.dart';
import 'comments_sheet.dart';

class VideoCard extends StatefulWidget {
  final Video video;
  final bool autoPlay;
  final bool shouldInitialize;

  const VideoCard({
    super.key,
    required this.video,
    this.autoPlay = true,
    this.shouldInitialize = true,
  });

  @override
  State<VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<VideoCard> with SingleTickerProviderStateMixin {
  final _videoService = VideoService();
  late AnimationController _likeController;
  late Animation<double> _likeAnimation;
  bool _isLiked = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _likeController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _likeAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _likeController, curve: Curves.easeInOut),
    );
    _checkLikeStatus();
  }

  @override
  void dispose() {
    _likeController.dispose();
    super.dispose();
  }

  Future<void> _checkLikeStatus() async {
    final userId = context.read<AuthProvider>().userId;
    if (userId != null) {
      final isLiked = await _videoService.hasUserLikedVideo(widget.video.id, userId);
      if (mounted) {
        setState(() {
          _isLiked = isLiked;
        });
      }
    }
  }

  Future<void> _toggleLike() async {
    if (_isLoading) return;

    final userId = context.read<AuthProvider>().userId;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to like videos')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final isLiked = await _videoService.toggleLike(widget.video.id, userId);
      if (mounted) {
        setState(() {
          _isLiked = isLiked;
        });
        if (isLiked) {
          _likeController.forward().then((_) => _likeController.reverse());
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: CommentsSheet(video: widget.video),
        ),
      ),
    );
  }

  Widget _buildProfilePhoto() {
    return CircleAvatar(
      radius: 16,
      backgroundColor: Colors.grey[800],
      backgroundImage: widget.video.creatorPhotoUrl != null && 
                      widget.video.creatorPhotoUrl!.isNotEmpty
          ? NetworkImage(widget.video.creatorPhotoUrl!)
          : null,
      child: widget.video.creatorPhotoUrl == null || 
             widget.video.creatorPhotoUrl!.isEmpty
          ? const Icon(Icons.person, color: Colors.white, size: 16)
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Video player
        VideoPlayerWidget(
          video: widget.video,
          autoPlay: widget.autoPlay,
          shouldInitialize: widget.shouldInitialize,
        ),

        // Gradient overlay
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.3),
                  Colors.transparent,
                  Colors.black.withOpacity(0.3),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),

        // Video Info
        Positioned(
          bottom: 16,
          left: 16,
          right: 60,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UserProfileScreen(
                        userId: widget.video.userId,
                        username: widget.video.creatorUsername,
                      ),
                    ),
                  );
                },
                child: Row(
                  children: [
                    _buildProfilePhoto(),
                    const SizedBox(width: 8),
                    Text(
                      '@${widget.video.creatorUsername}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.video.caption,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: widget.video.hashtags.map((tag) => Text(
                  '#$tag',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                )).toList(),
              ),
            ],
          ),
        ),

        // Action Buttons
        Positioned(
          right: 8,
          bottom: 16,
          child: Column(
            children: [
              ScaleTransition(
                scale: _likeAnimation,
                child: IconButton(
                  icon: Icon(
                    _isLiked ? Icons.favorite : Icons.favorite_border,
                    color: _isLiked ? Colors.red : Colors.white,
                  ),
                  onPressed: _isLoading ? null : _toggleLike,
                ),
              ),
              Text(
                '${widget.video.likes}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              IconButton(
                icon: const Icon(Icons.comment),
                color: Colors.white,
                onPressed: _showComments,
              ),
              Text(
                '${widget.video.commentCount ?? 0}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              IconButton(
                icon: const Icon(Icons.remove_red_eye),
                color: Colors.white,
                onPressed: () {
                  // TODO: Implement view tracking
                },
              ),
              Text(
                '${widget.video.views}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
} 