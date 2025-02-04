import 'package:cloud_firestore/cloud_firestore.dart';

class Comment {
  final String id;
  final String videoId;
  final String userId;
  final String username;
  final String? userPhotoUrl;
  final String text;
  final int likes;
  final bool likedByCreator;
  bool isLiked;
  final DateTime createdAt;

  Comment({
    required this.id,
    required this.videoId,
    required this.userId,
    required this.username,
    this.userPhotoUrl,
    required this.text,
    required this.likes,
    required this.likedByCreator,
    this.isLiked = false,
    required this.createdAt,
  });

  factory Comment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Comment(
      id: doc.id,
      videoId: data['videoId'] ?? '',
      userId: data['userId'] ?? '',
      username: data['username'] ?? '',
      userPhotoUrl: data['userPhotoUrl'],
      text: data['text'] ?? '',
      likes: data['likes'] ?? 0,
      likedByCreator: data['likedByCreator'] ?? false,
      isLiked: false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'videoId': videoId,
      'userId': userId,
      'username': username,
      'userPhotoUrl': userPhotoUrl,
      'text': text,
      'likes': likes,
      'likedByCreator': likedByCreator,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
} 