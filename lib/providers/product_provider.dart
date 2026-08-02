import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shop/models/product_model.dart';

class ProductProvider extends ChangeNotifier {
  List<ProductModel> _products = [];
  bool _isLoading = false;

  List<ProductModel> get products => _products;
  bool get isLoading => _isLoading;

  Future<void> fetchProducts() async {
    _isLoading = true;
    notifyListeners();

    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance.collection('products').get();
      _products = snapshot.docs.map((doc) => ProductModel.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint("Error fetching products: $e");
    }

    _isLoading = false;
    notifyListeners();
  }

  List<ProductModel> get popularProducts {
    // In a real app, you might have a field 'isPopular' in Firestore.
    // For now, we'll return a subset based on some logic or just the first few.
    if (_products.isEmpty) return [];
    return _products.take(4).toList();
  }

  List<ProductModel> get flashSaleProducts {
    return _products.where((p) => p.dicountpercent != null && p.dicountpercent! >= 15).toList();
  }

  List<ProductModel> get bestSellers {
    if (_products.length <= 4) return _products;
    return _products.skip(4).take(3).toList();
  }

  List<ProductModel> get kidsProducts {
    return _products.where((p) => p.brandName.contains('Jr.') || p.title.contains('Kids') || p.title.contains('Toddler')).toList();
  }
}
