import 'package:shop/models/product_model.dart';

class CartItemModel {
  final ProductModel product;
  int quantity;
  final String? selectedSize;
  final String? selectedColor;

  CartItemModel({
    required this.product,
    this.quantity = 1,
    this.selectedSize,
    this.selectedColor,
  });
}
