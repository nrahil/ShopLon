import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shop/models/order_model.dart';

/// Streams the signed-in user's orders from users/{uid}/orders, newest first.
class OrderProvider extends ChangeNotifier {
  List<OrderModel> _orders = [];
  bool _isLoading = false;
  String? _error;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _ordersSubscription;

  List<OrderModel> get orders => _orders;
  bool get isLoading => _isLoading;
  String? get error => _error;

  OrderProvider() {
    _authSubscription =
        FirebaseAuth.instance.authStateChanges().listen(_onUserChanged);
  }

  void _onUserChanged(User? user) {
    _ordersSubscription?.cancel();
    _ordersSubscription = null;
    _orders = [];
    _error = null;

    if (user == null) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();
    _ordersSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen(
      (snapshot) {
        _orders = snapshot.docs.map(OrderModel.fromFirestore).toList();
        _isLoading = false;
        _error = null;
        notifyListeners();
      },
      onError: (Object e) {
        debugPrint("Orders stream error: $e");
        _isLoading = false;
        _error = "Couldn't load your orders.";
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _ordersSubscription?.cancel();
    super.dispose();
  }
}
