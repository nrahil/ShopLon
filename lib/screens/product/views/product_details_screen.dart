import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:shop/components/buy_full_ui_kit.dart';
import 'package:shop/components/cart_button.dart';
import 'package:shop/components/custom_modal_bottom_sheet.dart';
import 'package:shop/components/product/product_card.dart';
import 'package:shop/constants.dart';
import 'package:shop/screens/product/views/product_returns_screen.dart';

import 'package:shop/route/screen_export.dart';
import 'package:provider/provider.dart';
import 'package:shop/providers/product_provider.dart';
import 'package:shop/providers/wishlist_provider.dart';
import 'package:shop/models/product_model.dart';

import 'components/notify_me_card.dart';
import 'components/product_images.dart';
import 'components/product_info.dart';
import 'components/product_list_tile.dart';
import '../../../components/review_card.dart';
import 'product_buy_now_screen.dart';

class ProductDetailsScreen extends StatelessWidget {
  const ProductDetailsScreen({
    super.key,
    required this.product,
    this.isProductAvailable = true,
  });

  final ProductModel product;
  final bool isProductAvailable;

  @override
  Widget build(BuildContext context) {
    final relatedProducts = context
        .watch<ProductProvider>()
        .products
        .where((p) => p.id != product.id)
        .take(5)
        .toList();

    return Scaffold(
      bottomNavigationBar: isProductAvailable
          ? CartButton(
              price: product.effectivePrice,
              press: () {
                customModalBottomSheet(
                  context,
                  height: MediaQuery.of(context).size.height * 0.92,
                  child: ProductBuyNowScreen(product: product),
                );
              },
            )
          :

          /// If profuct is not available then show [NotifyMeCard]
          NotifyMeCard(
              isNotify: false,
              onChanged: (value) {},
            ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              floating: true,
              actions: [
                Consumer<WishlistProvider>(
                  builder: (context, wishlist, child) {
                    final isWishlisted = wishlist.isWishlisted(product.id);
                    return IconButton(
                      tooltip: isWishlisted
                          ? "Remove from wishlist"
                          : "Add to wishlist",
                      onPressed: () {
                        wishlist.toggle(product);
                      },
                      icon: isWishlisted
                          ? const Icon(Icons.bookmark, color: primaryColor)
                          : SvgPicture.asset(
                              "assets/icons/Bookmark.svg",
                              colorFilter: ColorFilter.mode(
                                Theme.of(context).textTheme.bodyLarge!.color!,
                                BlendMode.srcIn,
                              ),
                            ),
                    );
                  },
                ),
              ],
            ),
            ProductImages(images: [product.image]),
            ProductInfo(
              brand: product.brandName,
              title: product.title,
              isAvailable: isProductAvailable,
              description:
                  "${product.title} by ${product.brandName}. Crafted from quality materials for everyday comfort and style.",
              rating: 4.4,
              numOfReviews: 126,
            ),
            ProductListTile(
              svgSrc: "assets/icons/Product.svg",
              title: "Product Details",
              press: () {
                customModalBottomSheet(
                  context,
                  height: MediaQuery.of(context).size.height * 0.92,
                  child: const BuyFullKit(
                      images: ["assets/screens/Product detail.png"]),
                );
              },
            ),
            ProductListTile(
              svgSrc: "assets/icons/Delivery.svg",
              title: "Shipping Information",
              press: () {
                customModalBottomSheet(
                  context,
                  height: MediaQuery.of(context).size.height * 0.92,
                  child: const BuyFullKit(
                    images: ["assets/screens/Shipping information.png"],
                  ),
                );
              },
            ),
            ProductListTile(
              svgSrc: "assets/icons/Return.svg",
              title: "Returns",
              isShowBottomBorder: true,
              press: () {
                customModalBottomSheet(
                  context,
                  height: MediaQuery.of(context).size.height * 0.92,
                  child: const ProductReturnsScreen(),
                );
              },
            ),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(defaultPadding),
                child: ReviewCard(
                  rating: 4.3,
                  numOfReviews: 128,
                  numOfFiveStar: 80,
                  numOfFourStar: 30,
                  numOfThreeStar: 5,
                  numOfTwoStar: 4,
                  numOfOneStar: 1,
                ),
              ),
            ),
            ProductListTile(
              svgSrc: "assets/icons/Chat.svg",
              title: "Reviews",
              isShowBottomBorder: true,
              press: () {
                Navigator.pushNamed(context, productReviewsScreenRoute);
              },
            ),
            SliverPadding(
              padding: const EdgeInsets.all(defaultPadding),
              sliver: SliverToBoxAdapter(
                child: Text(
                  "You may also like",
                  style: Theme.of(context).textTheme.titleSmall!,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 220,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: relatedProducts.length,
                  itemBuilder: (context, index) {
                    final related = relatedProducts[index];
                    return Padding(
                      padding: EdgeInsets.only(
                          left: defaultPadding,
                          right: index == relatedProducts.length - 1
                              ? defaultPadding
                              : 0),
                      child: ProductCard(
                        image: related.image,
                        title: related.title,
                        brandName: related.brandName,
                        price: related.price,
                        priceAfetDiscount: related.priceAfetDiscount,
                        dicountpercent: related.dicountpercent,
                        press: () {
                          Navigator.pushReplacementNamed(
                            context,
                            productDetailsScreenRoute,
                            arguments: related,
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: defaultPadding),
            )
          ],
        ),
      ),
    );
  }
}
