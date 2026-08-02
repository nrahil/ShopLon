import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shop/models/product_model.dart';
import 'package:shop/models/category_model.dart';

import 'package:flutter/foundation.dart';

Future<void> seedDatabase() async {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  debugPrint("Starting database seed...");

  // Products Data
  List<ProductModel> allDemoProducts = [
    ProductModel(
      id: "p1",
      image: "https://i.imgur.com/CGCyp1d.png",
      title: "Arc Reactor Hoodie — Unisex",
      brandName: "Stark Apparel",
      price: 540,
      priceAfetDiscount: 420,
      dicountpercent: 20,
    ),
    ProductModel(
      id: "p2",
      image: "https://i.imgur.com/q9oF9Yq.png",
      title: "Vibranium Series Joggers",
      brandName: "Stark Active",
      price: 800,
      priceAfetDiscount: 680,
      dicountpercent: 15,
    ),
    ProductModel(
      id: "p3",
      image: "https://i.imgur.com/MsppAcx.png",
      title: "SI — Runner Pro X Sneakers",
      brandName: "Stark Footwear",
      price: 650.62,
      priceAfetDiscount: 390.36,
      dicountpercent: 40,
    ),
    ProductModel(
      id: "p4",
      image: "https://i.imgur.com/JfyZlnO.png",
      title: "Emerald City Wrap Dress",
      brandName: "Stark Collection",
      price: 1264,
      priceAfetDiscount: 1200.8,
      dicountpercent: 5,
    ),
    ProductModel(
      id: "p5",
      image: "https://i.imgur.com/tXyOMMG.png",
      title: "Nano-Tech Slim Fit Blazer",
      brandName: "Stark Formals",
      price: 650.62,
      priceAfetDiscount: 390.36,
      dicountpercent: 40,
    ),
    ProductModel(
      id: "p6",
      image: "https://i.imgur.com/h2LqppX.png",
      title: "Precision Weave Corset Top",
      brandName: "Stark Collection",
      price: 1264,
      priceAfetDiscount: 1200.8,
      dicountpercent: 5,
    ),
    // Kids
    ProductModel(
      id: "k1",
      image: "https://i.imgur.com/dbbT6PA.png",
      title: "Mini Arc — Kids Puffer Jacket",
      brandName: "Stark Jr.",
      price: 650.62,
      priceAfetDiscount: 590.36,
      dicountpercent: 24,
    ),
    ProductModel(
      id: "k2",
      image: "https://i.imgur.com/7fSxC7k.png",
      title: "StarKids Tiered Swing Dress",
      brandName: "Stark Jr.",
      price: 650.62,
    ),
    ProductModel(
      id: "k3",
      image: "https://i.imgur.com/pXnYE9Q.png",
      title: "Sheath Knit Dress — Toddler",
      brandName: "Stark Jr.",
      price: 400,
    ),
    ProductModel(
      id: "k4",
      image: "https://i.imgur.com/V1MXgfa.png",
      title: "Emerald Junior Windbreaker",
      brandName: "Stark Jr.",
      price: 400,
      priceAfetDiscount: 360,
      dicountpercent: 20,
    ),
    ProductModel(
      id: "k5",
      image: "https://i.imgur.com/8gvE5Ss.png",
      title: "Mini Stark Printed Tee Set",
      brandName: "Stark Jr.",
      price: 654,
    ),
    ProductModel(
      id: "k6",
      image: "https://i.imgur.com/cBvB5YB.png",
      title: "Kids Classic Canvas Sneaker",
      brandName: "Stark Footwear Jr.",
      price: 250,
    ),
  ];

  WriteBatch productBatch = firestore.batch();
  for (var product in allDemoProducts) {
    DocumentReference docRef = firestore.collection('products').doc(product.id);
    productBatch.set(docRef, product.toJson());
  }
  await productBatch.commit();
  debugPrint("Products seeded successfully.");

  // Categories Data
  List<CategoryModel> allDemoCategories = [
    CategoryModel(id: 'c1', title: "On sale", svgSrc: "assets/icons/Sale.svg"),
    CategoryModel(id: 'c2', title: "Man’s & Woman’s", svgSrc: "assets/icons/Man&Woman.svg"),
    CategoryModel(id: 'c3', title: "Kids", svgSrc: "assets/icons/Child.svg"),
    CategoryModel(id: 'c4', title: "Accessories", svgSrc: "assets/icons/Accessories.svg"),
  ];
  
  WriteBatch categoryBatch = firestore.batch();
  for (var category in allDemoCategories) {
    DocumentReference docRef = firestore.collection('categories').doc(category.id);
    categoryBatch.set(docRef, category.toJson());
  }
  await categoryBatch.commit();
  debugPrint("Categories seeded successfully.");
}
