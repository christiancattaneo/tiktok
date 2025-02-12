import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:video_player/video_player.dart';
import '../models/video.dart';
import '../providers/app_auth_provider.dart';
import '../services/video_service.dart';
import '../screens/user_profile_screen.dart';
import 'video_player_widget.dart';
import 'comments_sheet.dart';
import '../services/user_service.dart';
import '../models/user.dart' as app_models;

class VideoCard extends StatefulWidget {
  final Video video;
  final bool autoPlay;
  final bool shouldInitialize;
  final BoxFit fit;
  final bool preloadOnly;

  const VideoCard({
    super.key,
    required this.video,
    this.autoPlay = true,
    this.shouldInitialize = true,
    this.fit = BoxFit.contain,
    this.preloadOnly = false,
  });

  @override
  State<VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<VideoCard> with SingleTickerProviderStateMixin {
  final _videoService = VideoService();
  final _userService = UserService();
  late AnimationController _likeController;
  late Animation<double> _likeAnimation;
  bool _isLiked = false;
  bool _isLoading = false;
  bool _showHeartOverlay = false;

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

    // Listen to animation status to hide heart overlay
    _likeController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _showHeartOverlay = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _likeController.dispose();
    super.dispose();
  }

  Future<void> _checkLikeStatus() async {
    final userId = context.read<AppAuthProvider>().userId;
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

    final userId = context.read<AppAuthProvider>().userId;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to like videos')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _showHeartOverlay = true;
    });

    try {
      final isLiked = await _videoService.toggleLike(widget.video.id, userId);
      if (mounted) {
        setState(() {
          _isLiked = isLiked;
        });
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
    return StreamBuilder<app_models.User?>(
      stream: _userService.getUserStream(widget.video.userId),
      builder: (context, snapshot) {
        final photoUrl = snapshot.data?.photoUrl ?? widget.video.creatorPhotoUrl;
        
        return CircleAvatar(
          radius: 16,
          backgroundColor: Colors.grey[800],
          backgroundImage: photoUrl != null && photoUrl.isNotEmpty
              ? NetworkImage(photoUrl)
              : null,
          child: photoUrl == null || photoUrl.isEmpty
              ? const Icon(Icons.person, color: Colors.white, size: 16)
              : null,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Video player with double tap gesture
        GestureDetector(
          onDoubleTap: () async {
            if (!_isLoading) {
              final userId = context.read<AppAuthProvider>().userId;
              if (userId != null) {
                // Toggle like without showing heart animation
                await _toggleLike();
              }
            }
          },
          child: SizedBox.expand(
            child: VideoPlayerWidget(
              videoUrl: widget.video.videoUrl,
              videoId: widget.video.id,
              isPaused: !widget.autoPlay,
              shouldPreload: !widget.shouldInitialize,
            ),
          ),
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
          bottom: 80,
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
          bottom: 80,
          child: Column(
            children: [
              IconButton(
                icon: Icon(
                  _isLiked ? Icons.favorite : Icons.favorite_border,
                  color: _isLiked ? Colors.red : Colors.white,
                ),
                onPressed: _isLoading ? null : _toggleLike,
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
              if (context.read<AppAuthProvider>().userId == widget.video.userId) ...[
                const SizedBox(height: 16),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  color: Colors.white,
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Video'),
                        content: const Text('Are you sure you want to delete this video? This action cannot be undone.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('CANCEL'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('DELETE'),
                          ),
                        ],
                      ),
                    );

                    if (confirmed == true) {
                      try {
                        await _videoService.deleteVideo(widget.video.id, widget.video.userId);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Video deleted successfully')),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error deleting video: $e')),
                          );
                        }
                      }
                    }
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
} 