import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shop/models/order_model.dart';
import 'package:shop/services/api_client.dart';

/// Test cards understood by the bundled mock payment provider.
class TestCard {
  const TestCard(this.label, this.number);
  final String label;
  final String number;

  static const all = [
    TestCard('Succeeds', '4242 4242 4242 4242'),
    TestCard('Declined', '4000 0000 0000 0002'),
    TestCard('Insufficient funds', '4000 0000 0000 9995'),
    TestCard('Duplicate webhook', '4000 0000 0000 0259'),
    TestCard('Lost webhook', '4000 0000 0000 0341'),
  ];
}

/// The signed-in user's orders, plus payment actions.
class OrderProvider extends ChangeNotifier {
  OrderProvider({ApiClient? api}) : _api = api ?? ApiClient.instance {
    _authSubscription =
        FirebaseAuth.instance.authStateChanges().listen((user) {
      _orders = [];
      _error = null;
      if (user != null) {
        fetchOrders();
      } else {
        notifyListeners();
      }
    });
  }

  final ApiClient _api;
  StreamSubscription<User?>? _authSubscription;
  List<OrderModel> _orders = [];
  bool _isLoading = false;
  String? _error;

  List<OrderModel> get orders => _orders;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchOrders() async {
    if (FirebaseAuth.instance.currentUser == null) return;
    _isLoading = true;
    notifyListeners();
    try {
      final page = await _api.get('/v1/orders', query: {'limit': '50'})
          as Map<String, dynamic>;
      _orders = (page['items'] as List)
          .whereType<Map>()
          .map((o) => OrderModel.fromApi(Map<String, dynamic>.from(o)))
          .toList();
      _error = null;
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _upsert(OrderModel order) {
    final i = _orders.indexWhere((o) => o.id == order.id);
    if (i >= 0) {
      _orders[i] = order;
    } else {
      _orders.insert(0, order);
    }
    notifyListeners();
  }

  Future<OrderModel> getOrder(String id) async {
    final order = OrderModel.fromApi(
        await _api.get('/v1/orders/$id') as Map<String, dynamic>);
    _upsert(order);
    return order;
  }

  /// Opens a new payment attempt (after a decline, or to resume paying).
  Future<OrderModel> startPayment(String orderId) async {
    final order = OrderModel.fromApi(await _api.post(
        '/v1/orders/$orderId/payments',
        idempotencyKey: newIdempotencyKey()) as Map<String, dynamic>);
    _upsert(order);
    return order;
  }

  Future<OrderModel> cancel(String orderId) async {
    final order = OrderModel.fromApi(
        await _api.post('/v1/orders/$orderId/cancel') as Map<String, dynamic>);
    _upsert(order);
    return order;
  }

  /// Sends card details straight to the payment provider using the attempt's
  /// client secret. They never pass through the ShopLon API.
  Future<void> confirmMockPayment(PaymentInfo payment,
      {required String cardNumber,
      required int expMonth,
      required int expYear,
      required String cvc}) async {
    final http.Response res;
    try {
      res = await http
          .post(
            Uri.parse(payment.confirmUrl!),
            headers: {'content-type': 'application/json'},
            body: jsonEncode({
              'client_secret': payment.clientSecret,
              'card': {
                'number': cardNumber.replaceAll(' ', ''),
                'exp_month': expMonth,
                'exp_year': expYear,
                'cvc': cvc,
              },
            }),
          )
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      throw ApiException(0, 'NETWORK', "Couldn't reach the payment provider.");
    }
    if (res.statusCode >= 400) {
      String message = 'Payment failed.';
      try {
        message = (jsonDecode(res.body)['error']['message'] as String?) ?? message;
      } catch (_) {}
      throw ApiException(res.statusCode, 'PAYMENT_REJECTED', message);
    }
  }

  /// Polls until the payment settles (webhook processed), backing off from
  /// 0.5 s to 3 s. Returns the latest order even if it is still pending.
  Future<OrderModel> waitForSettlement(String orderId,
      {Duration timeout = const Duration(seconds: 45)}) async {
    final deadline = DateTime.now().add(timeout);
    var delay = const Duration(milliseconds: 500);
    var order = await getOrder(orderId);
    while (DateTime.now().isBefore(deadline)) {
      final p = order.payment;
      if (!order.isAwaitingPayment || (p != null && !p.isOpen)) return order;
      await Future.delayed(delay);
      if (delay < const Duration(seconds: 3)) delay *= 2;
      order = await getOrder(orderId);
    }
    return order;
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
