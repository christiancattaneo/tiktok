import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:giphy_picker/giphy_picker.dart';

class ConfigService {
  static String get giphyApiKey => dotenv.env['GIPHY_API_KEY'] ?? '';
  
  static Future<void> initialize() async {
    // Load environment variables
    await dotenv.load();
    
    // Initialize GIPHY
    Giphy.init(apiKey: giphyApiKey);
    
    print('ConfigService initialized');
    // Don't print the actual API key in logs
    print('GIPHY initialized: ${giphyApiKey.substring(0, 4)}...');
  }
} 