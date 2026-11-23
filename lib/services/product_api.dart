import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shop/models/category_model.dart';
import 'package:shop/models/product_model.dart';

/// Thrown when the product API can't be reached or returns bad data.
class ProductApiException implements Exception {
  ProductApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Public product catalogue from DummyJSON (https://dummyjson.com).
/// Free, no API key required, and CORS-enabled so it works on web.
class ProductApi {
  ProductApi({http.Client? client}) : _client = client ?? http.Client();

  static const String _baseUrl = 'https://dummyjson.com';
  static const Duration _timeout = Duration(seconds: 20);

  final http.Client _client;

  Future<dynamic> _get(String path) async {
    final http.Response response;
    try {
      response =
          await _client.get(Uri.parse('$_baseUrl$path')).timeout(_timeout);
    } catch (e) {
      throw ProductApiException(
          "Couldn't reach the product server. Check your internet connection.");
    }
    if (response.statusCode != 200) {
      throw ProductApiException(
          'Product server error (${response.statusCode}). Please try again.');
    }
    try {
      return jsonDecode(response.body);
    } catch (_) {
      throw ProductApiException(
          'Received invalid data from the product server.');
    }
  }

  /// All products (limit=0 returns the full catalogue, ~200 items).
  Future<List<ProductModel>> fetchProducts() async {
    final data = await _get('/products?limit=0');
    final list = (data is Map ? data['products'] : null) as List? ?? const [];
    return list
        .whereType<Map>()
        .map((p) => ProductModel.fromApi(Map<String, dynamic>.from(p)))
        .toList();
  }

  Future<List<CategoryModel>> fetchCategories() async {
    final data = await _get('/products/categories');
    final list = data is List ? data : const [];
    return list
        .whereType<Map>()
        .map((c) => CategoryModel.fromApi(Map<String, dynamic>.from(c)))
        .toList();
  }

  void close() => _client.close();
}
