import 'dart:io';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class VideoCacheManager extends CacheManager {
  static const key = 'videoCache';
  static const maxAgeCacheObject = Duration(days: 1);
  static const maxNrOfCacheObjects = 20;
  
  static VideoCacheManager? _instance;
  
  factory VideoCacheManager() {
    _instance ??= VideoCacheManager._();
    return _instance!;
  }
  
  VideoCacheManager._() : super(
    Config(
      key,
      stalePeriod: maxAgeCacheObject,
      maxNrOfCacheObjects: maxNrOfCacheObjects,
      repo: JsonCacheInfoRepository(databaseName: key),
      fileService: HttpFileService(),
    ),
  );
  
  Future<String?> getVideoFilePath(String url) async {
    final fileInfo = await getFileFromCache(url);
    if (fileInfo == null) {
      return null;
    }
    return fileInfo.file.path;
  }
  
  Future<void> preCacheVideo(String url) async {
    try {
      // Check if already cached
      final fileInfo = await getFileFromCache(url);
      if (fileInfo != null) {
        return;
      }
      
      // Download and cache the video
      await downloadFile(url);
      print('🎥 Pre-cached video: $url');
    } catch (e) {
      print('Error pre-caching video: $e');
    }
  }
  
  Future<void> cleanupCache() async {
    try {
      await emptyCache();
      print('🧹 Cleaned video cache');
    } catch (e) {
      print('Error cleaning cache: $e');
    }
  }
  
  Future<int> getCacheSize() async {
    try {
      final cacheDir = await getTemporaryDirectory();
      final cacheFiles = Directory(path.join(cacheDir.path, key))
          .listSync(recursive: true, followLinks: false);
      
      int totalSize = 0;
      for (var file in cacheFiles) {
        if (file is File) {
          totalSize += await file.length();
        }
      }
      
      return totalSize;
    } catch (e) {
      print('Error getting cache size: $e');
      return 0;
    }
  }
  
  Future<void> removeOldCache() async {
    try {
      final cacheSize = await getCacheSize();
      final maxSize = 500 * 1024 * 1024; // 500MB
      
      if (cacheSize > maxSize) {
        await cleanupCache();
      }
    } catch (e) {
      print('Error removing old cache: $e');
    }
  }
} 