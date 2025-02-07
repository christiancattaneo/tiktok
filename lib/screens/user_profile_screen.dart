import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_auth_provider.dart';
import '../services/video_service.dart';
import '../services/user_service.dart';
import '../models/video.dart';
import '../models/user.dart';
import '../widgets/video_card.dart';
import '../widgets/video_player_widget.dart';
import '../screens/video_player_fullscreen.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;
  final String username;

  const UserProfileScreen({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _videoService = VideoService();
  final _userService = UserService();
  bool _isFollowing = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkFollowStatus();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkFollowStatus() async {
    final currentUserId = context.read<AppAuthProvider>().userId;
    if (currentUserId != null && currentUserId != widget.userId) {
      final isFollowing = await _userService.isFollowing(currentUserId, widget.userId);
      if (mounted) {
        setState(() {
          _isFollowing = isFollowing;
        });
      }
    }
  }

  Future<void> _toggleFollow() async {
    if (_isLoading) return;

    final currentUserId = context.read<AppAuthProvider>().userId;
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to follow users')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isFollowing) {
        await _userService.unfollowUser(currentUserId, widget.userId);
      } else {
        await _userService.followUser(currentUserId, widget.userId);
      }
      
      setState(() {
        _isFollowing = !_isFollowing;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showFollowers(BuildContext context, String userId) {
    showModalBottomSheet(
      context: context,
      builder: (context) => _FollowersSheet(userId: userId),
    );
  }

  void _showFollowing(BuildContext context, String userId) {
    showModalBottomSheet(
      context: context,
      builder: (context) => _FollowingSheet(userId: userId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.read<AppAuthProvider>().userId;
    final isCurrentUser = currentUserId == widget.userId;

    return Scaffold(
      appBar: AppBar(
        title: Text('@${widget.username}'),
      ),
      body: StreamBuilder<User?>(
        stream: _userService.getUserStream(widget.userId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final user = snapshot.data;
          if (user == null) {
            return const Center(child: Text('User not found'));
          }

          return Column(
            children: [
              // Profile Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundImage: user.photoUrl.isNotEmpty
                          ? NetworkImage(user.photoUrl)
                          : null,
                      child: user.photoUrl.isEmpty
                          ? const Icon(Icons.person, size: 50)
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '@${user.username}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (user.bio.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        user.bio,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (!isCurrentUser) ...[
                      ElevatedButton(
                        onPressed: _isLoading ? null : _toggleFollow,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isFollowing ? Colors.grey : Colors.blue,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(200, 40),
                        ),
                        child: Text(_isFollowing ? 'Following' : 'Follow'),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        InkWell(
                          onTap: () => _showFollowers(context, user.id),
                          child: Column(
                            children: [
                              Text(
                                '${user.followersCount}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const Text('Followers'),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: () => _showFollowing(context, user.id),
                          child: Column(
                            children: [
                              Text(
                                '${user.followingCount}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const Text('Following'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Tabs
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Videos'),
                  Tab(text: 'Liked'),
                ],
              ),

              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Created Videos Tab
                    StreamBuilder<List<Video>>(
                      stream: _videoService.getUserVideos(user.id),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(child: Text('Error: ${snapshot.error}'));
                        }
                        if (!snapshot.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        final videos = snapshot.data!;
                        if (videos.isEmpty) {
                          return const Center(child: Text('No videos yet'));
                        }
                        return SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: _buildVideoGrid(videos),
                        );
                      },
                    ),

                    // Liked Videos Tab
                    StreamBuilder<List<Video>>(
                      stream: _videoService.getUserLikedVideos(user.id),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(child: Text('Error: ${snapshot.error}'));
                        }
                        if (!snapshot.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        final videos = snapshot.data!;
                        if (videos.isEmpty) {
                          return const Center(child: Text('No liked videos'));
                        }
                        return SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: _buildVideoGrid(videos),
                        );
                      },
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

  Widget _buildVideoGrid(List<Video> videos) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.8,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: videos.length,
      itemBuilder: (context, index) {
        final video = videos[index];
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => VideoPlayerFullscreen(
                  video: video,
                  initialIndex: index,
                  videos: videos,
                ),
              ),
            );
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                ),
                child: ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.center,
                    maxWidth: double.infinity,
                    maxHeight: double.infinity,
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: 1,
                        height: 1.25, // Force 0.8 aspect ratio (1/1.25 = 0.8)
                        child: VideoPlayerWidget(
                          videoUrl: video.videoUrl,
                          videoId: video.id,
                          isPaused: true,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => VideoPlayerFullscreen(
                          video: video,
                          initialIndex: index,
                          videos: videos,
                        ),
                      ),
                    );
                  },
                ),
              ),
              Container(
                color: Colors.black.withOpacity(0.1),
              ),
              Positioned(
                bottom: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${video.views}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FollowersSheet extends StatelessWidget {
  final String userId;
  final _userService = UserService();

  _FollowersSheet({required this.userId});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            'Followers',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<List<User>>(
              stream: _userService.getUserFollowers(userId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final followers = snapshot.data!;
                if (followers.isEmpty) {
                  return const Center(child: Text('No followers yet'));
                }
                return ListView.builder(
                  itemCount: followers.length,
                  itemBuilder: (context, index) {
                    final follower = followers[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: follower.photoUrl.isNotEmpty
                            ? NetworkImage(follower.photoUrl)
                            : null,
                        child: follower.photoUrl.isEmpty
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      title: Text('@${follower.username}'),
                      subtitle: Text(follower.bio),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => UserProfileScreen(
                              userId: follower.id,
                              username: follower.username,
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FollowingSheet extends StatelessWidget {
  final String userId;
  final _userService = UserService();

  _FollowingSheet({required this.userId});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            'Following',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<List<User>>(
              stream: _userService.getUserFollowing(userId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final following = snapshot.data!;
                if (following.isEmpty) {
                  return const Center(child: Text('Not following anyone yet'));
                }
                return ListView.builder(
                  itemCount: following.length,
                  itemBuilder: (context, index) {
                    final followedUser = following[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: followedUser.photoUrl.isNotEmpty
                            ? NetworkImage(followedUser.photoUrl)
                            : null,
                        child: followedUser.photoUrl.isEmpty
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      title: Text('@${followedUser.username}'),
                      subtitle: Text(followedUser.bio),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => UserProfileScreen(
                              userId: followedUser.id,
                              username: followedUser.username,
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
} 