import 'package:flutter/material.dart';
import 'package:shop/components/product/secondary_product_card.dart';
import 'package:provider/provider.dart';
import 'package:shop/providers/product_provider.dart';

import '../../../../constants.dart';
import '../../../../route/route_constants.dart';

class MostPopular extends StatelessWidget {
  const MostPopular({
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
            "Most popular",
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        Consumer<ProductProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (provider.popularProducts.isEmpty) {
              return const Center(child: Text("No products found"));
            }
            return SizedBox(
              height: 114,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: provider.popularProducts.length,
                itemBuilder: (context, index) {
                  final product = provider.popularProducts[index];
                  return Padding(
                    padding: EdgeInsets.only(
                      left: defaultPadding,
                      right: index == provider.popularProducts.length - 1
                          ? defaultPadding
                          : 0,
                    ),
                    child: SecondaryProductCard(
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
