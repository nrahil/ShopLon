import 'package:flutter/material.dart';
import 'package:shop/route/route_constants.dart';
import 'package:provider/provider.dart';
import 'package:shop/providers/product_provider.dart';

import '/components/Banner/M/banner_m_with_counter.dart';
import '../../../../components/product/product_card.dart';
import '../../../../constants.dart';

class FlashSale extends StatelessWidget {
  const FlashSale({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BannerMWithCounter(
          duration: const Duration(hours: 8),
          text: "Super Flash Sale \n50% Off",
          press: () {},
        ),
        const SizedBox(height: defaultPadding / 2),
        Padding(
          padding: const EdgeInsets.all(defaultPadding),
          child: Text(
            "Flash sale",
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        Consumer<ProductProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (provider.flashSaleProducts.isEmpty) {
              return const Center(child: Text("No products on sale right now"));
            }
            return SizedBox(
              height: 220,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: provider.flashSaleProducts.length,
                itemBuilder: (context, index) {
                  final product = provider.flashSaleProducts[index];
                  return Padding(
                    padding: EdgeInsets.only(
                      left: defaultPadding,
                      right: index == provider.flashSaleProducts.length - 1
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
