import 'dart:io' if (dart.library.html) 'dart:html';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/app_auth_provider.dart';
import '../services/video_service.dart';
import '../services/hashtag_service.dart';
import 'package:path/path.dart' as path;
import 'package:video_player/video_player.dart';
import '../services/trend_service.dart';

class UploadVideoScreen extends StatefulWidget {
  const UploadVideoScreen({super.key});

  @override
  State<UploadVideoScreen> createState() => _UploadVideoScreenState();
}

class _UploadVideoScreenState extends State<UploadVideoScreen> {
  final _videoService = VideoService();
  final _trendService = TrendService();
  final _hashtagService = HashtagService();
  final _captionController = TextEditingController();
  final _hashtagController = TextEditingController();
  XFile? _videoFile;
  VideoPlayerController? _previewController;
  bool _isUploading = false;
  bool _isGeneratingHashtags = false;
  List<String> _aiGeneratedHashtags = [];
  double _uploadProgress = 0.0;
  String _uploadStatus = '';
  List<String> _hashtags = [];
  List<Map<String, dynamic>> _trendingHashtags = [];
  bool _isLoadingInsights = false;

  // List of supported video formats with their common variations
  final _supportedFormats = {
    'mp4': ['mp4', 'mpeg4', 'mpeg-4', 'm4v'],
    'mov': ['mov', 'qt', 'quicktime'],
    'avi': ['avi'],
    'mkv': ['mkv', 'matroska'],
  };

  @override
  void initState() {
    super.initState();
    _loadTrendingHashtags();
  }

  @override
  void dispose() {
    _previewController?.dispose();
    _captionController.dispose();
    _hashtagController.dispose();
    super.dispose();
  }

  Future<void> _initializePreview() async {
    if (_videoFile == null) return;

    // Dispose previous controller if exists
    await _previewController?.dispose();
    
    // Create new controller
    _previewController = VideoPlayerController.file(File(_videoFile!.path));
    
    try {
      await _previewController!.initialize();
      // Get the first frame as preview
      await _previewController!.setVolume(0.0);
      await _previewController!.seekTo(Duration.zero);
      await _previewController!.pause();
      if (mounted) setState(() {});
    } catch (e) {
      print('Error initializing video preview: $e');
    }
  }

