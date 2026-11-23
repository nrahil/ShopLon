import 'package:flutter/material.dart';
import 'package:shop/models/category_model.dart';
import 'package:shop/services/product_api.dart';

/// Loads product categories from the public DummyJSON API.
class CategoryProvider extends ChangeNotifier {
  CategoryProvider({ProductApi? api}) : _api = api ?? ProductApi();

  final ProductApi _api;

  List<CategoryModel> _categories = [];
  bool _isLoading = false;
  String? _error;

  List<CategoryModel> get categories => _categories;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchCategories() async {
    if (_isLoading) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _categories = await _api.fetchCategories();
    } catch (e) {
      debugPrint("Error fetching categories: $e");
      _error = e is ProductApiException
          ? e.message
          : "Couldn't load categories. Please try again.";
    }

    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }
}
