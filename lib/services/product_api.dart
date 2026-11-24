import 'package:shop/models/category_model.dart';
import 'package:shop/models/product_model.dart';
import 'package:shop/services/api_client.dart';

/// Thrown when the catalogue can't be loaded.
class ProductApiException implements Exception {
  ProductApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Catalogue endpoints of the ShopLon API (public, cached and paginated).
class ProductApi {
  ProductApi({ApiClient? client}) : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  /// Follows the keyset-pagination cursor until the whole catalogue is loaded.
  Future<List<ProductModel>> fetchProducts({String? category}) async {
    final products = <ProductModel>[];
    String? cursor;
    try {
      do {
        final page = await _api.get('/v1/products', auth: false, query: {
          'limit': '200',
          if (category != null) 'category': category,
          if (cursor != null) 'cursor': cursor,
        }) as Map<String, dynamic>;
        products.addAll((page['items'] as List)
            .whereType<Map>()
            .map((p) => ProductModel.fromBackend(Map<String, dynamic>.from(p))));
        cursor = page['nextCursor'] as String?;
      } while (cursor != null);
    } on ApiException catch (e) {
      throw ProductApiException(e.isNetwork
          ? "Couldn't reach the shop server. Is the backend running?"
          : e.message);
    }
    return products;
  }

  Future<List<CategoryModel>> fetchCategories() async {
    try {
      final data =
          await _api.get('/v1/categories', auth: false) as Map<String, dynamic>;
      return (data['items'] as List)
          .whereType<Map>()
          .map((c) => CategoryModel.fromApi(Map<String, dynamic>.from(c)))
          .toList();
    } on ApiException catch (e) {
      throw ProductApiException(e.isNetwork
          ? "Couldn't reach the shop server. Is the backend running?"
          : e.message);
    }
  }

  void close() {}
}
