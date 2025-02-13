import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class VideoCacheManager extends CacheManager {
  static const key = 'videoCacheKey';
  static const maxAgeCacheObject = Duration(days: 7);
  static const maxNrOfCacheObjects = 20;  // Limit cache to 20 videos
  
  static final VideoCacheManager _instance = VideoCacheManager._();
  factory VideoCacheManager() => _instance;

  VideoCacheManager._() : super(
    Config(
      key,
      stalePeriod: maxAgeCacheObject,
      maxNrOfCacheObjects: maxNrOfCacheObjects,
      repo: JsonCacheInfoRepository(databaseName: key),
      fileService: HttpFileService(),
    ),
  );

  Future<void> cleanupCache() async {
    try {
      await emptyCache();
      print('📱 Video cache cleaned successfully');
    } catch (e) {
      print('📱 Error cleaning video cache: $e');
    }
  }
} 