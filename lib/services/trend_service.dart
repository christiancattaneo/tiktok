import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/video.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TrendService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'us-central1');
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get trending hashtags based on engagement metrics
  Future<List<Map<String, dynamic>>> getTrendingHashtags() async {
    try {
      // Check authentication
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        print('❌ [TrendService] User not authenticated for getTrendingHashtags');
        return [];
      }
      
      final callable = _functions.httpsCallable('getTrendingHashtags');
      final result = await callable.call();
      
      return List<Map<String, dynamic>>.from(result.data['hashtags'] ?? []);
    } catch (e) {
      print('Error getting trending hashtags: $e');
      return [];
    }
  }

  // Get optimal video length recommendations based on user engagement
  Future<Map<String, dynamic>> getOptimalVideoLength() async {
    try {
      // Check authentication
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        print('❌ [TrendService] User not authenticated for getOptimalVideoLength');
        return {};
      }
      
      final callable = _functions.httpsCallable('getOptimalVideoLength');
      final result = await callable.call();
      
      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      print('Error getting optimal video length: $e');
      return {};
    }
  }

  // Get personalized hashtag recommendations based on user's content
  Future<List<String>> getPersonalizedHashtags(String videoCaption) async {
    try {
      print('🏷️ [TrendService] Starting getPersonalizedHashtags request');
      print('🏷️ [TrendService] Caption: $videoCaption');
      
      // Check authentication state
      final currentUser = _auth.currentUser;
      print('🏷️ [TrendService] Current user: ${currentUser?.uid ?? 'Not authenticated'}');
      
      if (currentUser == null) {
        print('❌ [TrendService] No authenticated user found');
        return [];
      }

      // Force token refresh
      print('🏷️ [TrendService] Forcing token refresh...');
      try {
        final idToken = await currentUser.getIdToken(true);
        print('🏷️ [TrendService] Token refreshed successfully: ${idToken != null && idToken.isNotEmpty ? idToken.substring(0, 10) : "empty"}...');
      } catch (e) {
        print('❌ [TrendService] Error refreshing token: $e');
      }

      // Log Firebase Functions configuration
      print('🏷️ [TrendService] Firebase Functions initialized');
      
      final callable = _functions.httpsCallable(
        'getPersonalizedHashtags',
        options: HttpsCallableOptions(
          timeout: const Duration(seconds: 30),
        ),
      );
      print('🏷️ [TrendService] Created callable reference');
      
      print('🏷️ [TrendService] Calling Cloud Function...');
      final result = await callable.call({
        'caption': videoCaption,
        'uid': currentUser.uid, // Add user ID to payload
      });
      print('🏷️ [TrendService] Received response from Cloud Function');
      print('🏷️ [TrendService] Raw response data: ${result.data}');
      
      if (result.data == null) {
        print('❌ [TrendService] Response data is null');
        return [];
      }

      if (result.data['hashtags'] == null) {
        print('❌ [TrendService] Response hashtags field is null');
        return [];
      }

      final hashtags = List<String>.from(result.data['hashtags']);
      print('🏷️ [TrendService] Parsed hashtags: $hashtags');
      return hashtags;
    } on FirebaseFunctionsException catch (e, stackTrace) {
      print('❌ [TrendService] Firebase Functions Error:');
      print('❌ [TrendService] Code: ${e.code}');
      print('❌ [TrendService] Message: ${e.message}');
      print('❌ [TrendService] Details: ${e.details}');
      print('❌ [TrendService] Stack trace: $stackTrace');
      return [];
    } catch (e, stackTrace) {
      print('❌ [TrendService] Error getting personalized hashtags:');
      print('❌ [TrendService] Error: $e');
      print('❌ [TrendService] Stack trace: $stackTrace');
      return [];
    }
  }

  // Get engagement predictions for a video
  Future<Map<String, dynamic>> predictEngagement(String videoId) async {
    try {
      final callable = _functions.httpsCallable('predictEngagement');
      final result = await callable.call({
        'videoId': videoId,
      });
      
      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      print('Error predicting engagement: $e');
      return {};
    }
  }
} 