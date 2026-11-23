import 'package:cloud_firestore/cloud_firestore.dart';

class ProductModel {
  final String id;
  final String image, brandName, title;
  final double price;
  final double? priceAfetDiscount;
  final int? dicountpercent;

  ProductModel({
    required this.id,
    required this.image,
    required this.brandName,
    required this.title,
    required this.price,
    this.priceAfetDiscount,
    this.dicountpercent,
  });

  /// Price the customer actually pays.
  double get effectivePrice => priceAfetDiscount ?? price;

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: (json['id'] ?? '').toString(),
      image: json['image'] as String? ?? '',
      brandName: json['brandName'] as String? ?? '',
      title: json['title'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      priceAfetDiscount: (json['priceAfetDiscount'] as num?)?.toDouble(),
      dicountpercent: (json['dicountpercent'] as num?)?.toInt(),
    );
  }

  factory ProductModel.fromFirestore(DocumentSnapshot doc) {
    final data = Map<String, dynamic>.from(doc.data() as Map? ?? {});
    return ProductModel.fromJson({...data, 'id': doc.id});
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'image': image,
      'brandName': brandName,
      'title': title,
      'price': price,
      'priceAfetDiscount': priceAfetDiscount,
      'dicountpercent': dicountpercent,
    };
  }
}
