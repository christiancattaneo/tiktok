import 'package:cloud_firestore/cloud_firestore.dart';

class SampleVideos {
  static final List<Map<String, dynamic>> data = [
    {
      'userId': 'placeholder_user',
      'videoUrl': 'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
      'caption': 'Urban vibes 🌆 City life never sleeps',
      'thumbnailUrl': 'https://storage.googleapis.com/gtv-videos-bucket/sample/images/ForBiggerBlazes.jpg',
      'hashtags': ['city', 'urban', 'vibes'],
      'likes': 0,
      'views': 0,
      'commentCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    },
    {
      'userId': 'placeholder_user',
      'videoUrl': 'https://www.w3schools.com/html/mov_bbb.mp4',
      'caption': 'Classic moments 🎬 Never gets old',
      'thumbnailUrl': 'https://storage.googleapis.com/gtv-videos-bucket/sample/images/BigBuckBunny.jpg',
      'hashtags': ['classic', 'moments', 'fun'],
      'likes': 0,
      'views': 0,
      'commentCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    },
    {
      'userId': 'placeholder_user',
      'videoUrl': 'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4',
      'caption': 'Adventure awaits 🌟 Ready for action',
      'thumbnailUrl': 'https://storage.googleapis.com/gtv-videos-bucket/sample/images/ForBiggerEscapes.jpg',
      'hashtags': ['adventure', 'action', 'excitement'],
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