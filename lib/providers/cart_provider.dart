import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shop/models/cart_item_model.dart';
import 'package:shop/models/order_model.dart';
import 'package:shop/models/product_model.dart';
import 'package:shop/services/api_client.dart';

/// Cart backed by the ShopLon API (Redis on the server).
///
/// * The server is the source of truth for prices and totals. After every
///   write, the provider adopts the cart the server returns.
/// * Quantity changes are applied optimistically, so the UI reacts instantly,
///   and rolled back if the server rejects them.
/// * Writes to the same line are chained, so rapid taps reach the server in
///   order and the last tap wins.
class CartProvider extends ChangeNotifier {
  CartProvider({ApiClient? api}) : _api = api ?? ApiClient.instance {
    _authSubscription =
        FirebaseAuth.instance.authStateChanges().listen(_onAuthChanged);
  }

  final ApiClient _api;
  StreamSubscription<User?>? _authSubscription;
  String? _userId;

  List<CartItemModel> _cartItems = [];
  int _subtotalCents = 0, _shippingCents = 0, _taxCents = 0, _totalCents = 0;
  bool _isLoading = false;
  String? _error;
  final Map<String, Future<void>> _lineQueues = {};

  /// Reused for retries of the same checkout attempt, then cleared.
  String? _checkoutKey;

  bool get isLoggedIn => _userId != null;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<CartItemModel> get cartItems => _cartItems;
  int get itemCount => _cartItems.length;

  double get subtotal => _subtotalCents / 100;
  double get shippingTotal => _shippingCents / 100;
  double get taxTotal => _taxCents / 100;
  double get totalPrice => _totalCents / 100;

  /// Free shipping on orders of $100 or more (mirrors the server rule).
  static const double freeShippingThreshold = 100;

  void _onAuthChanged(User? user) {
    _userId = user?.uid;
    _checkoutKey = null;
    if (user == null) {
      _apply(null);
      notifyListeners();
    } else {
      refresh();
    }
  }

  void _apply(Map<String, dynamic>? cart) {
    final totals = Map<String, dynamic>.from(cart?['totals'] as Map? ?? {});
    _cartItems = (cart?['lines'] as List? ?? const [])
        .whereType<Map>()
        .map((l) => CartItemModel.fromBackend(Map<String, dynamic>.from(l)))
        .toList();
    _subtotalCents = (totals['subtotalCents'] as num?)?.toInt() ?? 0;
    _shippingCents = (totals['shippingCents'] as num?)?.toInt() ?? 0;
    _taxCents = (totals['taxCents'] as num?)?.toInt() ?? 0;
    _totalCents = (totals['totalCents'] as num?)?.toInt() ?? 0;
  }

  Future<void> refresh() async {
    if (_userId == null) return;
    _isLoading = true;
    notifyListeners();
    try {
      _apply(await _api.get('/v1/cart') as Map<String, dynamic>);
      _error = null;
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Throws [StateError] when signed out, or [ApiException] (with a readable
  /// message) when the server rejects the change.
  Future<void> addToCart(ProductModel product,
      {int quantity = 1, String? size, String? color}) async {
    if (_userId == null) {
      throw StateError("Please log in to add items to your cart.");
    }
    final cart = await _api.post('/v1/cart/items', body: {
      'productId': product.id,
      'quantity': quantity,
      'size': size,
      'color': color,
    });
    _apply(cart as Map<String, dynamic>);
    notifyListeners();
  }

  Future<void> removeFromCart(CartItemModel item) =>
      updateQuantity(item, 0);

  Future<void> updateQuantity(CartItemModel item, int newQuantity) {
    final lineKey = item.id;
    if (_userId == null || lineKey == null) return Future.value();
    final target = newQuantity.clamp(0, 10);

    // Optimistic update.
    final previous = _cartItems;
    _cartItems = [
      for (final i in _cartItems)
        if (i.id != lineKey) i else if (target > 0) i.copyWith(quantity: target),
    ];
    notifyListeners();

    final path = '/v1/cart/items/${Uri.encodeComponent(lineKey)}';
    final run = (_lineQueues[lineKey] ?? Future.value()).then((_) async {
      try {
        final cart = target == 0
            ? await _api.delete(path)
            : await _api.put(path, body: {'quantity': target});
        _apply(cart as Map<String, dynamic>);
      } on ApiException {
        _cartItems = previous; // roll back
        rethrow;
      } finally {
        notifyListeners();
      }
    });
    // Keep the chain alive even if this write fails.
    _lineQueues[lineKey] = run.catchError((_) {});
    return run;
  }

  /// Turns the cart into an order (stock is reserved on the server) and
  /// returns it with an open payment attempt. Safe to call again after a
  /// network error: the same idempotency key returns the same order.
  Future<OrderModel> checkout() async {
    if (_userId == null) throw StateError("Please log in to place an order.");
    if (_cartItems.isEmpty) throw StateError("Your cart is empty.");
    await Future.wait(_lineQueues.values); // let pending quantity changes land first

    _checkoutKey ??= newIdempotencyKey();
    try {
      final order = OrderModel.fromApi(await _api.post('/v1/checkout',
          idempotencyKey: _checkoutKey) as Map<String, dynamic>);
      _checkoutKey = null;
      unawaited(refresh()); // ordered lines were removed server-side
      return order;
    } on ApiException catch (e) {
      // A definitive answer (e.g. out of stock): the next tap is a new attempt.
      if (!e.isNetwork && e.status < 500) _checkoutKey = null;
      if (e.code == 'OUT_OF_STOCK') unawaited(refresh());
      rethrow;
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
