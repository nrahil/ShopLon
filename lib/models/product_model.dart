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

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'] ?? '',
      image: json['image'] ?? '',
      brandName: json['brandName'] ?? '',
      title: json['title'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      priceAfetDiscount: json['priceAfetDiscount']?.toDouble(),
      dicountpercent: json['dicountpercent'],
    );
  }

  factory ProductModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ProductModel(
      id: doc.id,
      image: data['image'] ?? '',
      brandName: data['brandName'] ?? '',
      title: data['title'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      priceAfetDiscount: data['priceAfetDiscount']?.toDouble(),
      dicountpercent: data['dicountpercent'],
    );
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
