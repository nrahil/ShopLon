import 'package:shop/models/cart_item_model.dart';
import 'package:shop/models/product_model.dart';

/// The latest payment attempt on an order.
class PaymentInfo {
  final String id;
  final String provider; // "mock" or "stripe"
  final String status; // CREATED | SUCCEEDED | FAILED | REFUND_PENDING | REFUNDED
  final String? providerRef;
  final String? clientSecret;
  final String? confirmUrl;
  final String? redirectUrl;
  final String? failureReason;

  const PaymentInfo({
    required this.id,
    required this.provider,
    required this.status,
    this.providerRef,
    this.clientSecret,
    this.confirmUrl,
    this.redirectUrl,
    this.failureReason,
  });

  bool get isOpen => status == 'CREATED';

  factory PaymentInfo.fromJson(Map<String, dynamic> j) => PaymentInfo(
        id: j['id'] as String,
        provider: j['provider'] as String? ?? 'mock',
        status: j['status'] as String? ?? 'CREATED',
        providerRef: j['providerRef'] as String?,
        clientSecret: j['clientSecret'] as String?,
        confirmUrl: j['confirmUrl'] as String?,
        redirectUrl: j['redirectUrl'] as String?,
        failureReason: j['failureReason'] as String?,
      );

  String get failureMessage => switch (failureReason) {
        'card_declined' => 'Your card was declined.',
        'insufficient_funds' => 'Your card has insufficient funds.',
        'order_expired' => 'The reservation expired before payment completed.',
        'order_cancelled' => 'The order was cancelled.',
        null => 'The payment did not go through.',
        _ => 'The payment did not go through ($failureReason).',
      };
}

class OrderModel {
  final String id;
  final List<CartItemModel> items;
  final int itemCount;
  final double subtotal, shipping, tax, total;
  final int totalCents;

  /// PENDING_PAYMENT | PAID | SHIPPED | CANCELLED | EXPIRED | REFUND_PENDING | REFUNDED
  final String status;
  final DateTime? createdAt;
  final DateTime? expiresAt;
  final PaymentInfo? payment;

  const OrderModel({
    required this.id,
    required this.items,
    required this.itemCount,
    required this.subtotal,
    required this.shipping,
    required this.tax,
    required this.total,
    required this.totalCents,
    required this.status,
    this.createdAt,
    this.expiresAt,
    this.payment,
  });

  factory OrderModel.fromApi(Map<String, dynamic> j) {
    double money(String key) => ((j[key] as num?)?.toInt() ?? 0) / 100;
    final items = (j['items'] as List? ?? const [])
        .whereType<Map>()
        .map((raw) {
          final i = Map<String, dynamic>.from(raw);
          final unit = ((i['unitPriceCents'] as num?)?.toInt() ?? 0) / 100;
          return CartItemModel(
            id: i['productId'] as String?,
            product: ProductModel(
              id: i['productId'] as String? ?? '',
              image: i['thumbnail'] as String? ?? '',
              brandName: '',
              title: i['title'] as String? ?? '',
              price: unit,
            ),
            quantity: (i['quantity'] as num?)?.toInt() ?? 1,
            selectedSize: i['selectedSize'] as String?,
            selectedColor: i['selectedColor'] as String?,
          );
        })
        .toList();
    return OrderModel(
      id: j['id'] as String,
      items: items,
      itemCount: (j['itemCount'] as num?)?.toInt() ?? items.length,
      subtotal: money('subtotalCents'),
      shipping: money('shippingCents'),
      tax: money('taxCents'),
      total: money('totalCents'),
      totalCents: (j['totalCents'] as num?)?.toInt() ?? 0,
      status: j['status'] as String? ?? 'PENDING_PAYMENT',
      createdAt: DateTime.tryParse(j['createdAt'] as String? ?? ''),
      expiresAt: DateTime.tryParse(j['expiresAt'] as String? ?? ''),
      payment: j['payment'] is Map
          ? PaymentInfo.fromJson(Map<String, dynamic>.from(j['payment'] as Map))
          : null,
    );
  }

  bool get isAwaitingPayment => status == 'PENDING_PAYMENT';
  bool get isPaid => status == 'PAID' || status == 'SHIPPED';
  bool get isClosed => !isAwaitingPayment && !isPaid;

  String get statusLabel => switch (status) {
        'PENDING_PAYMENT' => 'Awaiting payment',
        'PAID' => 'Paid',
        'SHIPPED' => 'Shipped',
        'CANCELLED' => 'Cancelled',
        'EXPIRED' => 'Expired',
        'REFUND_PENDING' => 'Refund pending',
        'REFUNDED' => 'Refunded',
        _ => status,
      };

  /// Short, readable order number, e.g. "#A1B2C3".
  String get shortId =>
      '#${id.substring(0, id.length < 6 ? id.length : 6).toUpperCase()}';
}
