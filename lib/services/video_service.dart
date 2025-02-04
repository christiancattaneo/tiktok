import 'dart:io' if (dart.library.html) 'dart:html';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import '../models/video.dart';
import '../models/comment.dart';
import 'package:path/path.dart' as path;

class VideoService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  // Upload video file to Firebase Storage
  Future<String?> uploadVideo(XFile videoFile, String userId) async {
    try {
      // Generate a unique ID for the video
      final videoId = _uuid.v4();
      
      // Debug logging
      print('Original video file path: ${videoFile.path}');
      print('Original video file name: ${videoFile.name}');
      
      // Get the extension from the file name for web support
      final extension = path.extension(videoFile.name).toLowerCase().replaceAll('.', '');
      print('Detected extension: $extension');
      
      // Map the extension to the correct content type
      final contentType = switch (extension) {
        'mp4' || 'mpeg4' || 'mpeg-4' || 'm4v' => 'video/mp4',
        'mov' || 'qt' || 'quicktime' => 'video/quicktime',
        'avi' => 'video/x-msvideo',
        'mkv' || 'matroska' => 'video/x-matroska',
        _ => 'video/mp4', // Default to mp4 if unknown
      };
      print('Using content type: $contentType');

      // Always store with .mp4 extension for better compatibility
      final videoRef = _storage.ref().child('videos/$userId/$videoId.mp4');
      print('Storage reference path: ${videoRef.fullPath}');

      // Upload the video file with metadata
      final metadata = SettableMetadata(
        contentType: contentType,
        customMetadata: {
          'originalExtension': extension,
          'uploadedAt': DateTime.now().toIso8601String(),
          'platform': kIsWeb ? 'web' : 'mobile',
        },
      );

      print('Starting upload with metadata: ${metadata.contentType}');
      
      // Read the file as bytes
      final Uint8List bytes = await videoFile.readAsBytes();
      print('File read as bytes. Size: ${bytes.length} bytes');

      // Upload the bytes
      final uploadTask = videoRef.putData(bytes, metadata);
      print('Upload task created');

      final snapshot = await uploadTask;
      print('Upload completed. Size: ${snapshot.totalBytes} bytes');

      // Get the download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();
      print('Download URL generated: $downloadUrl');

      return downloadUrl;
    } catch (e, stackTrace) {
      print('Error uploading video: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  // Create video metadata in Firestore
  Future<bool> createVideoMetadata({
    required String userId,
    required String videoUrl,
    required String caption,
    required String creatorUsername,
    String? creatorPhotoUrl,
    String? thumbnailUrl,
    List<String> hashtags = const [],
  }) async {
    try {
      final videoDoc = await _firestore.collection('videos').add({
        'userId': userId,
        'creatorUsername': creatorUsername,
        'creatorPhotoUrl': creatorPhotoUrl,
        'videoUrl': videoUrl,
        'caption': caption,
        'thumbnailUrl': thumbnailUrl,
        'hashtags': hashtags,
        'likes': 0,
        'views': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return videoDoc.id.isNotEmpty;
    } catch (e) {
      print('Error creating video metadata: $e');
      return false;
    }
  }

  // Get videos for feed
  Stream<List<Video>> getVideoFeed() {
    return _firestore
        .collection('videos')
        .orderBy('createdAt', descending: true)
        .limit(10)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => Video.fromFirestore(doc)).toList();
        });
  }

  // Delete video
  Future<bool> deleteVideo(String videoId, String userId) async {
    try {
      // Delete from Firestore
      await _firestore.collection('videos').doc(videoId).delete();

      // Delete from Storage
      await _storage.ref().child('videos/$userId/$videoId.mp4').delete();

      return true;
    } catch (e) {
      print('Error deleting video: $e');
      return false;
    }
  }

  // Get a single video by ID
  Future<Video?> getVideoById(String videoId) async {
    final doc = await _firestore.collection('videos').doc(videoId).get();
    if (doc.exists) {
      return Video.fromFirestore(doc);
    }
    return null;
  }

  // Update video like count
  Future<void> updateLikeCount(String videoId, int increment) async {
    await _firestore.collection('videos').doc(videoId).update({
      'likes': FieldValue.increment(increment),
    });
  }

  // Update video comment count
  Future<void> updateCommentCount(String videoId, int increment) async {
    await _firestore.collection('videos').doc(videoId).update({
      'commentCount': FieldValue.increment(increment),
    });
  }

  // Search videos by caption
  Future<List<Video>> searchVideos(String query) async {
    final snapshot = await _firestore
        .collection('videos')
        .where('caption', isGreaterThanOrEqualTo: query)
        .where('caption', isLessThan: query + 'z')
        .get();
    
    return snapshot.docs.map((doc) => Video.fromFirestore(doc)).toList();
  }

  // Toggle like on a video
  Future<bool> toggleLike(String videoId, String userId) async {
    final videoRef = _firestore.collection('videos').doc(videoId);
    final userLikesRef = _firestore.collection('users').doc(userId).collection('likes').doc(videoId);

    try {
      bool isLiked = false;
      await _firestore.runTransaction((transaction) async {
        final videoDoc = await transaction.get(videoRef);
        final userLikeDoc = await transaction.get(userLikesRef);

        if (!videoDoc.exists) {
          throw Exception('Video not found');
        }

        if (userLikeDoc.exists) {
          // User has already liked the video - remove like
          transaction.delete(userLikesRef);
          transaction.update(videoRef, {
            'likes': FieldValue.increment(-1),
          });
          isLiked = false;
        } else {
          // User hasn't liked the video - add like
          transaction.set(userLikesRef, {
            'timestamp': FieldValue.serverTimestamp(),
          });
          transaction.update(videoRef, {
            'likes': FieldValue.increment(1),
          });
          isLiked = true;
        }
      });
      return isLiked;
    } catch (e) {
      print('Error toggling like: $e');
      return false;
    }
  }

  // Check if user has liked a video
  Future<bool> hasUserLikedVideo(String videoId, String userId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('likes')
          .doc(videoId)
          .get();
      return doc.exists;
    } catch (e) {
      print('Error checking like status: $e');
      return false;
    }
  }

  // Get all videos liked by a user
  Stream<List<String>> getUserLikedVideoIds(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('likes')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toList());
  }

  // Add a comment to a video
  Future<Comment?> addComment({
    required String videoId,
    required String userId,
    required String username,
    required String text,
    String? userPhotoUrl,
  }) async {
    try {
      print('Creating comment with photo URL: $userPhotoUrl');
      
      final commentRef = _firestore
          .collection('videos')
          .doc(videoId)
          .collection('comments')
          .doc();

      final comment = Comment(
        id: commentRef.id,
        videoId: videoId,
        userId: userId,
        username: username,
        userPhotoUrl: userPhotoUrl,
        text: text,
        likes: 0,
        likedByCreator: false,
        createdAt: DateTime.now(),
      );

      print('Comment object created with photo URL: ${comment.userPhotoUrl}');
      final map = comment.toMap();
      print('Comment map for Firestore: $map');

      await commentRef.set(map);

      // Update comment count
      await _firestore.collection('videos').doc(videoId).update({
        'commentCount': FieldValue.increment(1),
      });

      return comment;
    } catch (e) {
      print('Error adding comment: $e');
      return null;
    }
  }

  // Get comments for a video
  Stream<List<Comment>> getVideoComments(String videoId) {
    return _firestore
        .collection('videos')
        .doc(videoId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
          print('Retrieved ${snapshot.docs.length} comments');
          final comments = snapshot.docs.map((doc) {
            final data = doc.data();
            print('Comment data from Firestore: $data');
            return Comment.fromFirestore(doc);
          }).toList();
          print('Mapped comments with photo URLs: ${comments.map((c) => c.userPhotoUrl)}');
          return comments;
        });
  }

  // Delete a comment
  Future<bool> deleteComment(String videoId, String commentId) async {
    try {
      await _firestore
          .collection('videos')
          .doc(videoId)
          .collection('comments')
          .doc(commentId)
          .delete();

      await _firestore.collection('videos').doc(videoId).update({
        'commentCount': FieldValue.increment(-1),
      });

      return true;
    } catch (e) {
      print('Error deleting comment: $e');
      return false;
    }
  }

  // Toggle like on a comment
  Future<bool> toggleCommentLike(String videoId, String commentId, String userId) async {
    final commentRef = _firestore
        .collection('videos')
        .doc(videoId)
        .collection('comments')
        .doc(commentId);
    final userLikesRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('commentLikes')
        .doc(commentId);
    final videoRef = _firestore.collection('videos').doc(videoId);

    try {
      bool isLiked = false;
      await _firestore.runTransaction((transaction) async {
        final commentDoc = await transaction.get(commentRef);
        final userLikeDoc = await transaction.get(userLikesRef);
        final videoDoc = await transaction.get(videoRef);

        if (!commentDoc.exists || !videoDoc.exists) {
          throw Exception('Comment or video not found');
        }

        final videoData = videoDoc.data() as Map<String, dynamic>;
        final isCreator = videoData['userId'] == userId;

        if (userLikeDoc.exists) {
          // User has already liked the comment - remove like
          transaction.delete(userLikesRef);
          transaction.update(commentRef, {
            'likes': FieldValue.increment(-1),
            if (isCreator) 'likedByCreator': false,
          });
          isLiked = false;
        } else {
          // User hasn't liked the comment - add like
          transaction.set(userLikesRef, {
            'timestamp': FieldValue.serverTimestamp(),
          });
          transaction.update(commentRef, {
            'likes': FieldValue.increment(1),
            if (isCreator) 'likedByCreator': true,
          });
          isLiked = true;
        }
      });
      return isLiked;
    } catch (e) {
      print('Error toggling comment like: $e');
      return false;
    }
  }

  // Check if user has liked a comment
  Future<bool> hasUserLikedComment(String commentId, String userId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('commentLikes')
          .doc(commentId)
          .get();
      return doc.exists;
    } catch (e) {
      print('Error checking comment like status: $e');
      return false;
    }
  }

  // Get videos created by a user
  Stream<List<Video>> getUserVideos(String userId) {
    return _firestore
        .collection('videos')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Video.fromFirestore(doc)).toList());
  }

  // Get videos liked by a user
  Stream<List<Video>> getUserLikedVideos(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('likes')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
          final videoIds = snapshot.docs.map((doc) => doc.id).toList();
          if (videoIds.isEmpty) return [];

          // Get all videos in a single batch
          final videoDocs = await Future.wait(
            videoIds.map((id) => _firestore.collection('videos').doc(id).get())
          );

          // Filter out any deleted videos and map to Video objects
          return videoDocs
              .where((doc) => doc.exists)
              .map((doc) => Video.fromFirestore(doc))
              .toList();
        });
  }

  Future<void> incrementViews(String videoId) async {
    try {
      await _firestore.collection('videos').doc(videoId).update({
        'views': FieldValue.increment(1),
      });
    } catch (e) {
      print('Error incrementing views: $e');
    }
  }
} 