import 'package:flutter_dotenv/flutter_dotenv.dart';

class ConfigService {
  static String get giphyApiKey => dotenv.env['GIPHY_API_KEY'] ?? '';
  static String get pexelsApiKey => dotenv.env['PEXELS_API_KEY'] ?? '';
  
  static Future<void> initialize() async {
    // Load environment variables
    await dotenv.load();
    
    print('ConfigService initialized');
    // Don't print the actual API keys in logs
    print('GIPHY API key loaded: ${giphyApiKey.substring(0, 4)}...');
    print('Pexels API key loaded: ${pexelsApiKey.substring(0, 4)}...');
  }
} 