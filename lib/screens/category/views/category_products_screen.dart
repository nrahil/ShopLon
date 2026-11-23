import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shop/components/load_error.dart';
import 'package:shop/components/product/product_card.dart';
import 'package:shop/components/responsive.dart';
import 'package:shop/constants.dart';
import 'package:shop/models/category_model.dart';
import 'package:shop/providers/product_provider.dart';
import 'package:shop/route/route_constants.dart';

/// Products in one category, or the whole catalogue when [category] is null.
class CategoryProductsScreen extends StatefulWidget {
  const CategoryProductsScreen({super.key, this.category});

  final CategoryModel? category;

  @override
  State<CategoryProductsScreen> createState() => _CategoryProductsScreenState();
}

enum _Sort { featured, priceLow, priceHigh, rating, discount }

class _CategoryProductsScreenState extends State<CategoryProductsScreen> {
  _Sort _sort = _Sort.featured;

  static const _sortLabels = {
    _Sort.featured: "Featured",
    _Sort.priceLow: "Price: low to high",
    _Sort.priceHigh: "Price: high to low",
    _Sort.rating: "Top rated",
    _Sort.discount: "Biggest discount",
  };

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductProvider>();
    final category = widget.category;
    final products = [
      ...(category == null
          ? provider.products
          : provider.inCategory(category.slug)),
    ];

    switch (_sort) {
      case _Sort.featured:
        break;
      case _Sort.priceLow:
        products.sort((a, b) => a.effectivePrice.compareTo(b.effectivePrice));
      case _Sort.priceHigh:
        products.sort((a, b) => b.effectivePrice.compareTo(a.effectivePrice));
      case _Sort.rating:
        products.sort((a, b) => b.rating.compareTo(a.rating));
      case _Sort.discount:
        products.sort(
            (a, b) => (b.dicountpercent ?? 0).compareTo(a.dicountpercent ?? 0));
    }

    Widget body;
    if (provider.isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (provider.error != null && provider.products.isEmpty) {
      body = LoadError(
        message: provider.error!,
        onRetry: provider.fetchProducts,
      );
    } else if (products.isEmpty) {
      body = const Center(child: Text("No products in this category yet"));
    } else {
      body = CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
                defaultPadding, defaultPadding / 2, defaultPadding, 0),
            sliver: SliverToBoxAdapter(
              child: Text(
                "${products.length} products",
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(defaultPadding),
            sliver: SliverGrid(
              gridDelegate: productGridDelegate,
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final product = products[index];
                  return ProductCard(
                    image: product.image,
                    brandName: product.brandName,
                    title: product.title,
                    price: product.price,
                    priceAfetDiscount: product.priceAfetDiscount,
                    dicountpercent: product.dicountpercent,
                    press: () {
                      Navigator.pushNamed(context, productDetailsScreenRoute,
                          arguments: product);
                    },
                  );
                },
                childCount: products.length,
              ),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(category?.title ?? "All products"),
        actions: [
          PopupMenuButton<_Sort>(
            tooltip: "Sort",
            icon: const Icon(Icons.sort),
            initialValue: _sort,
            onSelected: (value) => setState(() => _sort = value),
            itemBuilder: (context) => [
              for (final entry in _sortLabels.entries)
                PopupMenuItem(value: entry.key, child: Text(entry.value)),
            ],
          ),
        ],
      ),
      body: body,
    );
  }
}
