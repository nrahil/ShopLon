import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shop/models/product_model.dart';

class WishlistProvider extends ChangeNotifier {
  final Set<String> _wishlistedIds = {};
  final Map<String, ProductModel> _wishlistedProducts = {};
  StreamSubscription<QuerySnapshot>? _wishlistSubscription;
  String? _userId;

  WishlistProvider() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        _userId = user.uid;
        _listenToWishlist();
      } else {
        _userId = null;
        _wishlistedIds.clear();
        _wishlistedProducts.clear();
        _wishlistSubscription?.cancel();
        notifyListeners();
      }
    });
  }

  void _listenToWishlist() {
    if (_userId == null) return;
    
    _wishlistSubscription?.cancel();
    _wishlistSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(_userId)
        .collection('wishlist')
        .snapshots()
        .listen((snapshot) {
      _wishlistedIds.clear();
      _wishlistedProducts.clear();
      
      for (var doc in snapshot.docs) {
        var product = ProductModel.fromJson(doc.data());
        _wishlistedIds.add(product.id);
        _wishlistedProducts[product.id] = product;
      }
      notifyListeners();
    });
  }

  List<ProductModel> get wishlistedItems => _wishlistedProducts.values.toList();

  bool isWishlisted(String id) {
    return _wishlistedIds.contains(id);
  }

  Future<void> toggle(ProductModel product) async {
    if (_userId == null) return;
    
    var docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(_userId)
        .collection('wishlist')
        .doc(product.id);

    if (_wishlistedIds.contains(product.id)) {
      await docRef.delete();
    } else {
      await docRef.set(product.toJson());
    }
  }

  @override
  void dispose() {
    _wishlistSubscription?.cancel();
    super.dispose();
  }
}
