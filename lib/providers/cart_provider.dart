import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shop/models/cart_item_model.dart';
import 'package:shop/models/product_model.dart';

class CartProvider extends ChangeNotifier {
  List<CartItemModel> _cartItems = [];
  StreamSubscription<QuerySnapshot>? _cartSubscription;
  String? _userId;

  CartProvider() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        _userId = user.uid;
        _listenToCart();
      } else {
        _userId = null;
        _cartItems.clear();
        _cartSubscription?.cancel();
        notifyListeners();
      }
    });
  }

  void _listenToCart() {
    if (_userId == null) return;
    
    _cartSubscription?.cancel();
    _cartSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(_userId)
        .collection('cart')
        .snapshots()
        .listen((snapshot) {
      _cartItems = snapshot.docs.map((doc) => CartItemModel.fromJson(doc.data(), doc.id)).toList();
      notifyListeners();
    });
  }

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

  Future<void> addToCart(ProductModel product, {int quantity = 1, String? size, String? color}) async {
    if (_userId == null) return;

    int index = _cartItems.indexWhere((item) => 
      item.product.id == product.id && 
      item.selectedSize == size && 
      item.selectedColor == color
    );

    var cartRef = FirebaseFirestore.instance.collection('users').doc(_userId).collection('cart');

    if (index >= 0) {
      CartItemModel existingItem = _cartItems[index];
      await cartRef.doc(existingItem.id).update({
        'quantity': existingItem.quantity + quantity,
      });
    } else {
      CartItemModel newItem = CartItemModel(
        product: product,
        quantity: quantity,
        selectedSize: size,
        selectedColor: color,
      );
      await cartRef.add(newItem.toJson());
    }
  }

  Future<void> removeFromCart(CartItemModel item) async {
    if (_userId == null || item.id == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(_userId)
        .collection('cart')
        .doc(item.id)
        .delete();
  }

  Future<void> updateQuantity(CartItemModel item, int newQuantity) async {
    if (_userId == null || item.id == null) return;
    
    if (newQuantity <= 0) {
      await removeFromCart(item);
    } else {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .collection('cart')
          .doc(item.id)
          .update({'quantity': newQuantity});
    }
  }

  Future<void> clearCart() async {
    if (_userId == null) return;
    
    var cartRef = FirebaseFirestore.instance.collection('users').doc(_userId).collection('cart');
    var snapshot = await cartRef.get();
    
    WriteBatch batch = FirebaseFirestore.instance.batch();
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  @override
  void dispose() {
    _cartSubscription?.cancel();
    super.dispose();
  }
}
