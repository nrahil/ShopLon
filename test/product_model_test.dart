import 'package:flutter_test/flutter_test.dart';
import 'package:shop/models/category_model.dart';
import 'package:shop/models/product_model.dart';

void main() {
  // Trimmed copy of https://dummyjson.com/products/1
  final apiJson = <String, dynamic>{
    "id": 1,
    "title": "Essence Mascara Lash Princess",
    "description": "A popular mascara.",
    "category": "beauty",
    "price": 9.99,
    "discountPercentage": 10.48,
    "rating": 2.56,
    "stock": 99,
    "brand": "Essence",
    "thumbnail": "https://cdn.dummyjson.com/thumb.webp",
    "images": ["https://cdn.dummyjson.com/1.webp"],
    "shippingInformation": "Ships in 3-5 business days",
    "reviews": [
      {
        "rating": 3,
        "comment": "Ok",
        "reviewerName": "A",
        "date": "2025-04-30T09:41:02.053Z"
      },
      {
        "rating": 5,
        "comment": "Great",
        "reviewerName": "B",
        "date": "2025-04-30T09:41:02.053Z"
      },
    ],
  };

  test('fromApi maps prices, discount and details', () {
    final p = ProductModel.fromApi(apiJson);
    expect(p.id, 'dj_1');
    expect(p.brandName, 'Essence');
    expect(p.image, 'https://cdn.dummyjson.com/thumb.webp');
    expect(p.price, 9.99);
    expect(p.dicountpercent, 10);
    expect(p.priceAfetDiscount, closeTo(8.94, 0.001));
    expect(p.effectivePrice, p.priceAfetDiscount);
    expect(p.reviews.length, 2);
    expect(p.gallery, [
      'https://cdn.dummyjson.com/thumb.webp',
      'https://cdn.dummyjson.com/1.webp',
    ]);
    expect(p.isAvailable, isTrue);
  });

  test('fromApi falls back to category name when brand is missing', () {
    final p = ProductModel.fromApi(
        {...apiJson, 'brand': null, 'category': 'home-decoration'});
    expect(p.brandName, 'Home Decoration');
  });

  test('tiny discounts are not shown as a sale', () {
    final p = ProductModel.fromApi({...apiJson, 'discountPercentage': 0.3});
    expect(p.dicountpercent, isNull);
    expect(p.priceAfetDiscount, isNull);
    expect(p.effectivePrice, 9.99);
  });

  test('toJson/fromJson round-trip keeps cart and wishlist data', () {
    final p = ProductModel.fromApi(apiJson);
    final copy = ProductModel.fromJson(p.toJson());
    expect(copy.id, p.id);
    expect(copy.effectivePrice, p.effectivePrice);
    expect(copy.category, 'beauty');
    expect(copy.stock, 99);
  });

  test('category from API gets slug and an icon', () {
    final c = CategoryModel.fromApi(
        {'slug': 'mens-shirts', 'name': 'Mens Shirts', 'url': ''});
    expect(c.slug, 'mens-shirts');
    expect(c.title, 'Mens Shirts');
    expect(c.svgSrc, 'assets/icons/Man.svg');
  });
}
