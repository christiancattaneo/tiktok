import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'providers/app_auth_provider.dart';
import 'providers/video_provider.dart';
import 'app.dart';
import 'services/config_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> initializeFirebase() async {
  try {
    await Firebase.initializeApp(
      name: 'ReelAI',
      options: DefaultFirebaseOptions.currentPlatform,
    ).then((_) {
      // Disable automatic data collection and app check
      FirebaseAuth.instance.setSettings(
        appVerificationDisabledForTesting: true,
        phoneNumber: null,
        smsCode: null,
        forceRecaptchaFlow: false,
      );
      
      // Configure Firestore with more permissive settings
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
        host: 'firestore.googleapis.com',
        sslEnabled: true,
        ignoreUndefinedProperties: true,
      );
      
      // Disable App Check verification
      FirebaseFirestore.instance.enableNetwork();
    });
  } catch (e) {
    print('Firebase initialization error: $e');
    // If initialization fails, try to get existing app
    Firebase.app('ReelAI');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await initializeFirebase();
    
    // Initialize configuration (including GIPHY)
    await dotenv.load();  // Just load .env file directly
    
    // Print Firebase Auth state for debugging
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      print('🔐 Auth State Changed: ${user?.uid ?? 'No user'}');
    });
    
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AppAuthProvider()),
          ChangeNotifierProvider(create: (_) => VideoProvider()),
        ],
        child: const MyApp(),
      ),
    );
  } catch (e) {
    print('Error during initialization: $e');
    rethrow;
  }
} 