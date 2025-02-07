import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../services/auth_service.dart';
import '../models/user.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  User? _user;
  firebase_auth.User? _firebaseUser;
  bool _isLoading = true;  // Start with loading true
  String? _error;

  User? get user => _user;
  String? get userId => _firebaseUser?.uid;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  String? get error => _error;

  AuthProvider() {
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    _authService.authStateChanges.listen((firebase_auth.User? firebaseUser) async {
      _isLoading = true;
      _error = null;
      _firebaseUser = firebaseUser;
      notifyListeners();

      try {
        if (firebaseUser != null) {
          // Try to get user profile with retries
          for (int i = 0; i < 3; i++) {
            try {
              _user = await _authService.getCurrentUser();
              if (_user != null) {
                _error = null; // Clear any previous errors
                break;
              }
              if (i < 2) { // Only delay if we're going to retry
                await Future.delayed(Duration(seconds: 1));
              }
            } catch (e) {
              print('Attempt ${i + 1} failed: $e');
              if (i == 2) {
                _error = 'Failed to load user profile. Please try again.';
                _user = null;
              }
            }
          }
        } else {
          _user = null;
          _error = null; // Clear any errors when logging out
        }
      } catch (e) {
        print('Auth state error: $e');
        _error = 'Authentication error. Please try again.';
        _user = null;
      } finally {
        _isLoading = false;
        notifyListeners();
      }
    });
  }

  Future<String?> signIn(String email, String password) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // First, check if there's a current user and sign them out
      if (_firebaseUser != null) {
        await _authService.signOut();
        // Wait a moment for the auth state to clear
        await Future.delayed(const Duration(milliseconds: 500));
      }

      final result = await _authService.signInWithEmailAndPassword(email, password);
      if (result == null) {
        _error = 'Failed to sign in';
        return 'Failed to sign in';
      }
      return null; // null means success
    } catch (e) {
      _error = e.toString();
      return e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> signUp(String email, String password, String username) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final result = await _authService.signUpWithEmailAndPassword(
        email,
        password,
        username,
      );
      if (result == null) {
        _error = 'Failed to sign up';
        return 'Failed to sign up';
      }
      return null; // null means success
    } catch (e) {
      _error = e.toString();
      return e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    print('🔑 Sign out process started');
    try {
      _isLoading = true;
      notifyListeners();
      
      await _authService.signOut();
      _user = null;
      _firebaseUser = null;
      _error = null;
      
      print('🔑 Sign out completed successfully');
    } catch (e) {
      print('🔑 Error during sign out: $e');
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
      print('🔑 Sign out process finished');
    }
  }
} 