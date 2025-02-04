import 'package:cloud_firestore/cloud_firestore.dart';

class Video {
  final String id;
  final String userId;
  final String videoUrl;
  final String thumbnailUrl;
  final String caption;
  final int likes;
  final DateTime createdAt;

  Video({
    required this.id,
    required this.userId,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.caption,
    required this.likes,
    required this.createdAt,
  });

  factory Video.fromFirestore(Map<String, dynamic> data, String id) {
    return Video(
      id: id,
      userId: data['userId'] ?? '',
      videoUrl: data['videoUrl'] ?? '',
      thumbnailUrl: data['thumbnailUrl'] ?? '',
      caption: data['caption'] ?? '',
      likes: data['likes'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'videoUrl': videoUrl,
      'thumbnailUrl': thumbnailUrl,
      'caption': caption,
      'likes': likes,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
} 