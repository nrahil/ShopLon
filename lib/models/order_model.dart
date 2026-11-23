import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shop/models/cart_item_model.dart';

class OrderModel {
  final String id;
  final List<CartItemModel> items;
  final int itemCount;
  final double subtotal, shipping, tax, total;
  final String status;
  final DateTime? createdAt;

  const OrderModel({
    required this.id,
    required this.items,
    required this.itemCount,
    required this.subtotal,
    required this.shipping,
    required this.tax,
    required this.total,
    required this.status,
    this.createdAt,
  });

  factory OrderModel.fromFirestore(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final rawItems = data['items'] as List? ?? const [];
    final items = <CartItemModel>[];
    for (var i = 0; i < rawItems.length; i++) {
      final raw = rawItems[i];
      if (raw is Map) {
        items.add(CartItemModel.fromJson(
            Map<String, dynamic>.from(raw), '${doc.id}_$i'));
      }
    }
    double num_(String key) => (data[key] as num?)?.toDouble() ?? 0;

    return OrderModel(
      id: doc.id,
      items: items,
      itemCount: (data['itemCount'] as num?)?.toInt() ?? items.length,
      subtotal: num_('subtotal'),
      shipping: num_('shipping'),
      tax: num_('tax'),
      total: num_('total'),
      status: data['status'] as String? ?? 'Processing',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Short, readable order number, e.g. "#A1B2C3".
  String get shortId =>
      '#${id.substring(0, id.length < 6 ? id.length : 6).toUpperCase()}';
}
