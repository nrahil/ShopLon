import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shop/models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  UserModel? _currentUser;
  bool _isLoading = false;

  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isLoading => _isLoading;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('user');
    if (userJson != null) {
      _currentUser = UserModel.fromJson(json.decode(userJson));
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    // Mock network delay
    await Future.delayed(const Duration(seconds: 1));

    _isLoading = false;
    
    // In Phase 1, any valid-looking request works, but check against demo if wanted.
    // We'll let any reasonable credentials pass in mock mode.
    if (email.isNotEmpty && password.length >= 6) {
      _currentUser = UserModel(
        name: email.split('@').first,
        email: email,
      );
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user', json.encode(_currentUser!.toJson()));
      notifyListeners();
      return true;
    }
    
    notifyListeners();
    return false;
  }

  Future<bool> signup(String name, String email, String password) async {
    _isLoading = true;
    notifyListeners();

    // Mock network delay
    await Future.delayed(const Duration(seconds: 1));

    _isLoading = false;
    
    if (name.isNotEmpty && email.isNotEmpty && password.length >= 6) {
      _currentUser = UserModel(
        name: name,
        email: email,
      );
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user', json.encode(_currentUser!.toJson()));
      notifyListeners();
      return true;
    }

    notifyListeners();
    return false;
  }

  Future<void> logout() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user');
    notifyListeners();
  }
  
  Future<void> updateProfile({required String name, required String email}) async {
    if (_currentUser != null) {
      _currentUser = UserModel(
        name: name,
        email: email,
        avatarUrl: _currentUser!.avatarUrl,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user', json.encode(_currentUser!.toJson()));
      notifyListeners();
    }
  }
}
