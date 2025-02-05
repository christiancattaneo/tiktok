import 'package:cloud_firestore/cloud_firestore.dart';

class Comment {
  final String id;
  final String videoId;
  final String userId;
  final String username;
  final String? userPhotoUrl;
  final String text;
  final String? gifUrl;  // URL for GIF if one is attached
  final String? gifId;   // GIPHY ID for the GIF
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
    this.gifUrl,
    this.gifId,
    this.likes = 0,
    this.likedByCreator = false,
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
      gifUrl: data['gifUrl'],
      gifId: data['gifId'],
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
      'gifUrl': gifUrl,
      'gifId': gifId,
      'likes': likes,
      'likedByCreator': likedByCreator,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  Comment copyWith({
    String? id,
    String? videoId,
    String? userId,
    String? username,
    String? userPhotoUrl,
    String? text,
    String? gifUrl,
    String? gifId,
    int? likes,
    bool? likedByCreator,
    DateTime? createdAt,
  }) {
    return Comment(
      id: id ?? this.id,
      videoId: videoId ?? this.videoId,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      userPhotoUrl: userPhotoUrl ?? this.userPhotoUrl,
      text: text ?? this.text,
      gifUrl: gifUrl ?? this.gifUrl,
      gifId: gifId ?? this.gifId,
      likes: likes ?? this.likes,
      likedByCreator: likedByCreator ?? this.likedByCreator,
      isLiked: this.isLiked,
      createdAt: createdAt ?? this.createdAt,
    );
  }
} 