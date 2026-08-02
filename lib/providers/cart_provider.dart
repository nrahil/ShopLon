import 'package:flutter/material.dart';
import 'package:shop/models/cart_item_model.dart';
import 'package:shop/models/product_model.dart';

class CartProvider extends ChangeNotifier {
  final List<CartItemModel> _cartItems = [];

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

  double get shippingTotal => 10.0; // Mock fixed shipping
  double get taxTotal => subtotal * 0.08; // 8% mock tax

  double get totalPrice => subtotal + shippingTotal + taxTotal;

  void addToCart(ProductModel product, {int quantity = 1, String? size, String? color}) {
    // Check if same item with same attributes exists
    int index = _cartItems.indexWhere((item) => 
      item.product.title == product.title && 
      item.selectedSize == size && 
      item.selectedColor == color
    );

    if (index >= 0) {
      _cartItems[index].quantity += quantity;
    } else {
      _cartItems.add(CartItemModel(
        product: product,
        quantity: quantity,
        selectedSize: size,
        selectedColor: color,
      ));
    }
    notifyListeners();
  }

  void removeFromCart(CartItemModel item) {
    _cartItems.remove(item);
    notifyListeners();
  }

  void updateQuantity(CartItemModel item, int newQuantity) {
    if (newQuantity <= 0) {
      removeFromCart(item);
    } else {
      item.quantity = newQuantity;
      notifyListeners();
    }
  }

  void clearCart() {
    _cartItems.clear();
    notifyListeners();
  }
}
