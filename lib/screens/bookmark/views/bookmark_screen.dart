import 'package:flutter/material.dart';
import 'package:shop/components/product/product_card.dart';
import 'package:shop/route/route_constants.dart';

import 'package:provider/provider.dart';
import 'package:shop/providers/wishlist_provider.dart';
import '../../../constants.dart';

class BookmarkScreen extends StatelessWidget {
  const BookmarkScreen({super.key, this.showAppBar = true});

  /// False when shown as a tab inside [EntryPoint], which has its own AppBar.
  final bool showAppBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: showAppBar ? AppBar(title: const Text("Wishlist")) : null,
      body: Consumer<WishlistProvider>(
        builder: (context, wishlist, child) {
          final items = wishlist.wishlistedItems;
          if (items.isEmpty) {
            return const Center(
              child: Text("Your wishlist is empty"),
            );
          }
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                    horizontal: defaultPadding, vertical: defaultPadding),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200.0,
                    mainAxisSpacing: defaultPadding,
                    crossAxisSpacing: defaultPadding,
                    childAspectRatio: 0.66,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (BuildContext context, int index) {
                      return ProductCard(
                        image: items[index].image,
                        brandName: items[index].brandName,
                        title: items[index].title,
                        price: items[index].price,
                        priceAfetDiscount: items[index].priceAfetDiscount,
                        dicountpercent: items[index].dicountpercent,
                        press: () {
                          Navigator.pushNamed(context, productDetailsScreenRoute, arguments: items[index]);
                        },
                      );
                    },
                    childCount: items.length,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
