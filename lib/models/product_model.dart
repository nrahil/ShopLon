import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewModel {
  final int rating;
  final String comment;
  final String reviewerName;
  final DateTime? date;

  const ReviewModel({
    required this.rating,
    required this.comment,
    required this.reviewerName,
    this.date,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      rating: (json['rating'] as num?)?.toInt() ?? 0,
      comment: json['comment'] as String? ?? '',
      reviewerName: json['reviewerName'] as String? ?? 'Anonymous',
      date: DateTime.tryParse(json['date'] as String? ?? ''),
    );
  }
}

class ProductModel {
  final String id;
  final String image, brandName, title;
  final double price;
  final double? priceAfetDiscount;
  final int? dicountpercent;

  // Extra details (filled from the product API; optional for older saved items).
  final String description;
  final String category;
  final double rating;
  final int stock;
  final List<String> images;
  final List<ReviewModel> reviews;
  final String? shippingInformation;
  final String? warrantyInformation;
  final String? returnPolicy;

  ProductModel({
    required this.id,
    required this.image,
    required this.brandName,
    required this.title,
    required this.price,
    this.priceAfetDiscount,
    this.dicountpercent,
    this.description = '',
    this.category = '',
    this.rating = 0,
    this.stock = 1,
    this.images = const [],
    this.reviews = const [],
    this.shippingInformation,
    this.warrantyInformation,
    this.returnPolicy,
  });

  /// Price the customer actually pays.
  double get effectivePrice => priceAfetDiscount ?? price;

  bool get isAvailable => stock > 0;

  /// All images to show in the gallery, main image first.
  List<String> get gallery {
    final all = <String>[if (image.isNotEmpty) image, ...images];
    return all.toSet().toList();
  }

  /// Builds a product from the DummyJSON API (https://dummyjson.com/docs/products).
  factory ProductModel.fromApi(Map<String, dynamic> json) {
    final price = (json['price'] as num?)?.toDouble() ?? 0;
    final discount = (json['discountPercentage'] as num?)?.toDouble() ?? 0;
    final roundedDiscount = discount.round();
    final hasDiscount = roundedDiscount >= 1;
    final images =
        (json['images'] as List?)?.whereType<String>().toList() ?? [];

    return ProductModel(
      id: 'dj_${json['id']}',
      image: json['thumbnail'] as String? ??
          (images.isNotEmpty ? images.first : ''),
      brandName: (json['brand'] as String?) ??
          _titleCase(json['category'] as String? ?? 'ShopLon'),
      title: json['title'] as String? ?? '',
      price: price,
      priceAfetDiscount: hasDiscount
          ? double.parse((price * (1 - discount / 100)).toStringAsFixed(2))
          : null,
      dicountpercent: hasDiscount ? roundedDiscount : null,
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      stock: (json['stock'] as num?)?.toInt() ?? 0,
      images: images,
      reviews: (json['reviews'] as List?)
              ?.whereType<Map>()
              .map((r) => ReviewModel.fromJson(Map<String, dynamic>.from(r)))
              .toList() ??
          const [],
      shippingInformation: json['shippingInformation'] as String?,
      warrantyInformation: json['warrantyInformation'] as String?,
      returnPolicy: json['returnPolicy'] as String?,
    );
  }

  /// Builds a product from the ShopLon API. Money arrives as integer cents,
  /// and the sale price is computed by the server, not here.
  factory ProductModel.fromBackend(Map<String, dynamic> json) {
    final priceCents = (json['priceCents'] as num?)?.toInt() ?? 0;
    final saleCents = (json['salePriceCents'] as num?)?.toInt() ?? priceCents;
    final discount = (json['discountPercent'] as num?)?.toInt() ?? 0;
    final category = json['category'] as String? ?? '';
    final hasDiscount = discount >= 1 && saleCents < priceCents;
    return ProductModel(
      id: json['id'] as String? ?? '',
      image: json['thumbnail'] as String? ?? '',
      brandName: (json['brand'] as String?) ??
          _titleCase(category.isEmpty ? 'ShopLon' : category),
      title: json['title'] as String? ?? '',
      price: priceCents / 100,
      priceAfetDiscount: hasDiscount ? saleCents / 100 : null,
      dicountpercent: hasDiscount ? discount : null,
      description: json['description'] as String? ?? '',
      category: category,
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      stock: (json['stock'] as num?)?.toInt() ?? 0,
      images: (json['images'] as List?)?.whereType<String>().toList() ?? [],
      reviews: (json['reviews'] as List?)
              ?.whereType<Map>()
              .map((r) => ReviewModel.fromJson(Map<String, dynamic>.from(r)))
              .toList() ??
          const [],
      shippingInformation: json['shippingInformation'] as String?,
      warrantyInformation: json['warrantyInformation'] as String?,
      returnPolicy: json['returnPolicy'] as String?,
    );
  }

  /// Builds a product saved in Firestore (wishlist).
  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: (json['id'] ?? '').toString(),
      image: json['image'] as String? ?? '',
      brandName: json['brandName'] as String? ?? '',
      title: json['title'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      priceAfetDiscount: (json['priceAfetDiscount'] as num?)?.toDouble(),
      dicountpercent: (json['dicountpercent'] as num?)?.toInt(),
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      stock: (json['stock'] as num?)?.toInt() ?? 1,
      images:
          (json['images'] as List?)?.whereType<String>().toList() ?? const [],
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
      'description': description,
      'category': category,
      'rating': rating,
      'stock': stock,
      'images': images,
    };
  }

  static String _titleCase(String slug) => slug
      .split(RegExp(r'[-_ ]'))
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');
}
