import 'package:flutter/material.dart';
import 'package:shop/components/product/product_card.dart';
import 'package:provider/provider.dart';
import 'package:shop/providers/product_provider.dart';

import '../../../../constants.dart';
import '../../../../route/route_constants.dart';

class BestSellers extends StatelessWidget {
  const BestSellers({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: defaultPadding / 2),
        Padding(
          padding: const EdgeInsets.all(defaultPadding),
          child: Text(
            "Best sellers",
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        Consumer<ProductProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (provider.bestSellers.isEmpty) {
              return const Center(child: Text("No products found"));
            }
            return SizedBox(
              height: 220,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: provider.bestSellers.length,
                itemBuilder: (context, index) {
                  final product = provider.bestSellers[index];
                  return Padding(
                    padding: EdgeInsets.only(
                      left: defaultPadding,
                      right: index == provider.bestSellers.length - 1
                          ? defaultPadding
                          : 0,
                    ),
                    child: ProductCard(
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
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}
