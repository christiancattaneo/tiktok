import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/services.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class HashtagService {
  static final HashtagService _instance = HashtagService._internal();
  factory HashtagService() => _instance;
  HashtagService._internal();

  String get _geminiApiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
  String get _pexelsApiKey => dotenv.env['PEXELS_API_KEY'] ?? '';
  final String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';

  Future<List<String>> generateHashtags(String videoPath, String description) async {
    try {
      String? imageData;
      
      // Extract frames from the video, regardless of source
      final frameBytes = await _extractVideoFrame(videoPath);
      if (frameBytes != null) {
        imageData = base64Encode(frameBytes);
        print('🎥 Successfully created frame collage from video');
      }

      if (imageData != null) {
        final response = await _callGeminiVision(imageData, description);
        if (response != null && response.isNotEmpty) {
          return _parseHashtags(response);
        }
      }

      // Fallback to text-based analysis
      return await _generateTextHashtags(description);
    } catch (e) {
      print('🏷️ Error generating hashtags: $e');
      return ['video'];
    }
  }

  Future<Uint8List?> _extractVideoFrame(String videoPath) async {
    try {
      String localPath = videoPath;
      File? tempFile;

      // If videoPath is a URL, download it to a temporary file
      if (videoPath.startsWith('http')) {
        print('🎥 Downloading video to temporary file');
        final response = await http.get(Uri.parse(videoPath));
        if (response.statusCode != 200) {
          throw Exception('Failed to download video: ${response.statusCode}');
        }

        // Create temporary file
        final tempDir = await getTemporaryDirectory();
        tempFile = File('${tempDir.path}/temp_${DateTime.now().millisecondsSinceEpoch}.mp4');
        await tempFile.writeAsBytes(response.bodyBytes);
        localPath = tempFile.path;
        print('🎥 Video downloaded to: $localPath');
      }

      try {
        // Get video duration
        final intervals = 6; // Number of frames to capture
        List<Uint8List> frames = [];

        // Try to capture frames at regular intervals
        for (var i = 0; i < intervals; i++) {
          try {
            final frameBytes = await VideoThumbnail.thumbnailData(
              video: localPath,
              imageFormat: ImageFormat.JPEG,
              maxWidth: 512,
              timeMs: (i + 1) * 1000, // Capture a frame every second for first 6 seconds
              quality: 85,
            );
            
            if (frameBytes != null) {
              frames.add(frameBytes);
              print('🎥 Successfully captured frame $i');
            }
          } catch (e) {
            print('🎬 Error capturing frame $i: $e');
          }
        }

        // Clean up temporary file if we created one
        if (tempFile != null) {
          await tempFile.delete();
          print('🎥 Deleted temporary file');
        }

        if (frames.isEmpty) {
          print('🎬 No frames captured from video');
          return null;
        }

        // Create a collage from the frames
        return _createCollage(frames);
      } finally {
        // Ensure temporary file is cleaned up even if an error occurs
        if (tempFile != null && await tempFile.exists()) {
          await tempFile.delete();
          print('🎥 Cleaned up temporary file');
        }
      }
    } catch (e) {
      print('🎬 Error extracting video frames: $e');
      return null;
    }
  }

  Future<Uint8List?> _compressImage(ui.Image image) async {
    try {
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;
      
      // Convert to img.Image for processing
      final imgLib = img.decodeImage(byteData.buffer.asUint8List());
      if (imgLib == null) return null;
      
      // Compress to JPEG
      return Uint8List.fromList(img.encodeJpg(imgLib, quality: 85));
    } catch (e) {
      print('🗜️ Error compressing image: $e');
      return null;
    }
  }

  Future<Uint8List?> _createCollage(List<Uint8List> frames) async {
    try {
      // Decode all frames
      final List<img.Image?> images = frames
          .map((bytes) => img.decodeImage(bytes))
          .where((img) => img != null)
          .toList();
      
      if (images.isEmpty) return null;
      
      // Calculate collage dimensions
      final rows = 2;
      final cols = 3;
      final frameWidth = 512;
      final frameHeight = 512;
      
      // Create blank canvas
      final collage = img.Image(
        width: frameWidth * cols,
        height: frameHeight * rows,
      );
      
      // Place frames in grid
      for (var i = 0; i < images.length && i < rows * cols; i++) {
        final row = i ~/ cols;
        final col = i % cols;
        final frame = images[i];
        
        if (frame != null) {
          // Resize frame to fit grid
          final resized = img.copyResize(
            frame,
            width: frameWidth,
            height: frameHeight,
          );
          
          // Copy frame onto collage
          img.compositeImage(
            collage,
            resized,
            dstX: col * frameWidth,
            dstY: row * frameHeight,
          );
        }
      }
      
      // Compress the collage to stay under 20MB
      var quality = 85;
      while (true) {
        final jpegBytes = img.encodeJpg(collage, quality: quality);
        if (jpegBytes.length <= 20 * 1024 * 1024 || quality <= 30) {
          return Uint8List.fromList(jpegBytes);
        }
        quality -= 10;
      }
    } catch (e) {
      print('🎬 Error creating collage: $e');
      return null;
    }
  }

  String? _extractPexelsVideoId(String url) {
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      
      // Handle different Pexels URL formats
      if (segments.contains('video-files')) {
        return segments[segments.indexOf('video-files') - 1];
      } else if (segments.contains('videos')) {
        return segments[segments.indexOf('videos') + 1];
      }
      
      return null;
    } catch (e) {
      print('🔍 Error extracting Pexels video ID: $e');
      return null;
    }
  }

  Future<List<String>> _generateTextHashtags(String description) async {
    try {
      final response = await _callGeminiText(description);
      if (response != null && response.isNotEmpty) {
        return _parseHashtags(response);
      }
    } catch (e) {
      print('📝 Error generating text hashtags: $e');
    }
    return ['video'];
  }

  List<String> _parseHashtags(String text) {
    try {
      return text
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .map((tag) => tag.toString())
          .toList()
          .cast<String>();
    } catch (e) {
      print('🏷️ Error parsing hashtags: $e');
      return ['video'];
    }
  }

  Future<String?> _callGeminiVision(String imageData, String description) async {
    if (_geminiApiKey.isEmpty) {
      print('🔑 No Gemini API key found');
      return null;
    }

    try {
      final uri = Uri.parse('$_baseUrl?key=$_geminiApiKey');
      final prompt = '''
      Analyze these video frames and generate relevant hashtags that describe the video content.
      The image shows 6 frames from different parts of the video to give you a better understanding of its content.
      Additional context: $description
      
      Return only a comma-separated list of hashtags without # symbols.
      Example format: trending, viral, dance, music
      
      Consider:
      1. The overall theme or story
      2. Actions or movements shown
      3. Setting and environment
      4. Style and mood
      5. Any recurring elements across frames
      ''';

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'contents': [{
            'parts': [
              {'text': prompt},
              {
                'inlineData': {
                  'mimeType': 'image/jpeg',
                  'data': imageData
                }
              }
            ]
          }],
          'generationConfig': {
            'temperature': 0.7,
            'topK': 40,
            'topP': 0.95,
            'maxOutputTokens': 1024,
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['candidates'][0]['content']['parts'][0]['text'];
      } else {
        print('🖼️ Error from Gemini Vision API: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('🖼️ Error calling Gemini Vision API: $e');
      return null;
    }
  }

  Future<String?> _callGeminiText(String description) async {
    if (_geminiApiKey.isEmpty) {
      print('🔑 No Gemini API key found');
      return null;
    }

    try {
      final uri = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=$_geminiApiKey');
      
      final prompt = '''
      Generate 5-10 relevant hashtags for this video:
      Description: $description

      Return only a comma-separated list of hashtags without # symbols.
      Example format: trending, viral, dance, music
      ''';

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'contents': [{
            'parts': [{
              'text': prompt
            }]
          }],
          'generationConfig': {
            'temperature': 0.7,
            'topK': 40,
            'topP': 0.95,
            'maxOutputTokens': 1024,
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['candidates'][0]['content']['parts'][0]['text'];
      } else {
        print('📝 Error from Gemini Text API: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('📝 Error calling Gemini Text API: $e');
      return null;
    }
  }
} 