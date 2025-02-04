import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/auth_provider.dart';
import '../services/video_service.dart';
import '../services/user_service.dart';
import '../models/video.dart';
import '../models/user.dart' as app_models;
import '../widgets/video_card.dart';
import 'edit_profile_screen.dart';

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

      final userId = context.read<AuthProvider>().userId;
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
    final userId = context.read<AuthProvider>().userId;
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
                  context.read<AuthProvider>().signOut();
                },
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Videos'),
                Tab(text: 'Liked'),
              ],
            ),
          ),
          body: Column(
            children: [
              // Profile Header
              Padding(
                padding: const EdgeInsets.all(16.0),
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
                        Column(
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
                        Column(
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

                        return GridView.builder(
                          padding: const EdgeInsets.all(8),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 0.6,
                          ),
                          itemCount: videos.length,
                          itemBuilder: (context, index) {
                            final video = videos[index];
                            return GestureDetector(
                              onTap: () {
                                // TODO: Open video in full screen
                              },
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  if (video.thumbnailUrl != null)
                                    Image.network(
                                      video.thumbnailUrl!,
                                      fit: BoxFit.cover,
                                    )
                                  else
                                    Container(
                                      color: Colors.grey[900],
                                      child: const Icon(
                                        Icons.play_circle_outline,
                                        color: Colors.white,
                                        size: 32,
                                      ),
                                    ),
                                  Positioned(
                                    bottom: 4,
                                    right: 4,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.favorite,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${video.likes}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
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
                          return const Center(child: Text('No liked videos'));
                        }

                        return GridView.builder(
                          padding: const EdgeInsets.all(8),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 0.6,
                          ),
                          itemCount: videos.length,
                          itemBuilder: (context, index) {
                            final video = videos[index];
                            return GestureDetector(
                              onTap: () {
                                // TODO: Open video in full screen
                              },
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  if (video.thumbnailUrl != null)
                                    Image.network(
                                      video.thumbnailUrl!,
                                      fit: BoxFit.cover,
                                    )
                                  else
                                    Container(
                                      color: Colors.grey[900],
                                      child: const Icon(
                                        Icons.play_circle_outline,
                                        color: Colors.white,
                                        size: 32,
                                      ),
                                    ),
                                  Positioned(
                                    bottom: 4,
                                    left: 4,
                                    child: Text(
                                      '@${video.creatorUsername}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
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