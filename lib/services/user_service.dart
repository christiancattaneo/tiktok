import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../models/user.dart' as app_models;
import 'package:firebase_auth/firebase_auth.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Get user by ID as a stream for real-time updates
  Stream<app_models.User?> getUserStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) {
          if (doc.exists) {
            return app_models.User.fromFirestore(doc);
          }
          return null;
        });
  }

  // Get user by ID (one-time fetch)
  Future<app_models.User?> getUserById(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return app_models.User.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting user by ID: $e');
      return null;
    }
  }

  // Follow a user
  Future<bool> followUser(String currentUserId, String targetUserId) async {
    try {
      final batch = _firestore.batch();
      
      // Add to current user's following collection
      final followingRef = _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('following')
          .doc(targetUserId);
      
      // Add to target user's followers collection
      final followerRef = _firestore
          .collection('users')
          .doc(targetUserId)
          .collection('followers')
          .doc(currentUserId);
      
      // Update follower counts
      final currentUserRef = _firestore.collection('users').doc(currentUserId);
      final targetUserRef = _firestore.collection('users').doc(targetUserId);

      batch.set(followingRef, {
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      batch.set(followerRef, {
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      batch.update(currentUserRef, {
        'followingCount': FieldValue.increment(1),
      });
      
      batch.update(targetUserRef, {
        'followersCount': FieldValue.increment(1),
      });

      await batch.commit();
      return true;
    } catch (e) {
      print('Error following user: $e');
      return false;
    }
  }

  // Unfollow a user
  Future<bool> unfollowUser(String currentUserId, String targetUserId) async {
    try {
      final batch = _firestore.batch();
      
      // Remove from current user's following collection
      final followingRef = _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('following')
          .doc(targetUserId);
      
      // Remove from target user's followers collection
      final followerRef = _firestore
          .collection('users')
          .doc(targetUserId)
          .collection('followers')
          .doc(currentUserId);
      
      // Update follower counts
      final currentUserRef = _firestore.collection('users').doc(currentUserId);
      final targetUserRef = _firestore.collection('users').doc(targetUserId);

      batch.delete(followingRef);
      batch.delete(followerRef);
      
      batch.update(currentUserRef, {
        'followingCount': FieldValue.increment(-1),
      });
      
      batch.update(targetUserRef, {
        'followersCount': FieldValue.increment(-1),
      });

      await batch.commit();
      return true;
    } catch (e) {
      print('Error unfollowing user: $e');
      return false;
    }
  }

  // Check if user is following another user
  Future<bool> isFollowing(String currentUserId, String targetUserId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('following')
          .doc(targetUserId)
          .get();
      return doc.exists;
    } catch (e) {
      print('Error checking follow status: $e');
      return false;
    }
  }

  // Get user's followers
  Stream<List<app_models.User>> getUserFollowers(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('followers')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
          final userDocs = await Future.wait(
            snapshot.docs.map((doc) => 
              _firestore.collection('users').doc(doc.id).get()
            )
          );
          return userDocs
              .where((doc) => doc.exists)
              .map((doc) => app_models.User.fromFirestore(doc))
              .toList();
        });
  }

  // Get user's following
  Stream<List<app_models.User>> getUserFollowing(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('following')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
          final userDocs = await Future.wait(
            snapshot.docs.map((doc) => 
              _firestore.collection('users').doc(doc.id).get()
            )
          );
          return userDocs
              .where((doc) => doc.exists)
              .map((doc) => app_models.User.fromFirestore(doc))
              .toList();
        });
  }

  Future<bool> updateProfilePhoto(String userId, XFile image) async {
    try {
      // Debug logging for authentication
      final auth = FirebaseAuth.instance;
      final currentUser = auth.currentUser;
      print('Current user: ${currentUser?.uid}');
      print('Attempting to upload for userId: $userId');
      
      // Upload image to Firebase Storage
      final ref = _storage.ref().child('profile_photos/$userId.jpg');
      
      // Read the file as bytes
      final bytes = await image.readAsBytes();
      
      // Upload with metadata to trigger Cloud Function
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'uploadedAt': DateTime.now().toIso8601String(),
          'requiresProcessing': 'true', // Flag for Cloud Function to process image
          'userId': userId,
          'type': 'profile_photo'
        },
      );
      
      print('Starting upload to path: ${ref.fullPath}');
      
      // Upload the image
      await ref.putData(bytes, metadata);
      
      // Don't get the download URL - Cloud Function will handle updating the user document
      // Just return true to indicate successful upload
      return true;
    } catch (e) {
      print('Error updating profile photo: $e');
      return false;
    }
  }

  // Update user's bio
  Future<bool> updateBio(String userId, String bio) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'bio': bio,
      });
      return true;
    } catch (e) {
      print('Error updating bio: $e');
      return false;
    }
  }
} 