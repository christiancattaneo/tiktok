import 'package:cloud_firestore/cloud_firestore.dart';

class Video {
  final String id;
  final String userId;
  final String creatorUsername;
  final String? creatorPhotoUrl;
  final String videoUrl;
  final String caption;
  final String? thumbnailUrl;
  final List<String> hashtags;
  final int likes;
  final int views;
  final int? commentCount;
  final DateTime? createdAt;

  Video({
    required this.id,
    required this.userId,
    required this.creatorUsername,
    this.creatorPhotoUrl,
    required this.videoUrl,
    required this.caption,
    this.thumbnailUrl,
    required this.hashtags,
    required this.likes,
    required this.views,
    this.commentCount,
    this.createdAt,
  });

  factory Video.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Video(
      id: doc.id,
      userId: data['userId'] ?? '',
      creatorUsername: data['creatorUsername'] ?? '',
      creatorPhotoUrl: data['creatorPhotoUrl'],
      videoUrl: data['videoUrl'] ?? '',
      caption: data['caption'] ?? '',
      thumbnailUrl: data['thumbnailUrl'],
      hashtags: List<String>.from(data['hashtags'] ?? []),
      likes: data['likes'] ?? 0,
      views: data['views'] ?? 0,
      commentCount: data['commentCount'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'creatorUsername': creatorUsername,
      'creatorPhotoUrl': creatorPhotoUrl,
      'videoUrl': videoUrl,
      'caption': caption,
      'thumbnailUrl': thumbnailUrl,
      'hashtags': hashtags,
      'likes': likes,
      'views': views,
      'commentCount': commentCount,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
    };
  }
} 