// import 'package:flutter_dotenv/flutter_dotenv.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';

// class ConfigService {
  // static String get pexelsApiKey => dotenv.env['PEXELS_API_KEY'] ?? '';
  // static String get giphyApiKey => dotenv.env['GIPHY_API_KEY'] ?? '';
  // static String geminiApiKey = dotenv.env['GEMINI_API'] ?? '';  // Hardcoded for testing

//   static Future<void> initialize() async {
//     try {
//       // Load environment variables
//       await dotenv.load();
      
//       print('ConfigService initialized');
//       // Don't print the actual API keys in logs
//       print('PEXELS API key loaded: ${pexelsApiKey.substring(0, 4)}...');
//       print('GIPHY API key loaded: ${giphyApiKey.substring(0, 4)}...');
//     } catch (e) {
//       print('Error initializing ConfigService: $e');
//     }
//   }
// } 