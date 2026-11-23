import 'package:shop/models/product_model.dart';

class CartItemModel {
  final String? id;
  final ProductModel product;
  int quantity;
  final String? selectedSize;
  final String? selectedColor;

  CartItemModel({
    this.id,
    required this.product,
    this.quantity = 1,
    this.selectedSize,
    this.selectedColor,
  });

  factory CartItemModel.fromJson(Map<String, dynamic> json, String docId) {
    return CartItemModel(
      id: docId,
      product: ProductModel.fromJson(
          Map<String, dynamic>.from(json['product'] as Map? ?? {})),
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      selectedSize: json['selectedSize'] as String?,
      selectedColor: json['selectedColor'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product': product.toJson(),
      'quantity': quantity,
      'selectedSize': selectedSize,
      'selectedColor': selectedColor,
    };
  }
}
