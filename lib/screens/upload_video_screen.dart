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
        // Debug logging
        print('Original file path: ${pickedFile.path}');
        print('Original file name: ${pickedFile.name}');
        
        // Get the extension from the file name for web support
        String? extension;
        if (pickedFile.name != null) {
          extension = path.extension(pickedFile.name!).toLowerCase().replaceAll('.', '');
        } else {
          extension = path.extension(pickedFile.path).toLowerCase().replaceAll('.', '');
        }
        print('Detected extension: $extension');
        
        // Debug logging for supported formats
        print('Supported formats: $_supportedFormats');
        
        // Check if the file format is supported
        bool isSupported = false;
        String? matchedFormat;
        if (extension.isNotEmpty) {  // Only check if we got an extension
          for (var entry in _supportedFormats.entries) {
            if (entry.value.contains(extension)) {
              isSupported = true;
              matchedFormat = entry.key;
              break;
            }
          }
        }
        
        print('Is supported: $isSupported, Matched format: $matchedFormat');
        
        if (!isSupported) {
          if (mounted) {
            // Show more detailed error message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Unsupported video format: ${extension.isEmpty ? "unknown" : ".$extension"}'),
                    const SizedBox(height: 4),
                    const Text('Supported formats:'),
                    Text(_supportedFormats.entries
                        .map((e) => '${e.key} (${e.value.join(", ")})')
                        .join('\n')),
                  ],
                ),
                duration: const Duration(seconds: 6),
              ),
            );
          }
          return;
        }

        // Check file size for both web and mobile
        try {
          final bytes = await pickedFile.readAsBytes();
          final sizeInMB = bytes.length / (1024 * 1024);
          
          if (sizeInMB > 100) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Video file is too large. Maximum size is 100MB'),
                ),
              );
            }
            return;
          }

          setState(() {
            _videoFile = pickedFile;
          });
        } catch (e) {
          print('Error checking file size: $e');
          // If we can't check the size, still allow the upload
          setState(() {
            _videoFile = pickedFile;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking video: ${e.toString()}'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
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

      // Upload video file
      final videoUrl = await _videoService.uploadVideo(_videoFile!, userId);
      if (videoUrl == null) {
        throw Exception('Failed to upload video');
      }

      // Create video metadata
      final success = await _videoService.createVideoMetadata(
        userId: userId,
        videoUrl: videoUrl,
        caption: _captionController.text.trim(),
        hashtags: _hashtags,
        creatorUsername: username,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video uploaded successfully!')),
        );
        Navigator.pop(context);
      } else {
        throw Exception('Failed to create video metadata');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading video: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isUploading = false;
      });
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isUploading)
              Column(
                children: [
                  const LinearProgressIndicator(),
                  const SizedBox(height: 8),
                  Text(
                    'Uploading video...',
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                ],
              )
            else if (_videoFile == null)
              Card(
                child: InkWell(
                  onTap: _pickVideo,
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
                        child: const Icon(
                          Icons.video_file,
                          size: 64,
                          color: Colors.white,
                        ),
                      ),
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
                            decoration: const InputDecoration(
                              labelText: 'Add hashtag',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.tag),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.add_circle),
                          onPressed: _addHashtag,
                          color: Theme.of(context).primaryColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: _hashtags.map((hashtag) => Chip(
                        label: Text(hashtag),
                        onDeleted: () {
                          setState(() {
                            _hashtags.remove(hashtag);
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
      bottomNavigationBar: _videoFile != null
        ? SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: _isUploading ? null : _uploadVideo,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                child: _isUploading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
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
          )
        : null,
    );
  }
} 