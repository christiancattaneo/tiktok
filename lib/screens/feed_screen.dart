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
import '../utils/video_cache_manager.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> with WidgetsBindingObserver, RouteAware {
  final _videoService = VideoService();
  late PageController _forYouPageController;
  late PageController _followingPageController;
  int _currentForYouPage = 0;
  int _currentFollowingPage = 0;
  bool _isLoading = true;
  bool _isPaused = false;
  String _searchQuery = '';
  final _preloadDistance = 3;
  final List<Widget> _preloadWidgets = [];
  static final RouteObserver<ModalRoute<void>> _routeObserver = RouteObserver<ModalRoute<void>>();
  bool _isFollowingFeed = false;
  final List<Map<String, String>> _recentSearches = [];
  static const int _maxRecentSearches = 5;
  DateTime? _lastVideoTimestamp;  // Track the timestamp of the last video
  final _searchController = TextEditingController();
  bool _isSearchMode = false;
  final FocusNode _searchFocusNode = FocusNode();

  static RouteObserver<ModalRoute<void>> get routeObserver => _routeObserver;

  @override
  void initState() {
    super.initState();
    _forYouPageController = PageController(initialPage: 0, viewportFraction: 1.0);
    _followingPageController = PageController(initialPage: 0, viewportFraction: 1.0);
    WidgetsBinding.instance.addObserver(this);
    _initializeFeed();
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

              // Update last video timestamp for pagination
              if (filteredVideos.isNotEmpty && !_isFollowingFeed) {
                _lastVideoTimestamp = filteredVideos.last.createdAt;
              }

              return PageView.builder(
                scrollDirection: Axis.vertical,
                controller: _isFollowingFeed ? _followingPageController : _forYouPageController,
                onPageChanged: (index) {
                  setState(() {
                    if (_isFollowingFeed) {
                      _currentFollowingPage = index;
                    } else {
                      _currentForYouPage = index;
                    }
                  });
                  _updatePreloadWidgets(index, filteredVideos);
                  
                  // Increment view count when video is viewed
                  _videoService.incrementViews(filteredVideos[index].id);

                  // Load more videos when we're near the end
                  if (!_isFollowingFeed && index >= filteredVideos.length - 5) {
                    _loadMoreVideos();
                  }
                },
                itemCount: filteredVideos.length,
                itemBuilder: (context, index) {
                  final video = filteredVideos[index];
                  final isCurrentVideo = _isFollowingFeed 
                    ? index == _currentFollowingPage 
                    : index == _currentForYouPage;
                  final shouldInitialize = index == 0 || (index - (_isFollowingFeed ? _currentFollowingPage : _currentForYouPage)).abs() <= 1;
                  
                  return VideoCard(
                    key: ValueKey('${video.id}_${video.likes}'),
                    video: video,
                    autoPlay: isCurrentVideo && !_isPaused,
                    shouldInitialize: shouldInitialize,
                    hideControls: _isSearchMode && _searchFocusNode.hasFocus,
                  );
                },
              );
            },
          ),
          
          // Top Overlay (Search and UI)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.7),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.8],
              ),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Search Bar and Top Actions
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        if (!_isSearchMode) ...[
                          // VibeTok Title
                          const Text(
                            'VibeTok',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Pacifico',
                            ),
                          ),
                          const Spacer(),
                          // Search Button
                          IconButton(
                            icon: const Icon(Icons.search, color: Colors.white),
                            onPressed: _toggleSearchMode,
                          ),
                          IconButton(
                            icon: const Icon(Icons.logout, color: Colors.white),
                            onPressed: _handleSignOut,
                          ),
                        ] else ...[
                          // Back Button
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: _toggleSearchMode,
                          ),
                          // Search Input
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              focusNode: _searchFocusNode,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'Search videos...',
                                hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                                border: InputBorder.none,
                                enabledBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                                ),
                                focusedBorder: const UnderlineInputBorder(
                                  borderSide: BorderSide(color: Colors.white),
                                ),
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _searchQuery = value;
                                });
                              },
                              textInputAction: TextInputAction.search,
                              onSubmitted: (query) {
                                if (query.isNotEmpty) {
                                  _addToRecentSearches(query, 'videos');
                                  _loadMoreVideos();
                                  _searchFocusNode.unfocus();
                                }
                              },
                            ),
                          ),
                          // Clear Button (only show when there's text)
                          if (_searchController.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.white),
                              onPressed: () {
                                _searchController.clear();
                                _handleSearch('');
                              },
                            ),
                        ],
                      ],
                    ),
                  ),
                  
                  // For You / Following Tabs (only show when not searching)
                  if (!_isSearchMode) ...[
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
                ],
              ),
            ),
          ),
          
          // Loading indicator at the bottom
          if (_isLoading)
            Positioned(
              top: 160, // Position it below the search bar and tabs
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Loading more videos...',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _updatePreloadWidgets(int currentIndex, List<Video> videos) {
    // Clear old preload widgets
    _preloadWidgets.clear();
    
    // Preload next videos
    for (var i = 1; i <= _preloadDistance; i++) {
      final preloadIndex = currentIndex + i;
      if (preloadIndex < videos.length) {
        final video = videos[preloadIndex];
        print('🎥 Preloading video: ${video.id}');
        
        // Add to preload widgets list
        _preloadWidgets.add(
          Offstage(
            offstage: true,
            child: VideoPlayerWidget(
              key: ValueKey('preload_${video.id}'),
              videoUrl: video.videoUrl,
              videoId: video.id,
              isPaused: true,
              shouldPreload: true,
            ),
          ),
        );
        
        // Start caching the video
        VideoCacheManager().getSingleFile(video.videoUrl).then((file) {
          print('🎥 Successfully preloaded video: ${video.id}');
        }).catchError((e) {
          print('🎥 Error preloading video ${video.id}: $e');
        });
      }
    }
    
    if (mounted) setState(() {});

    // Load more videos when we're near the end
    if (currentIndex >= videos.length - 5) {
      _loadMoreVideos();
    }
  }

  Future<void> _loadMoreVideos() async {
    if (_isLoading) return;  // Prevent multiple simultaneous loads
    
    setState(() {
      _isLoading = true;
    });

    try {
      print('🎥 Loading more videos with search query: $_searchQuery');
      final newVideos = await _videoService.fetchPexelsVideos(
        searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
        lastVideoTimestamp: _lastVideoTimestamp,
      );
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          _lastVideoTimestamp = newVideos.isNotEmpty ? newVideos.last.createdAt : _lastVideoTimestamp;
        });
      }

      print('🎥 Loaded ${newVideos.length} new videos');
      if (newVideos.isNotEmpty) {
        print('🎥 First video caption: ${newVideos.first.caption}');
        print('🎥 First video hashtags: ${newVideos.first.hashtags}');
      }
      
      // Only show snackbar during search
      if (mounted && newVideos.isNotEmpty && _searchQuery.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Loaded ${newVideos.length} new videos'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('🎥 Error loading more videos: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading videos: $e')),
        );
      }
    }
  }

  Future<void> _initializeFeed() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      print('🎥 Initializing feed...');
      // First check if we have any videos
      final snapshot = await _videoService.checkForVideos();
      if (!snapshot) {
        print('🎥 No videos found, loading initial Pexels videos');
        await _loadInitialPexelsVideos();
      } else {
        print('🎥 Existing videos found');
      }
    } catch (e) {
      print('🎥 Error initializing feed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadInitialPexelsVideos() async {
    try {
      print('🎥 Loading initial Pexels videos for empty feed');
      final videos = await _videoService.fetchPexelsVideos();  // No search query = popular videos
      print('🎥 Loaded ${videos.length} initial Pexels videos');
    } catch (e) {
      print('🎥 Error loading initial Pexels videos: $e');
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

  void _toggleSearchMode() {
    setState(() {
      _isSearchMode = !_isSearchMode;
      if (_isSearchMode) {
        _searchFocusNode.requestFocus();
      } else {
        _searchFocusNode.unfocus();
        _searchQuery = '';
        _searchController.clear();
      }
    });
  }

  void _handleSearch(String query) {
    if (query.isNotEmpty) {
      setState(() {
        _searchQuery = query;
      });
      _addToRecentSearches(query, 'videos');
      _loadMoreVideos();
      _searchFocusNode.unfocus();
    }
  }

  @override
  void dispose() {
    print('📱 FeedScreen dispose started');
    MainScreen.tabNotifier.removeListener(_handleTabChange);
    _routeObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    print('📱 Disposing page controllers');
    _forYouPageController.dispose();
    _followingPageController.dispose();
    
    // Clean up video cache when disposing
    VideoCacheManager().cleanupCache();
    
    _searchController.dispose();
    _searchFocusNode.dispose();
    
    super.dispose();
    print('📱 FeedScreen dispose completed');
  }
} 