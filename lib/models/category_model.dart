import 'package:cloud_firestore/cloud_firestore.dart';

class CategoryModel {
  final String? id;
  final String title;
  final String? image, svgSrc;
  final List<CategoryModel>? subCategories;

  CategoryModel({
    this.id,
    required this.title,
    this.image,
    this.svgSrc,
    this.subCategories,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json, {String? docId}) {
    return CategoryModel(
      id: docId ?? json['id'],
      title: json['title'] ?? '',
      image: json['image'],
      svgSrc: json['svgSrc'],
      subCategories: json['subCategories'] != null
          ? (json['subCategories'] as List)
              .map((e) => CategoryModel.fromJson(e))
              .toList()
          : null,
    );
  }

  factory CategoryModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return CategoryModel.fromJson(data, docId: doc.id);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'image': image,
      'svgSrc': svgSrc,
      'subCategories': subCategories?.map((e) => e.toJson()).toList(),
    };
  }
}
