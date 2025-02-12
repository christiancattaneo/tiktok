import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_auth_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/main_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VibeTok',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: Consumer<AppAuthProvider>(
        builder: (context, authProvider, _) {
          if (authProvider.isLoading) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }
          
          // Show error if there is one
          if (authProvider.error != null) {
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      authProvider.error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        // This will trigger a reload of the auth state
                        authProvider.signOut();
                      },
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            );
          }
          
          return authProvider.isAuthenticated
              ? const MainScreen()
              : const LoginScreen();
        },
      ),
    );
  }
} 