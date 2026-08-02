// Product catalog for ShopLon — Stark Industries
import 'package:shop/constants.dart';

class ProductModel {
  final String image, brandName, title;
  final double price;
  final double? priceAfetDiscount;
  final int? dicountpercent;

  ProductModel({
    required this.image,
    required this.brandName,
    required this.title,
    required this.price,
    this.priceAfetDiscount,
    this.dicountpercent,
  });
}

List<ProductModel> demoPopularProducts = [
  ProductModel(
    image: productDemoImg1,
    title: "Arc Reactor Hoodie — Unisex",
    brandName: "Stark Apparel",
    price: 540,
    priceAfetDiscount: 420,
    dicountpercent: 20,
  ),
  ProductModel(
    image: productDemoImg4,
    title: "Vibranium Series Joggers",
    brandName: "Stark Active",
    price: 800,
  ),
  ProductModel(
    image: productDemoImg5,
    title: "SI — Runner Pro X Sneakers",
    brandName: "Stark Footwear",
    price: 650.62,
    priceAfetDiscount: 390.36,
    dicountpercent: 40,
  ),
  ProductModel(
    image: productDemoImg6,
    title: "Emerald City Wrap Dress",
    brandName: "Stark Collection",
    price: 1264,
    priceAfetDiscount: 1200.8,
    dicountpercent: 5,
  ),
  ProductModel(
    image: "https://i.imgur.com/tXyOMMG.png",
    title: "Nano-Tech Slim Fit Blazer",
    brandName: "Stark Formals",
    price: 650.62,
    priceAfetDiscount: 390.36,
    dicountpercent: 40,
  ),
  ProductModel(
    image: "https://i.imgur.com/h2LqppX.png",
    title: "Precision Weave Corset Top",
    brandName: "Stark Collection",
    price: 1264,
    priceAfetDiscount: 1200.8,
    dicountpercent: 5,
  ),
];

List<ProductModel> demoFlashSaleProducts = [
  ProductModel(
    image: productDemoImg5,
    title: "SI — Runner Pro X Sneakers",
    brandName: "Stark Footwear",
    price: 650.62,
    priceAfetDiscount: 390.36,
    dicountpercent: 40,
  ),
  ProductModel(
    image: productDemoImg6,
    title: "Emerald City Wrap Dress",
    brandName: "Stark Collection",
    price: 1264,
    priceAfetDiscount: 1200.8,
    dicountpercent: 5,
  ),
  ProductModel(
    image: productDemoImg4,
    title: "Vibranium Series Joggers",
    brandName: "Stark Active",
    price: 800,
    priceAfetDiscount: 680,
    dicountpercent: 15,
  ),
];

List<ProductModel> demoBestSellersProducts = [
  ProductModel(
    image: "https://i.imgur.com/tXyOMMG.png",
    title: "Nano-Tech Slim Fit Blazer",
    brandName: "Stark Formals",
    price: 650.62,
    priceAfetDiscount: 390.36,
    dicountpercent: 40,
  ),
  ProductModel(
    image: "https://i.imgur.com/h2LqppX.png",
    title: "Precision Weave Corset Top",
    brandName: "Stark Collection",
    price: 1264,
    priceAfetDiscount: 1200.8,
    dicountpercent: 5,
  ),
  ProductModel(
    image: productDemoImg4,
    title: "Vibranium Series Joggers",
    brandName: "Stark Active",
    price: 800,
    priceAfetDiscount: 680,
    dicountpercent: 15,
  ),
];

List<ProductModel> kidsProducts = [
  ProductModel(
    image: "https://i.imgur.com/dbbT6PA.png",
    title: "Mini Arc — Kids Puffer Jacket",
    brandName: "Stark Jr.",
    price: 650.62,
    priceAfetDiscount: 590.36,
    dicountpercent: 24,
  ),
  ProductModel(
    image: "https://i.imgur.com/7fSxC7k.png",
    title: "StarKids Tiered Swing Dress",
    brandName: "Stark Jr.",
    price: 650.62,
  ),
  ProductModel(
    image: "https://i.imgur.com/pXnYE9Q.png",
    title: "Sheath Knit Dress — Toddler",
    brandName: "Stark Jr.",
    price: 400,
  ),
  ProductModel(
    image: "https://i.imgur.com/V1MXgfa.png",
    title: "Emerald Junior Windbreaker",
    brandName: "Stark Jr.",
    price: 400,
    priceAfetDiscount: 360,
    dicountpercent: 20,
  ),
  ProductModel(
    image: "https://i.imgur.com/8gvE5Ss.png",
    title: "Mini Stark Printed Tee Set",
    brandName: "Stark Jr.",
    price: 654,
  ),
  ProductModel(
    image: "https://i.imgur.com/cBvB5YB.png",
    title: "Kids Classic Canvas Sneaker",
    brandName: "Stark Footwear Jr.",
    price: 250,
  ),
];
