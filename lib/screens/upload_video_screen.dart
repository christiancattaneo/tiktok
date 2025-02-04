import 'dart:io' if (dart.library.html) 'dart:html';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/video_service.dart';
import 'package:path/path.dart' as path;

class UploadVideoScreen extends StatefulWidget {
  const UploadVideoScreen({super.key});

  @override
  State<UploadVideoScreen> createState() => _UploadVideoScreenState();
}

class _UploadVideoScreenState extends State<UploadVideoScreen> {
  final _videoService = VideoService();
  final _captionController = TextEditingController();
  final _hashtagController = TextEditingController();
  XFile? _videoFile;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String _uploadStatus = '';
  List<String> _hashtags = [];

  // List of supported video formats with their common variations
  final _supportedFormats = {
    'mp4': ['mp4', 'mpeg4', 'mpeg-4', 'm4v'],
    'mov': ['mov', 'qt', 'quicktime'],
    'avi': ['avi'],
    'mkv': ['mkv', 'matroska'],
  };

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
      final userId = context.read<AuthProvider>().userId;
      if (userId == null) {
        throw Exception('User not logged in');
      }

      final username = context.read<AuthProvider>().user?.username;
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
  void dispose() {
    _captionController.dispose();
    _hashtagController.dispose();
    super.dispose();
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
                          children: [
                            Icon(
                              Icons.video_library,
                              size: 64,
                              color: Theme.of(context).primaryColor,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Select Video',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap to choose a video from your gallery',
                              style: Theme.of(context).textTheme.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  Card(
                    child: AspectRatio(
                      aspectRatio: 9 / 16,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            color: Colors.black87,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.video_file,
                                  size: 64,
                                  color: Colors.white,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  path.basename(_videoFile!.name),
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                          if (!_isUploading)
                            Positioned(
                              bottom: 8,
                              right: 8,
                              child: IconButton(
                                icon: const Icon(Icons.edit),
                                color: Colors.white,
                                onPressed: _pickVideo,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
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
                                onSubmitted: (_) => _addHashtag(),
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
      bottomNavigationBar: BottomAppBar(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: ElevatedButton(
            onPressed: _isUploading ? null : _uploadVideo,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(12),
            ),
            child: _isUploading
              ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
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
                    Text('Uploading...'),
                  ],
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cloud_upload),
                    SizedBox(width: 8),
                    Text('Upload Video'),
                  ],
                ),
          ),
        ),
      ),
    );
  }
} 