  Future<void> _pickVideo() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 5),
      );

      if (pickedFile != null) {
        // Check file size
        final bytes = await pickedFile.readAsBytes();
        final sizeInMB = bytes.length / (1024 * 1024);
        
        if (sizeInMB > 25) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Video is too large. Please choose a video under 25MB for better playback.'),
                duration: Duration(seconds: 4),
              ),
            );
          }
          return;
        }

        // Get the extension from the file name for web support
        final extension = path.extension(pickedFile.name).toLowerCase().replaceAll('.', '');
        
        // Check if format is supported
        final isSupported = _supportedFormats.values.any((formats) => formats.contains(extension));
        if (!isSupported) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Unsupported video format: .$extension'),
                    const Text('Please use one of these formats:'),
                    Text(_supportedFormats.keys.join(', ')),
                  ],
                ),
                duration: const Duration(seconds: 4),
              ),
            );
          }
          return;
        }

        setState(() {
          _videoFile = pickedFile;
          _uploadStatus = 'Video selected: ${path.basename(pickedFile.name)}';
        });

        // Initialize video preview
        await _initializePreview();

        // Show recommendation if video is large
        if (sizeInMB > 15) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Tip: Consider compressing your video for faster upload and better playback.'),
                duration: Duration(seconds: 4),
              ),
            );
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking video: ${e.toString()}')),
      );
    }
  }

  void _addHashtag() {
    final hashtag = _hashtagController.text.trim();
    if (hashtag.isNotEmpty) {
      setState(() {
        _hashtags.add(hashtag);
        _hashtagController.clear();
      });
    }
  }

  Future<void> _loadTrendingHashtags() async {
    try {
      setState(() {
        _isLoadingInsights = true;
      });
      
      final hashtags = await _trendService.getTrendingHashtags();
      
      if (mounted) {
        setState(() {
          _trendingHashtags = hashtags;
          _isLoadingInsights = false;
        });
      }
    } catch (e) {
      print('Error loading insights: $e');
      if (mounted) {
        setState(() {
          _isLoadingInsights = false;
        });
      }
    }
  }

  Future<void> _generateAIHashtags() async {
    if (_videoFile == null) return;

    setState(() {
      _isGeneratingHashtags = true;
    });

    try {
      // Use the video file path for analysis
      final hashtags = await _hashtagService.generateHashtags(
        _videoFile!.path,
        _captionController.text,
      );

      if (mounted) {
        setState(() {
          _aiGeneratedHashtags = hashtags;
          _isGeneratingHashtags = false;
        });
      }
    } catch (e) {
      print('Error generating AI hashtags: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating hashtags: $e')),
        );
        setState(() {
          _isGeneratingHashtags = false;
        });
      }
    }
  }

  Future<void> _uploadVideo() async {
    if (_videoFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a video first')),
      );
      return;
    }

    if (_captionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a caption')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
      _uploadStatus = 'Preparing to upload...';
    });

    try {
      final userId = context.read<AppAuthProvider>().userId;
      if (userId == null) {
        throw Exception('User not logged in');
      }

      final username = context.read<AppAuthProvider>().user?.username;
      if (username == null) {
        throw Exception('Username not found');
      }

      setState(() {
        _uploadStatus = 'Uploading video...';
      });

      // Upload video file and generate thumbnail
      final uploadResult = await _videoService.uploadVideo(_videoFile!, userId);
      if (uploadResult == null) {
        throw Exception('Failed to upload video');
      }

      setState(() {
        _uploadStatus = 'Creating video post...';
        _uploadProgress = 0.8;
      });

      // Create video metadata with thumbnail
      final success = await _videoService.createVideoMetadata(
        userId: userId,
        videoUrl: uploadResult['videoUrl']!,
        thumbnailUrl: uploadResult['thumbnailUrl'],
        caption: _captionController.text.trim(),
        hashtags: _hashtags,
        creatorUsername: username,
      );

      if (success) {
        setState(() {
          _uploadStatus = 'Upload complete!';
          _uploadProgress = 1.0;
        });

        // Wait a moment to show the success state
        await Future.delayed(const Duration(seconds: 1));

        if (mounted) {
          // Pop back to the feed
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/',
            (route) => false,
          );
          
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Video uploaded successfully!'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        throw Exception('Failed to create video metadata');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _uploadStatus = 'Upload failed: ${e.toString()}';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading video: ${e.toString()}'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Video'),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_videoFile == null)
                  Card(
                    child: InkWell(
                      onTap: _isUploading ? null : _pickVideo,
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.video_library, size: 48),
                            SizedBox(height: 16),
                            Text('Select Video'),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  Card(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (_previewController?.value.isInitialized ?? false)
                          AspectRatio(
                            aspectRatio: _previewController!.value.aspectRatio,
                            child: VideoPlayer(_previewController!),
                          )
                        else
                          const Padding(
                            padding: EdgeInsets.all(32.0),
                            child: CircularProgressIndicator(),
                          ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: _isUploading
                                ? null
                                : () {
                                    setState(() {
                                      _videoFile = null;
                                      _uploadStatus = '';
                                    });
                                    _previewController?.dispose();
                                    _previewController = null;
                                  },
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                
                // Video Details Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Video Details',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _captionController,
                          enabled: !_isUploading,
                          decoration: const InputDecoration(
                            labelText: 'Caption',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.title),
                          ),
                          maxLines: 3,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => FocusScope.of(context).unfocus(),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _hashtagController,
                                enabled: !_isUploading,
                                decoration: const InputDecoration(
                                  labelText: 'Add hashtag',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.tag),
                                ),
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) {
                                  _addHashtag();
                                  FocusScope.of(context).unfocus();
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.add_circle),
                              onPressed: _isUploading ? null : _addHashtag,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: _hashtags.map((tag) => Chip(
                            label: Text('#$tag'),
                            onDeleted: _isUploading ? null : () {
                              setState(() {
                                _hashtags.remove(tag);
                              });
                            },
                          )).toList(),
                        ),
                        
                        // Trending Hashtags
                        if (_trendingHashtags.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 8),
                          Text(
                            'Trending Hashtags',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: _trendingHashtags.map((trend) => ActionChip(
                              label: Text(
                                '#${trend['tag']}',
                                style: TextStyle(
                                  color: trend['score'] > 0.8 
                                      ? Colors.red 
                                      : null,
                                ),
                              ),
                              avatar: trend['score'] > 0.8 
                                  ? const Icon(Icons.local_fire_department, size: 16)
                                  : null,
                              onPressed: () {
                                if (!_hashtags.contains(trend['tag'])) {
                                  setState(() {
                                    _hashtags.add(trend['tag']);
                                  });
                                }
                              },
                            )).toList(),
                          ),
                        ],

                        // AI Generated Hashtags
                        if (_videoFile != null) ...[
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'AI Generated Hashtags',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              if (!_isGeneratingHashtags)
                                IconButton(
                                  icon: const Icon(Icons.refresh),
                                  onPressed: _generateAIHashtags,
                                  tooltip: 'Regenerate hashtags',
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (_isGeneratingHashtags)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Column(
                                  children: [
                                    CircularProgressIndicator(),
                                    SizedBox(height: 8),
                                    Text('Analyzing video content...'),
                                  ],
                                ),
                              ),
                            )
                          else if (_aiGeneratedHashtags.isEmpty)
                            Center(
                              child: TextButton.icon(
                                icon: const Icon(Icons.auto_awesome),
                                label: const Text('Generate AI Hashtags'),
                                onPressed: _generateAIHashtags,
                              ),
                            )
                          else
                            Wrap(
                              spacing: 8,
                              children: _aiGeneratedHashtags.map((tag) => ActionChip(
                                avatar: const Icon(Icons.auto_awesome, size: 16),
                                label: Text('#$tag'),
                                onPressed: () {
                                  if (!_hashtags.contains(tag)) {
                                    setState(() {
                                      _hashtags.add(tag);
                                    });
                                  }
                                },
                              )).toList(),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isUploading)
            Container(
              color: Colors.black54,
              child: Center(
                child: Card(
                  margin: const EdgeInsets.all(32),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 20),
                        Text(
                          _uploadStatus,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (_uploadProgress > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: LinearProgressIndicator(
                              value: _uploadProgress,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      // Add padding at the bottom to avoid navigation bar
      bottomNavigationBar: !_isUploading ? Padding(  // Only show if not uploading
        padding: const EdgeInsets.only(bottom: 90),  // Space for navigation bar
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ElevatedButton(
            onPressed: _uploadVideo,  // Removed null check since button won't show when uploading
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(12),
            ),
            child: const Row(  // Simplified since we only show this when not uploading
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_upload),
                SizedBox(width: 8),
                Text('Upload Video'),
              ],
            ),
          ),
        ),
      ) : null,  // Return null when uploading to hide the button
    );
  }
} 