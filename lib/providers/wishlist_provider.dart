import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shop/models/product_model.dart';

class WishlistProvider extends ChangeNotifier {
  final Map<String, ProductModel> _wishlistedProducts = {};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _wishlistSubscription;
  StreamSubscription<User?>? _authSubscription;
  String? _userId;

  WishlistProvider() {
    _authSubscription =
        FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        _userId = user.uid;
        _listenToWishlist();
      } else {
        _userId = null;
        _wishlistedProducts.clear();
        _wishlistSubscription?.cancel();
        _wishlistSubscription = null;
        notifyListeners();
      }
    });
  }

  CollectionReference<Map<String, dynamic>> get _wishlistRef => FirebaseFirestore
      .instance
      .collection('users')
      .doc(_userId)
      .collection('wishlist');

  void _listenToWishlist() {
    if (_userId == null) return;

    _wishlistSubscription?.cancel();
    _wishlistSubscription = _wishlistRef.snapshots().listen(
      (snapshot) {
        _wishlistedProducts.clear();
        for (var doc in snapshot.docs) {
          final product = ProductModel.fromJson({...doc.data(), 'id': doc.id});
          _wishlistedProducts[product.id] = product;
        }
        notifyListeners();
      },
      onError: (Object e) => debugPrint("Wishlist stream error: $e"),
    );
  }

  List<ProductModel> get wishlistedItems => _wishlistedProducts.values.toList();

  bool isWishlisted(String id) => _wishlistedProducts.containsKey(id);

  Future<void> toggle(ProductModel product) async {
    if (_userId == null) return;

    final docRef = _wishlistRef.doc(product.id);
    try {
      if (isWishlisted(product.id)) {
        await docRef.delete();
      } else {
        await docRef.set(product.toJson());
      }
    } catch (e) {
      debugPrint("Wishlist toggle error: $e");
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _wishlistSubscription?.cancel();
    super.dispose();
  }
}
