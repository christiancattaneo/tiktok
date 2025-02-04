import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart' as app_models;

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Get current user
  Future<app_models.User?> getCurrentUser() async {
    try {
      final firebaseUser = _auth.currentUser;
      if (firebaseUser == null) return null;

      try {
        // Try to get the user document
        final docRef = _firestore.collection('users').doc(firebaseUser.uid);
        final doc = await docRef.get();

        if (doc.exists) {
          return app_models.User.fromFirestore(doc);
        }

        // If user exists in Auth but not in Firestore, create the document
        await docRef.set({
          'id': firebaseUser.uid,
          'email': firebaseUser.email,
          'username': firebaseUser.email?.split('@')[0] ?? 'user',
          'photoUrl': firebaseUser.photoURL ?? '',
          'bio': '',
          'likedVideos': [],
          'followersCount': 0,
          'followingCount': 0,
          'createdAt': FieldValue.serverTimestamp(),
        });

        final newDoc = await docRef.get();
        return app_models.User.fromFirestore(newDoc);
      } catch (e) {
        print('Firestore error: $e');
        return null;
      }
    } catch (e) {
      print('Error getting user profile: $e');
      return null;
    }
  }

  // Find user by username
  Future<String?> findUserByUsername(String username) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return null;
      }

      return querySnapshot.docs.first.data()['email'] as String?;
    } catch (e) {
      print('Error finding user by username: $e');
      return null;
    }
  }

  // Handle Firebase Auth errors
  String? _handleAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'email-already-in-use':
        return 'The email address is already in use.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'The password is too weak.';
      default:
        return 'An error occurred. Please try again.';
    }
  }

  // Sign in with email/username and password
  Future<String?> signInWithEmailAndPassword(String emailOrUsername, String password) async {
    try {
      String email = emailOrUsername;
      bool isEmail = emailOrUsername.contains('@');
      
      // If input doesn't contain '@', assume it's a username and try to find the email
      if (!isEmail) {
        final userEmail = await findUserByUsername(emailOrUsername);
        if (userEmail == null) {
          return 'No account found with this username.';
        }
        email = userEmail;
      }

      try {
        final userCredential = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        return userCredential.user?.uid;
      } on FirebaseAuthException catch (e) {
        // Customize error message based on whether user entered email or username
        if (e.code == 'user-not-found') {
          return isEmail 
              ? 'No account found with this email.'
              : 'No account found with this username.';
        }
        return _handleAuthError(e);
      }
    } catch (e) {
      print('Error during sign in: $e');
      return 'An error occurred. Please try again.';
    }
  }

  // Sign up with email and password
  Future<String?> signUpWithEmailAndPassword(
    String email,
    String password,
    String username,
  ) async {
    try {
      // Create the auth user
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        // Create user document with retry logic
        int retries = 3;
        while (retries > 0) {
          try {
            await _firestore.collection('users').doc(userCredential.user!.uid).set({
              'id': userCredential.user!.uid,
              'username': username,
              'email': email,
              'photoUrl': '',
              'bio': '',
              'likedVideos': [],
              'followersCount': 0,
              'followingCount': 0,
              'createdAt': FieldValue.serverTimestamp(),
            });
            
            // Verify the document was created
            final doc = await _firestore.collection('users').doc(userCredential.user!.uid).get();
            if (doc.exists) {
              return userCredential.user?.uid;
            }
            retries--;
          } catch (e) {
            if (retries <= 1) {
              throw FirebaseException(
                plugin: 'cloud_firestore',
                message: 'Failed to create user profile after multiple attempts',
              );
            }
            // Wait before retrying
            await Future.delayed(Duration(seconds: 1));
            retries--;
          }
        }
        return null;
      }
      return null;
    } on FirebaseAuthException catch (e) {
      return _handleAuthError(e);
    } on FirebaseException catch (e) {
      return e.message;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      // Clear any persisted auth state
      await _auth.setPersistence(Persistence.NONE);
      // Sign out
      await _auth.signOut();
      // Reset persistence back to default
      await _auth.setPersistence(Persistence.LOCAL);
    } catch (e) {
      print('Error during sign out: $e');
      rethrow;
    }
  }
} 