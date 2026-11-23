import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shop/models/cart_item_model.dart';
import 'package:shop/models/product_model.dart';

class CartProvider extends ChangeNotifier {
  List<CartItemModel> _cartItems = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _cartSubscription;
  StreamSubscription<User?>? _authSubscription;
  String? _userId;

  CartProvider() {
    _authSubscription =
        FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        _userId = user.uid;
        _listenToCart();
      } else {
        _userId = null;
        _cartItems = [];
        _cartSubscription?.cancel();
        _cartSubscription = null;
        notifyListeners();
      }
    });
  }

  CollectionReference<Map<String, dynamic>> get _cartRef =>
      FirebaseFirestore.instance.collection('users').doc(_userId).collection('cart');

  void _listenToCart() {
    if (_userId == null) return;

    _cartSubscription?.cancel();
    _cartSubscription = _cartRef.snapshots().listen(
      (snapshot) {
        _cartItems = snapshot.docs
            .map((doc) => CartItemModel.fromJson(doc.data(), doc.id))
            .toList();
        notifyListeners();
      },
      onError: (Object e) => debugPrint("Cart stream error: $e"),
    );
  }

  bool get isLoggedIn => _userId != null;
  List<CartItemModel> get cartItems => _cartItems;
  int get itemCount => _cartItems.length;

  double get subtotal {
    double total = 0;
    for (var item in _cartItems) {
      double price = item.product.priceAfetDiscount ?? item.product.price;
      total += price * item.quantity;
    }
    return total;
  }

  double get shippingTotal => 10.0;
  double get taxTotal => subtotal * 0.08;
  double get totalPrice => subtotal + shippingTotal + taxTotal;

  /// Throws a [StateError] when no user is signed in, or rethrows Firestore errors,
  /// so the caller can show feedback.
  Future<void> addToCart(ProductModel product,
      {int quantity = 1, String? size, String? color}) async {
    if (_userId == null) {
      throw StateError("Please log in to add items to your cart.");
    }

    int index = _cartItems.indexWhere((item) =>
        item.product.id == product.id &&
        item.selectedSize == size &&
        item.selectedColor == color);

    if (index >= 0) {
      CartItemModel existingItem = _cartItems[index];
      await _cartRef.doc(existingItem.id).update({
        'quantity': existingItem.quantity + quantity,
      });
    } else {
      CartItemModel newItem = CartItemModel(
        product: product,
        quantity: quantity,
        selectedSize: size,
        selectedColor: color,
      );
      await _cartRef.add(newItem.toJson());
    }
  }

  Future<void> removeFromCart(CartItemModel item) async {
    if (_userId == null || item.id == null) return;
    await _cartRef.doc(item.id).delete();
  }

  Future<void> updateQuantity(CartItemModel item, int newQuantity) async {
    if (_userId == null || item.id == null) return;

    if (newQuantity <= 0) {
      await removeFromCart(item);
    } else {
      await _cartRef.doc(item.id).update({'quantity': newQuantity});
    }
  }

  Future<void> clearCart() async {
    if (_userId == null) return;

    var snapshot = await _cartRef.get();
    WriteBatch batch = FirebaseFirestore.instance.batch();
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _cartSubscription?.cancel();
    super.dispose();
  }
}
