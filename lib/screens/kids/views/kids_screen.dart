import 'package:flutter/material.dart';
import 'package:shop/components/product/product_card.dart';
import 'package:provider/provider.dart';
import 'package:shop/providers/product_provider.dart';
import 'package:shop/constants.dart';
import 'package:shop/route/route_constants.dart';

class KidsScreen extends StatelessWidget {
  const KidsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Kids Collection"),
      ),
      body: Consumer<ProductProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.kidsProducts.isEmpty) {
            return const Center(child: Text("No kids products found"));
          }
          return GridView.builder(
            padding: const EdgeInsets.all(defaultPadding),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.7,
              crossAxisSpacing: defaultPadding,
              mainAxisSpacing: defaultPadding,
            ),
            itemCount: provider.kidsProducts.length,
            itemBuilder: (context, index) {
              final product = provider.kidsProducts[index];
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
          );
        },
      ),
    );
  }
}
