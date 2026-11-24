import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shop/models/user_model.dart';
import 'package:shop/services/api_client.dart';

class AuthProvider extends ChangeNotifier {
  static const String _defaultAvatar = 'https://i.imgur.com/IXnO207.png';

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _lastError;

  /// User-friendly message for the most recent failed login/signup.
  String? get lastError => _lastError;

  static String _messageFor(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'An account with this email already exists. Please log in instead.';
      case 'invalid-email':
        return 'That email address is not valid.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled in Firebase.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      default:
        return e.message ?? 'Something went wrong. Please try again.';
    }
  }
  StreamSubscription<User?>? _userSubscription;

  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isLoading => _isLoading;

  UserModel? _mapUser(User? user) {
    if (user == null) return null;
    final email = user.email ?? '';
    final displayName = user.displayName;
    return UserModel(
      name: (displayName != null && displayName.isNotEmpty)
          ? displayName
          : (email.isNotEmpty ? email.split('@').first : 'User'),
      email: email,
      avatarUrl: user.photoURL ?? _defaultAvatar,
    );
  }

  /// Waits for Firebase to restore any persisted session before returning,
  /// so the app can choose the correct initial route.
  Future<void> init() async {
    final restoredUser = await FirebaseAuth.instance.authStateChanges().first;
    _currentUser = _mapUser(restoredUser);

    // userChanges() also fires on display name / email updates.
    _userSubscription = FirebaseAuth.instance.userChanges().listen((User? user) {
      _currentUser = _mapUser(user);
      notifyListeners();
    });
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint("Login error: ${e.code} ${e.message}");
      _lastError = _messageFor(e);
      return false;
    } catch (e) {
      debugPrint("Unknown error: $e");
      _lastError = 'Something went wrong. Please try again.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> signup(String name, String email, String password) async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      final userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      await userCredential.user?.updateDisplayName(name.trim());
      await userCredential.user?.reload();
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint("Signup error: ${e.code} ${e.message}");
      _lastError = _messageFor(e);
      return false;
    } catch (e) {
      debugPrint("Unknown error: $e");
      _lastError = 'Something went wrong. Please try again.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Revokes the session on the server first (so a copied token stops working
  /// immediately, on every device), then signs out locally. If the server is
  /// unreachable, the local sign-out still happens.
  Future<void> logout() async {
    try {
      await ApiClient.instance
          .post('/v1/auth/logout')
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint("Server logout failed (signing out locally anyway): $e");
    }
    await FirebaseAuth.instance.signOut();
  }

  Future<void> updateProfile({required String name, required String email}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      if (name != user.displayName) {
        await user.updateDisplayName(name);
      }
      if (email != user.email) {
        // Email only changes after the user confirms the verification link.
        await user.verifyBeforeUpdateEmail(email);
      }
      await user.reload();
    } catch (e) {
      debugPrint("Update profile error: $e");
    }
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }
}
