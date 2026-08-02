import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shop/models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  UserModel? _currentUser;
  bool _isLoading = false;

  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isLoading => _isLoading;

  Future<void> init() async {
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        _currentUser = UserModel(
          name: user.displayName ?? user.email!.split('@').first,
          email: user.email ?? '',
          avatarUrl: user.photoURL ?? 'https://i.imgur.com/IXnO207.png',
        );
      } else {
        _currentUser = null;
      }
      notifyListeners();
    });
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint("Login error: ${e.message}");
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint("Unknown error: $e");
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signup(String name, String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      await userCredential.user?.updateDisplayName(name);
      
      // Update local state early for immediate UI response
      _currentUser = UserModel(
        name: name,
        email: email,
      );
      
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint("Signup error: ${e.message}");
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint("Unknown error: $e");
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
  }
  
  Future<void> updateProfile({required String name, required String email}) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        if (name != user.displayName) {
          await user.updateDisplayName(name);
        }
        if (email != user.email) {
          await user.verifyBeforeUpdateEmail(email);
        }
        
        // Update local state
        _currentUser = UserModel(
          name: name,
          email: email,
          avatarUrl: _currentUser?.avatarUrl ?? 'https://i.imgur.com/IXnO207.png',
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Update profile error: $e");
    }
  }
}
