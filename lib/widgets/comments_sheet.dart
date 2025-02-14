import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:giphy_picker/giphy_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../models/comment.dart';
import '../models/video.dart';
import '../providers/app_auth_provider.dart';
import '../services/video_service.dart';
import '../services/config_service.dart';
import '../screens/user_profile_screen.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Custom cache manager for GIFs
class GifCacheManager extends CacheManager {
  static const key = 'gifCacheKey';
  
  static final GifCacheManager _instance = GifCacheManager._();
  factory GifCacheManager() => _instance;

  GifCacheManager._() : super(
    Config(
      key,
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 100,
      repo: JsonCacheInfoRepository(databaseName: key),
      fileService: HttpFileService(),
    ),
  );
}

class CommentsSheet extends StatefulWidget {
  final Video video;

  const CommentsSheet({
    super.key,
    required this.video,
  });

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentLikeButton extends StatefulWidget {
  final Comment comment;
  final bool isLiked;
  final Function(Comment) onLike;

  const _CommentLikeButton({
    required this.comment,
    required this.isLiked,
    required this.onLike,
  });

  @override
  State<_CommentLikeButton> createState() => _CommentLikeButtonState();
}

class _CommentLikeButtonState extends State<_CommentLikeButton> with SingleTickerProviderStateMixin {
  late AnimationController _likeController;
  late Animation<double> _likeAnimation;

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
  }

  @override
  void dispose() {
    _likeController.dispose();
    super.dispose();
  }

