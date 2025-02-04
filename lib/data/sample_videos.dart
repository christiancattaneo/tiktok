import 'package:cloud_firestore/cloud_firestore.dart';

class SampleVideos {
  static final List<Map<String, dynamic>> data = [
    {
      'userId': 'placeholder_user',
      'videoUrl': 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
      'caption': 'Big Buck Bunny - A classic open source animated film',
      'thumbnailUrl': 'https://storage.googleapis.com/gtv-videos-bucket/sample/images/BigBuckBunny.jpg',
      'hashtags': ['animation', 'classic', 'opensource'],
      'likes': 0,
      'views': 0,
      'commentCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    },
    {
      'userId': 'placeholder_user',
      'videoUrl': 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
      'caption': 'Elephants Dream - Another beautiful open source animation',
      'thumbnailUrl': 'https://storage.googleapis.com/gtv-videos-bucket/sample/images/ElephantsDream.jpg',
      'hashtags': ['animation', 'dream', 'creative'],
      'likes': 0,
      'views': 0,
      'commentCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    },
    {
      'userId': 'placeholder_user',
      'videoUrl': 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/TearsOfSteel.mp4',
      'caption': 'Tears of Steel - Sci-fi short film by Blender Foundation',
      'thumbnailUrl': 'https://storage.googleapis.com/gtv-videos-bucket/sample/images/TearsOfSteel.jpg',
      'hashtags': ['scifi', 'blender', 'shortfilm'],
      'likes': 0,
      'views': 0,
      'commentCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    },
  ];

  static Future<void> addToFirestore() async {
    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();

    for (final video in data) {
      final docRef = firestore.collection('videos').doc();
      batch.set(docRef, video);
    }

    await batch.commit();
  }
} 