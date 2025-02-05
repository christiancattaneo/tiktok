import 'package:flutter_dotenv/flutter_dotenv.dart';

class ConfigService {
  static String get giphyApiKey => dotenv.env['GIPHY_API_KEY'] ?? '';
  
  static Future<void> initialize() async {
    // Load environment variables
    await dotenv.load();
    
    print('ConfigService initialized');
    // Don't print the actual API key in logs
    print('GIPHY API key loaded: ${giphyApiKey.substring(0, 4)}...');
  }
} 