  void _handleLike() async {
    await widget.onLike(widget.comment);
    if (mounted && widget.isLiked) {
      _likeController.forward().then((_) => _likeController.reverse());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ScaleTransition(
          scale: _likeAnimation,
          child: IconButton(
            icon: Icon(
              widget.isLiked ? Icons.favorite : Icons.favorite_border,
              color: widget.isLiked ? Colors.red : null,
            ),
            onPressed: _handleLike,
          ),
        ),
        Text(
          '${widget.comment.likes}',
          style: TextStyle(
            color: widget.isLiked ? Colors.red : Colors.grey[600],
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _CommentsSheetState extends State<CommentsSheet> with SingleTickerProviderStateMixin {
  final _videoService = VideoService();
  final _commentController = TextEditingController();
  bool _isSubmitting = false;
  Map<String, bool> _likedComments = {};
  GiphyGif? _selectedGif;

  // Keep track of visible items for preloading
  final _visibleItems = <int>{};
  final _preloadedGifs = <String>{};
  static const _preloadDistance = 3;

  // Add GIPHY API key getter
  String get _giphyApiKey => dotenv.env['GIPHY_API_KEY'] ?? '';

  @override
  void initState() {
    super.initState();
    // Clear old cache on init
    _clearOldCache();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _clearOldCache() async {
    try {
      await GifCacheManager().emptyCache();
    } catch (e) {
      print('Error clearing GIF cache: $e');
    }
  }

  Future<void> _preloadGif(String gifUrl) async {
    if (_preloadedGifs.contains(gifUrl)) return;
    
    try {
      // Add to preloaded set immediately to prevent duplicate loads
      _preloadedGifs.add(gifUrl);
      
      // Start preloading
      await GifCacheManager().downloadFile(gifUrl);
    } catch (e) {
      print('Error preloading GIF: $e');
      // Remove from preloaded set if failed
      _preloadedGifs.remove(gifUrl);
    }
  }

  void _updateVisibleItems(int index) {
    _visibleItems.add(index);
    
    // Preload next few GIFs
    final comments = context.read<List<Comment>?>();
    if (comments != null) {
      for (var i = 1; i <= _preloadDistance; i++) {
        final preloadIndex = index + i;
        if (preloadIndex < comments.length) {
          final gifUrl = comments[preloadIndex].gifUrl;
          if (gifUrl != null) {
            _preloadGif(gifUrl);
          }
        }
      }
    }
  }

  String _getOptimizedGifUrl(String originalUrl) {
    // Convert original GIPHY URL to downsized version
    // Example: https://media.giphy.com/media/xxx/giphy.gif
    // to: https://media.giphy.com/media/xxx/200.gif
    try {
      final uri = Uri.parse(originalUrl);
      final pathSegments = uri.pathSegments.toList();
      if (pathSegments.isNotEmpty) {
        pathSegments[pathSegments.length - 1] = '200.gif';
        return uri.replace(pathSegments: pathSegments).toString();
      }
    } catch (e) {
      print('Error optimizing GIF URL: $e');
    }
    return originalUrl;
  }

  Widget _buildGifImage(String gifUrl) {
    final optimizedUrl = _getOptimizedGifUrl(gifUrl);
    
    return CachedNetworkImage(
      imageUrl: optimizedUrl,
      cacheManager: GifCacheManager(),
      height: 150,
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 300),
      placeholder: (context, url) => Container(
        height: 150,
        color: Colors.grey[200],
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        height: 150,
        color: Colors.grey[200],
        child: const Center(
          child: Icon(Icons.error_outline),
        ),
      ),
    );
  }

  Future<void> _pickGif() async {
    final gif = await GiphyPicker.pickGif(
      context: context,
      apiKey: _giphyApiKey,
    );
    
    if (gif != null && mounted) {
      setState(() {
        _selectedGif = gif;
      });
      
      // Focus the text field after selecting a GIF
      FocusScope.of(context).requestFocus(FocusNode());
      // Show a snackbar to guide the user
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add a message (optional) and tap send to post your GIF'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty && _selectedGif == null) return;

    final userId = context.read<AppAuthProvider>().userId;
    final user = context.read<AppAuthProvider>().user;
    
    if (userId == null || user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to comment')),
        );
      }
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await _videoService.addComment(
        videoId: widget.video.id,
        userId: userId,
        username: user.username,
        text: text,
        userPhotoUrl: user.photoUrl,
        gifUrl: _selectedGif?.images.original?.url,
        gifId: _selectedGif?.id,
      );
      
      if (mounted) {
        _commentController.clear();
        setState(() {
          _selectedGif = null;
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
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _deleteComment(Comment comment) async {
    final userId = context.read<AppAuthProvider>().userId;
    if (userId != comment.userId) return;

    try {
      await _videoService.deleteComment(widget.video.id, comment.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _toggleLike(Comment comment) async {
    final userId = context.read<AppAuthProvider>().userId;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to pin comments')),
      );
      return;
    }

    try {
      // Check if current user is the video creator
      final isCreator = userId == widget.video.userId;
      
      final isLiked = await _videoService.toggleCommentLike(widget.video.id, comment.id, userId);
      if (mounted) {
        setState(() {
          _likedComments[comment.id] = isLiked;
          
          // If the current user is the creator, update likedByCreator status immediately
          if (isCreator) {
            comment.likedByCreator = isLiked;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _checkLikeStatus(Comment comment) async {
    final userId = context.read<AppAuthProvider>().userId;
    if (userId != null) {
      final isLiked = await _videoService.hasUserLikedComment(comment.id, userId);
      if (mounted) {
        setState(() {
          _likedComments[comment.id] = isLiked;
        });
      }
    }
  }

  Widget _buildProfilePhoto(String? photoUrl, {double radius = 16}) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey[800],
      backgroundImage: photoUrl != null && photoUrl.isNotEmpty
          ? NetworkImage(photoUrl)
          : null,
      child: photoUrl == null || photoUrl.isEmpty
          ? Icon(Icons.person, color: Colors.white, size: radius)
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxHeight = constraints.maxHeight;
          final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
          final gifPreviewHeight = keyboardVisible ? 100.0 : 150.0;  // Shrink when keyboard visible

          return Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Comments',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Comments List
              Expanded(
                child: StreamBuilder<List<Comment>>(
                  stream: _videoService.getVideoComments(widget.video.id),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }

                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final comments = snapshot.data!;
                    if (comments.isEmpty) {
                      return const Center(child: Text('No comments yet'));
                    }

                    return ListView.builder(
                      itemCount: comments.length,
                      itemBuilder: (context, index) {
                        final comment = comments[index];
                        final isAuthor = comment.userId == context.read<AppAuthProvider>().userId;

                        if (!_likedComments.containsKey(comment.id)) {
                          _checkLikeStatus(comment);
                        }

                        return VisibilityDetector(
                          key: Key('comment_${comment.id}'),
                          onVisibilityChanged: (info) {
                            if (info.visibleFraction > 0) {
                              _updateVisibleItems(index);
                            }
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Profile Photo
                                    GestureDetector(
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => UserProfileScreen(
                                            userId: comment.userId,
                                            username: comment.username,
                                          ),
                                        ),
                                      ),
                                      child: _buildProfilePhoto(comment.userPhotoUrl),
                                    ),
                                    const SizedBox(width: 12),
                                    // Comment Content
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Username and Badge
                                          Wrap(
                                            crossAxisAlignment: WrapCrossAlignment.center,
                                            spacing: 8,
                                            children: [
                                              Text(
                                                '@${comment.username}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              if (comment.likedByCreator)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons.verified,
                                                        size: 14,
                                                        color: Theme.of(context).primaryColor,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        'Pinned by creator',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: Theme.of(context).primaryColor,
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                            ],
                                          ),
                                          if (comment.text.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(comment.text),
                                          ],
                                          if (comment.gifUrl != null) ...[
                                            const SizedBox(height: 8),
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(8),
                                              child: _buildGifImage(comment.gifUrl!),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    // Action Buttons
                                    Column(
                                      children: [
                                        _CommentLikeButton(
                                          comment: comment,
                                          isLiked: _likedComments[comment.id] == true,
                                          onLike: _toggleLike,
                                        ),
                                        if (isAuthor)
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline),
                                            onPressed: () => _deleteComment(comment),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(height: 1),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              // Bottom section with GIF preview and input
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Selected GIF preview
                    if (_selectedGif != null && _selectedGif!.images.original?.url != null)
                      Container(
                        constraints: BoxConstraints(maxHeight: gifPreviewHeight),
                        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context).dividerColor,
                            width: 1,
                          ),
                        ),
                        child: Stack(
                          alignment: Alignment.topRight,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(11),
                              child: Image.network(
                                _selectedGif!.images.original!.url!,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return const SizedBox(
                                    height: 150,
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                },
                              ),
                            ),
                            Material(
                              color: Colors.black.withOpacity(0.5),
                              borderRadius: const BorderRadius.only(
                                topRight: Radius.circular(11),
                                bottomLeft: Radius.circular(11),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.close, color: Colors.white, size: 20),
                                padding: const EdgeInsets.all(8),
                                constraints: const BoxConstraints(),
                                onPressed: () => setState(() => _selectedGif = null),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Comment input
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.gif_box_outlined,
                              color: _selectedGif != null 
                                  ? Theme.of(context).primaryColor
                                  : null,
                            ),
                            onPressed: _isSubmitting ? null : _pickGif,
                          ),
                          Expanded(
                            child: TextField(
                              controller: _commentController,
                              decoration: InputDecoration(
                                hintText: _selectedGif != null 
                                  ? 'Add a message with your GIF...' 
                                  : 'Add a comment...',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                              ),
                              maxLines: null,
                              keyboardType: TextInputType.multiline,
                              textCapitalization: TextCapitalization.sentences,
                              enabled: !_isSubmitting,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: (_selectedGif != null || _commentController.text.trim().isNotEmpty)
                                  ? Theme.of(context).primaryColor
                                  : Colors.grey[300],
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: _isSubmitting
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.send,
                                      color: Colors.white,
                                    ),
                              onPressed: (_selectedGif != null || _commentController.text.trim().isNotEmpty) && !_isSubmitting
                                  ? _submitComment
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
} 