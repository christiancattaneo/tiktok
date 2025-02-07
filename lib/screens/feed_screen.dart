import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_auth_provider.dart';
import '../providers/video_provider.dart';
import '../services/video_service.dart';
import '../models/video.dart';
import '../widgets/video_card.dart';
import '../widgets/video_player_widget.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'main_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> with WidgetsBindingObserver, RouteAware {
  final _videoService = VideoService();
  late PageController _pageController;
  int _currentPage = 0;
  bool _isLoading = true;
  bool _isPaused = false;
  String _searchQuery = '';
  final _preloadDistance = 3;
  final List<Widget> _preloadWidgets = [];
  static final RouteObserver<ModalRoute<void>> _routeObserver = RouteObserver<ModalRoute<void>>();
  bool _isFollowingFeed = false;
  final List<Map<String, String>> _recentSearches = [];
  static const int _maxRecentSearches = 5;

  static RouteObserver<ModalRoute<void>> get routeObserver => _routeObserver;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0, viewportFraction: 1.0);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _routeObserver.subscribe(this, ModalRoute.of(context)!);
    final videoProvider = Provider.of<VideoProvider>(context, listen: false);
    videoProvider.clearActiveVideo();

    // Listen to tab changes using the public getter
    MainScreen.tabNotifier.addListener(_handleTabChange);
  }

  void _handleTabChange() {
    final isVisible = MainScreen.tabNotifier.value == 0; // 0 is feed tab
    setState(() {
      _isPaused = !isVisible;
    });
    if (!isVisible) {
      final videoProvider = Provider.of<VideoProvider>(context, listen: false);
      videoProvider.clearActiveVideo();
    }
  }

  @override
  void didPushNext() {
    // Route was pushed onto navigator and is now topmost route.
    setState(() {
      _isPaused = true;
    });
  }

  @override
  void didPopNext() {
    // Covering route was popped off the navigator.
    setState(() {
      _isPaused = false;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print('📱 App lifecycle changed to: $state');
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // App is not in foreground, pause video
      setState(() {
        _isPaused = true;
      });
      final videoProvider = Provider.of<VideoProvider>(context, listen: false);
      videoProvider.clearActiveVideo();
      print('📱 Videos paused due to app lifecycle change to: $state');
    } else if (state == AppLifecycleState.resumed) {
      // App is in foreground again
      setState(() {
        _isPaused = false;
      });
      print('📱 Videos resumed due to app lifecycle change to: $state');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          StreamBuilder<List<Video>>(
            stream: _isFollowingFeed 
              ? _videoService.getFollowingVideoFeed(context.read<AppAuthProvider>().userId ?? '')
              : _videoService.getVideoFeed(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error: ${snapshot.error}',
                    style: const TextStyle(color: Colors.white),
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              final videos = snapshot.data!;
              final filteredVideos = _searchQuery.isEmpty
                  ? videos
                  : videos.where((video) {
                      final query = _searchQuery.toLowerCase();
                      
                      // If query starts with @, only search usernames
                      if (query.startsWith('@')) {
                        final username = video.creatorUsername.toLowerCase();
                        return username.contains(query.substring(1));
                      }
                      
                      // Otherwise search everything
                      final caption = video.caption.toLowerCase();
                      final creator = video.creatorUsername.toLowerCase();
                      final hashtags = video.hashtags.map((tag) => tag.toLowerCase());
                      
                      return caption.contains(query) ||
                             creator.contains(query) ||
                             hashtags.any((tag) => tag.contains(query));
                    }).toList();

              if (filteredVideos.isEmpty) {
                return Center(
                  child: Text(
                    _isFollowingFeed 
                      ? 'Follow some creators to see their videos here!'
                      : 'No videos found',
                    style: const TextStyle(color: Colors.white),
                  ),
                );
              }

              return PageView.builder(
                scrollDirection: Axis.vertical,
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                  _updatePreloadWidgets(index, filteredVideos);
                  
                  // Increment view count when video is viewed
                  _videoService.incrementViews(filteredVideos[index].id);
                },
                itemCount: filteredVideos.length,
                itemBuilder: (context, index) {
                  final video = filteredVideos[index];
                  final isCurrentVideo = index == _currentPage;
                  final shouldInitialize = (index - _currentPage).abs() <= 1;
                  
                  return VideoCard(
                    key: ValueKey('${video.id}_${video.likes}'),
                    video: video,
                    autoPlay: isCurrentVideo && !_isPaused,
                    shouldInitialize: shouldInitialize,
                  );
                },
              );
            },
          ),
          
          // Top Bar with Tabs
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.only(top: 100, bottom: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isFollowingFeed = false;
                          });
                        },
                        child: Text(
                          'For You',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: !_isFollowingFeed ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isFollowingFeed = true;
                          });
                        },
                        child: Text(
                          'Following',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: _isFollowingFeed ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Indicator line
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 120,
                        height: 2,
                        color: Colors.white.withOpacity(0.2),
                      ),
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 200),
                        left: _isFollowingFeed ? 60 : 0,
                        child: Container(
                          width: 60,
                          height: 2,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          // Search and Logout buttons
          Positioned(
            top: 65,
            right: 8,
            child: Row(
              children: [
                if (_searchQuery.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () {
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.search, color: Colors.white),
                  onPressed: _showSearchDialog,
                ),
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.white),
                  onPressed: _handleSignOut,
                ),
              ],
            ),
          ),
          
          // VibeTok title
          Positioned(
            top: 65,
            left: 16,
            child: Text(
              'VibeTok',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                fontFamily: 'Pacifico',
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _updatePreloadWidgets(int currentIndex, List<Video> videos) {
    _preloadWidgets.clear();
    for (var i = 1; i <= _preloadDistance; i++) {
      final preloadIndex = currentIndex + i;
      if (preloadIndex < videos.length) {
        _preloadWidgets.add(
          Offstage(
            offstage: true,
            child: VideoPlayerWidget(
              key: ValueKey('preload_${videos[preloadIndex].id}'),
              videoUrl: videos[preloadIndex].videoUrl,
              videoId: videos[preloadIndex].id,
              isPaused: true,
              shouldPreload: true,
            ),
          ),
        );
      }
    }
    if (mounted) setState(() {});

    // Load more videos when we're near the end
    if (currentIndex >= videos.length - 3) {
      _loadMoreVideos();
    }
  }

  Future<void> _loadMoreVideos() async {
    try {
      print('🎥 Loading more videos with search query: $_searchQuery');
      final newVideos = await _videoService.fetchPexelsVideos(
        searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null
      );
      print('🎥 Loaded ${newVideos.length} new videos');
      if (newVideos.isNotEmpty) {
        print('🎥 First video caption: ${newVideos.first.caption}');
        print('🎥 First video hashtags: ${newVideos.first.hashtags}');
      }
      if (mounted && newVideos.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Loaded ${newVideos.length} new videos')),
        );
      }
    } catch (e) {
      print('🎥 Error loading more videos: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading videos: $e')),
        );
      }
    }
  }

  void _handleSignOut() {
    print('📱 Handling sign out in FeedScreen');
    // First pause any playing videos
    setState(() {
      _isPaused = true;
    });
    
    // Clear the active video
    if (mounted) {
      try {
        final videoProvider = Provider.of<VideoProvider>(context, listen: false);
        videoProvider.clearActiveVideo();
      } catch (e) {
        print('📱 Error clearing active video during sign out: $e');
      }
    }
    
    // Now proceed with sign out
    if (mounted) {
      context.read<AppAuthProvider>().signOut();
    }
  }

  void _addToRecentSearches(String query, String type) {
    setState(() {
      // Remove if already exists to avoid duplicates
      _recentSearches.removeWhere((search) => 
        search['query'] == query && search['type'] == type
      );
      
      // Add to beginning of list
      _recentSearches.insert(0, {
        'query': query,
        'type': type,
      });
      
      // Keep only most recent 5
      if (_recentSearches.length > _maxRecentSearches) {
        _recentSearches.removeLast();
      }
    });
  }

  Future<void> _showSearchDialog() async {
    final TextEditingController searchController = TextEditingController();
    
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: searchController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Search videos or creators...',
                prefixIcon: Icon(Icons.search),
              ),
              onSubmitted: (value) => Navigator.pop(context, {'query': value, 'type': 'videos'}),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.video_library),
                  label: const Text('Videos'),
                  onPressed: () => Navigator.pop(context, {'query': searchController.text, 'type': 'videos'}),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  icon: const Icon(Icons.person),
                  label: const Text('Creators'),
                  onPressed: () => Navigator.pop(context, {'query': searchController.text, 'type': 'creators'}),
                ),
              ],
            ),
            if (_recentSearches.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Recent Searches',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ...List.generate(_recentSearches.length, (index) {
                final search = _recentSearches[index];
                final isCreator = search['type'] == 'creators';
                return ListTile(
                  leading: Icon(
                    isCreator ? Icons.person : Icons.video_library,
                    size: 20,
                  ),
                  title: Text(search['query']!),
                  subtitle: Text(isCreator ? 'Creator' : 'Video'),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () {
                      setState(() {
                        _recentSearches.removeAt(index);
                      });
                      Navigator.pop(context);
                      _showSearchDialog(); // Reopen dialog to show updated list
                    },
                  ),
                  onTap: () => Navigator.pop(context, search),
                  dense: true,
                );
              }),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
        ],
      ),
    );

    if (result != null && result['query']?.isNotEmpty == true) {
      // Add to recent searches
      _addToRecentSearches(result['query']!, result['type'] ?? 'videos');
      
      setState(() {
        _searchQuery = result['query']!;
      });
      
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Searching...')),
        );
      }

      // Immediately load new videos when search term changes
      if (result['type'] == 'creators') {
        print('🔍 Searching for creator: ${result['query']}');
        // Creator search is handled by the video stream filter
      } else {
        print('🔍 Searching for videos: ${result['query']}');
        await _loadMoreVideos();
      }
    }
  }

  @override
  void dispose() {
    print('📱 FeedScreen dispose started');
    MainScreen.tabNotifier.removeListener(_handleTabChange);
    _routeObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    print('📱 Disposing page controller');
    _pageController.dispose();
    super.dispose();
    print('📱 FeedScreen dispose completed');
  }
} 