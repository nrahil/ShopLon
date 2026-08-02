import 'package:flutter/material.dart';
import 'package:shop/models/product_model.dart';

class WishlistProvider extends ChangeNotifier {
  // Using product titles as unique identifiers since models don't have IDs
  final Set<String> _wishlistedTitles = {};
  
  // Cache the actual product models for the bookmark screen
  final Map<String, ProductModel> _wishlistedProducts = {};

  List<ProductModel> get wishlistedItems => _wishlistedProducts.values.toList();

  bool isWishlisted(String title) {
    return _wishlistedTitles.contains(title);
  }

  void toggle(ProductModel product) {
    if (_wishlistedTitles.contains(product.title)) {
      _wishlistedTitles.remove(product.title);
      _wishlistedProducts.remove(product.title);
    } else {
      _wishlistedTitles.add(product.title);
      _wishlistedProducts[product.title] = product;
    }
    notifyListeners();
  }
}
