import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/app_auth_provider.dart';
import '../services/video_service.dart';
import '../services/user_service.dart';
import '../models/video.dart';
import '../models/user.dart' as app_models;
import '../widgets/video_card.dart';
import '../widgets/video_player_widget.dart';
import 'edit_profile_screen.dart';
import 'video_player_fullscreen.dart';
import 'user_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  final _userService = UserService();
  final _videoService = VideoService();
  final _imagePicker = ImagePicker();
  late TabController _tabController;
  bool _isLoading = false;
  // Track pinned state for videos
  final Map<String, bool> _pinnedStates = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );

      if (image == null) return;

      final userId = context.read<AppAuthProvider>().userId;
      if (userId == null) return;

      final success = await _userService.updateProfilePhoto(userId, image);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile photo updated successfully!')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update profile photo')),
          );
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
    final userId = context.read<AppAuthProvider>().userId;
    if (userId == null) return const Center(child: Text('Not logged in'));

    return StreamBuilder<app_models.User?>(
      stream: _userService.getUserStream(userId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final user = snapshot.data!;

        return Scaffold(
          appBar: AppBar(
            title: Text('@${user.username}'),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditProfileScreen(user: user),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () {
                  context.read<AppAuthProvider>().signOut();
                },
              ),
            ],
          ),
          body: Column(
            children: [
              // Profile Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 0),
                child: Column(
                  children: [
                    Stack(
                      children: [
                        GestureDetector(
                          onTap: _isLoading ? null : _pickAndUploadImage,
                          child: CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.grey[800],
                            backgroundImage: user.photoUrl != null && user.photoUrl!.isNotEmpty
                                ? NetworkImage(user.photoUrl!)
                                : null,
                            child: user.photoUrl == null || user.photoUrl!.isEmpty
                                ? const Icon(Icons.person, size: 50, color: Colors.white)
                                : null,
                          ),
                        ),
                        if (_isLoading)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black45,
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      user.username,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (user.bio != null && user.bio!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(user.bio!),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        InkWell(
                          onTap: () => _showFollowers(context, user.id),
                          child: Column(
                            children: [
                              Text(
                                '${user.followersCount}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
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
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Text('Following'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TabBar(
                      controller: _tabController,
                      tabs: const [
                        Tab(text: 'Videos'),
                        Tab(text: 'Pinned'),
                      ],
                    ),
                  ],
                ),
              ),

              // Videos/Liked Tabs
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Videos Tab
                    StreamBuilder<List<Video>>(
                      stream: _videoService.getUserVideos(userId),
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
                      stream: _videoService.getUserLikedVideos(userId),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(child: Text('Error: ${snapshot.error}'));
                        }

                        if (!snapshot.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final videos = snapshot.data!;
                        if (videos.isEmpty) {
                          return const Center(child: Text('No pinned videos'));
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
          ),
        );
      },
    );
  }

  Widget _buildVideoGrid(List<Video> videos) {
    // Initialize all videos as pinned in the Pinned tab
    if (_tabController.index == 1) {
      for (var video in videos) {
        _pinnedStates[video.id] = _pinnedStates[video.id] ?? true;
      }
    }

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
        return Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
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
                  Container(
                    color: Colors.black.withOpacity(0.1),
                  ),
                ],
              ),
            ),

            // Views count overlay
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

            // Modified unpin button
            if (_tabController.index == 1)
              Positioned(
                top: 4,
                left: 4,
                child: GestureDetector(
                  onTap: () async {
                    try {
                      final userId = context.read<AppAuthProvider>().userId;
                      if (userId != null) {
                        // Update local state immediately
                        setState(() {
                          _pinnedStates[video.id] = !(_pinnedStates[video.id] ?? true);
                        });
                        
                        await _videoService.toggleLike(video.id, userId);
                        
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(_pinnedStates[video.id] == true ? 'Video pinned' : 'Video unpinned'),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        }
                      }
                    } catch (e) {
                      // Revert local state on error
                      setState(() {
                        _pinnedStates[video.id] = !(_pinnedStates[video.id] ?? true);
                      });
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Transform.rotate(
                      angle: 0.785398,
                      child: Icon(
                        Icons.push_pin,
                        color: _pinnedStates[video.id] == true ? Colors.red : Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
          ],
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
            child: StreamBuilder<List<app_models.User>>(
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
            child: StreamBuilder<List<app_models.User>>(
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