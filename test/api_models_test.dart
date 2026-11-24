import 'package:flutter_test/flutter_test.dart';
import 'package:shop/models/cart_item_model.dart';
import 'package:shop/models/order_model.dart';
import 'package:shop/models/product_model.dart';

void main() {
  final productJson = <String, dynamic>{
    'id': 'dj_1',
    'title': 'Mascara',
    'brand': null,
    'category': 'beauty',
    'priceCents': 999,
    'discountPercent': 10,
    'salePriceCents': 899,
    'stock': 5,
    'rating': 4.5,
    'thumbnail': 'https://example.com/t.webp',
    'images': ['https://example.com/1.webp'],
    'reviews': [],
  };

  test('product from API uses server-computed sale price (cents)', () {
    final p = ProductModel.fromBackend(productJson);
    expect(p.price, 9.99);
    expect(p.priceAfetDiscount, 8.99);
    expect(p.effectivePrice, 8.99);
    expect(p.dicountpercent, 10);
    expect(p.brandName, 'Beauty');
  });

  test('cart line keeps the server line key as its id', () {
    final line = CartItemModel.fromBackend({
      'lineKey': 'dj_1|M|#FF000000',
      'product': productJson,
      'quantity': 3,
      'selectedSize': 'M',
      'selectedColor': '#FF000000',
    });
    expect(line.id, 'dj_1|M|#FF000000');
    expect(line.quantity, 3);
  });

  test('order maps cents, status and the open payment attempt', () {
    final o = OrderModel.fromApi({
      'id': 'a1b2c3d4-0000-0000-0000-000000000000',
      'status': 'PENDING_PAYMENT',
      'subtotalCents': 1798,
      'shippingCents': 1000,
      'taxCents': 144,
      'totalCents': 2942,
      'itemCount': 2,
      'createdAt': '2026-01-01T00:00:00.000Z',
      'expiresAt': '2026-01-01T00:15:00.000Z',
      'items': [
        {'productId': 'dj_1', 'title': 'Mascara', 'thumbnail': '', 'unitPriceCents': 899, 'quantity': 2},
      ],
      'payment': {
        'id': 'p1',
        'provider': 'mock',
        'status': 'CREATED',
        'clientSecret': 'pi_x_secret_y',
        'confirmUrl': 'http://localhost:8090/v1/payment_intents/pi_x/confirm',
      },
    });
    expect(o.total, 29.42);
    expect(o.items.single.product.effectivePrice, 8.99);
    expect(o.isAwaitingPayment, isTrue);
    expect(o.payment!.isOpen, isTrue);
    expect(o.statusLabel, 'Awaiting payment');
    expect(o.shortId, '#A1B2C3');
  });

  test('declined payment explains why', () {
    const p = PaymentInfo(id: 'p', provider: 'mock', status: 'FAILED', failureReason: 'insufficient_funds');
    expect(p.failureMessage, 'Your card has insufficient funds.');
  });
}
