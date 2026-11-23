import 'package:cloud_firestore/cloud_firestore.dart';

class CategoryModel {
  final String? id;

  /// API identifier used to filter products, e.g. "mens-shirts".
  final String slug;
  final String title;
  final String? image, svgSrc;
  final List<CategoryModel>? subCategories;

  CategoryModel({
    this.id,
    String? slug,
    required this.title,
    this.image,
    this.svgSrc,
    this.subCategories,
  }) : slug = slug ?? id ?? title.toLowerCase();

  /// Builds a category from DummyJSON's /products/categories.
  factory CategoryModel.fromApi(Map<String, dynamic> json) {
    final slug = json['slug'] as String? ?? '';
    return CategoryModel(
      id: slug,
      slug: slug,
      title: json['name'] as String? ?? slug,
      svgSrc: iconFor(slug),
    );
  }

  factory CategoryModel.fromJson(Map<String, dynamic> json, {String? docId}) {
    return CategoryModel(
      id: docId ?? json['id'],
      slug: json['slug'],
      title: json['title'] ?? '',
      image: json['image'],
      svgSrc: json['svgSrc'],
      subCategories: json['subCategories'] != null
          ? (json['subCategories'] as List)
              .map((e) => CategoryModel.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : null,
    );
  }

  factory CategoryModel.fromFirestore(DocumentSnapshot doc) {
    final data = Map<String, dynamic>.from(doc.data() as Map? ?? {});
    return CategoryModel.fromJson(data, docId: doc.id);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'slug': slug,
      'title': title,
      'image': image,
      'svgSrc': svgSrc,
      'subCategories': subCategories?.map((e) => e.toJson()).toList(),
    };
  }

  /// Picks one of the bundled icons for an API category.
  static String iconFor(String slug) {
    if (slug.startsWith('mens-')) return 'assets/icons/Man.svg';
    if (slug.startsWith('womens-') || slug == 'tops') {
      return 'assets/icons/Woman.svg';
    }
    switch (slug) {
      case 'beauty':
      case 'skin-care':
      case 'fragrances':
        return 'assets/icons/diamond.svg';
      case 'groceries':
        return 'assets/icons/Bag.svg';
      case 'furniture':
      case 'home-decoration':
      case 'kitchen-accessories':
        return 'assets/icons/Stores.svg';
      case 'laptops':
      case 'smartphones':
      case 'tablets':
      case 'mobile-accessories':
        return 'assets/icons/Scan.svg';
      case 'sunglasses':
        return 'assets/icons/Show.svg';
      case 'sports-accessories':
        return 'assets/icons/Flashlight.svg';
      case 'motorcycle':
      case 'vehicle':
        return 'assets/icons/Delivery.svg';
      default:
        return 'assets/icons/Category.svg';
    }
  }
}
