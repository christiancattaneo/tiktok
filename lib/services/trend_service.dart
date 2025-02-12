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
      print('🏷️ [TrendService] Starting getTrendingHashtags request');
      
      final callable = _functions.httpsCallable('getTrendingHashtags');
      print('🏷️ [TrendService] Calling Cloud Function...');
      
      final result = await callable.call();
      print('🏷️ [TrendService] Got response: ${result.data}');
      
      if (result.data == null || result.data['hashtags'] == null) {
        print('❌ [TrendService] No hashtags data in response');
        return [];
      }

      final List<dynamic> rawHashtags = result.data['hashtags'] as List<dynamic>;
      final hashtags = rawHashtags.map((item) {
        return {
          'tag': item['tag'] as String,
          'count': item['count'] as int,
          'engagement': item['engagement'] as int,
          'score': (item['score'] as num?)?.toDouble() ?? 0.5,
        };
      }).toList();
      
      print('🏷️ [TrendService] Parsed ${hashtags.length} hashtags');
      return hashtags;
    } catch (e, stackTrace) {
      print('❌ [TrendService] Error getting trending hashtags: $e');
      print('❌ [TrendService] Stack trace: $stackTrace');
      return [];
    }
  }
} 