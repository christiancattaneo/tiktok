import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_auth_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/feed_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppAuthProvider(),
      child: MaterialApp(
        title: 'ReelAI',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: Colors.black,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.black,
            elevation: 0,
          ),
        ),
        initialRoute: '/',
        routes: {
          '/': (context) => Consumer<AppAuthProvider>(
            builder: (context, authProvider, _) {
              return authProvider.isAuthenticated
                  ? const FeedScreen()
                  : const LoginScreen();
            },
          ),
        },
      ),
    );
  }
} 