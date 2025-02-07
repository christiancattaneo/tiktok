import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

class VideoProvider extends ChangeNotifier {
  VideoPlayerController? _activeVideoController;
  String? _activeVideoId;
  bool _isDisposed = false;
  
  VideoPlayerController? get activeVideoController => _activeVideoController;
  String? get activeVideoId => _activeVideoId;
  
  void setActiveVideo(VideoPlayerController controller, String videoId) {
    if (_isDisposed) return;
    
    print('📱 Setting active video: $videoId');
    _activeVideoController = controller;
    _activeVideoId = videoId;
    notifyListeners();
  }
  
  void clearActiveVideo() {
    print('📱 Clearing active video');
    _activeVideoController = null;
    _activeVideoId = null;
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    print('📱 Disposing VideoProvider');
    _isDisposed = true;
    _activeVideoController = null;
    _activeVideoId = null;
    super.dispose();
  }
} 