import 'package:flutter/material.dart';
import 'package:shop/models/product_model.dart';
import 'package:shop/services/product_api.dart';

/// Loads the product catalogue from the public DummyJSON API.
class ProductProvider extends ChangeNotifier {
  ProductProvider({ProductApi? api}) : _api = api ?? ProductApi();

  final ProductApi _api;

  List<ProductModel> _products = [];
  bool _isLoading = false;
  String? _error;

  List<ProductModel> get products => _products;
  bool get isLoading => _isLoading;

  /// User-facing message when the last load failed; null on success.
  String? get error => _error;

  Future<void> fetchProducts() async {
    if (_isLoading) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _products = await _api.fetchProducts();
    } catch (e) {
      debugPrint("Error fetching products: $e");
      _error = e is ProductApiException
          ? e.message
          : "Couldn't load products. Please try again.";
    }

    _isLoading = false;
    notifyListeners();
  }

  ProductModel? byId(String id) {
    for (final p in _products) {
      if (p.id == id) return p;
    }
    return null;
  }

  List<ProductModel> inCategory(String slug) =>
      _products.where((p) => p.category == slug).toList();

  /// Highest-rated products.
  List<ProductModel> get popularProducts {
    final sorted = [..._products]..sort((a, b) => b.rating.compareTo(a.rating));
    return sorted.take(10).toList();
  }

  /// Biggest discounts first (15% off or more).
  List<ProductModel> get flashSaleProducts {
    final onSale = _products
        .where((p) => p.dicountpercent != null && p.dicountpercent! >= 15)
        .toList()
      ..sort((a, b) => b.dicountpercent!.compareTo(a.dicountpercent!));
    return onSale;
  }

  /// "Selling fast": lowest stock that's still available.
  List<ProductModel> get bestSellers {
    final sorted = _products.where((p) => p.isAvailable).toList()
      ..sort((a, b) => a.stock.compareTo(b.stock));
    return sorted.take(10).toList();
  }

  /// One top-rated product from each category, for variety.
  List<ProductModel> get mostPopular {
    final best = <String, ProductModel>{};
    for (final p in _products) {
      final current = best[p.category];
      if (current == null || p.rating > current.rating) best[p.category] = p;
    }
    return best.values.take(12).toList();
  }

  /// The catalogue has no kids section, so this shows fashion items under $30.
  List<ProductModel> get kidsProducts => _products
      .where((p) =>
          const ['tops', 'womens-dresses', 'mens-shirts', 'sports-accessories']
              .contains(p.category) &&
          p.effectivePrice < 30)
      .toList();

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }
}
