import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:shop/components/buy_full_ui_kit.dart';
import 'package:shop/components/cart_button.dart';
import 'package:shop/components/custom_modal_bottom_sheet.dart';
import 'package:shop/components/product/product_card.dart';
import 'package:shop/components/responsive.dart';
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

  /// At or above this width the image and the details sit side by side.
  static const double _twoColumnBreakpoint = 840;

  void _openSheet(BuildContext context, Widget child) {
    customModalBottomSheet(
      context,
      height: MediaQuery.sizeOf(context).height * 0.92,
      child: child,
    );
  }

  Widget _wishlistButton() {
    return Consumer<WishlistProvider>(
      builder: (context, wishlist, child) {
        final isWishlisted = wishlist.isWishlisted(product.id);
        return IconButton(
          tooltip: isWishlisted ? "Remove from wishlist" : "Add to wishlist",
          onPressed: () => wishlist.toggle(product),
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
    );
  }

  Widget _buyButton(BuildContext context) {
    if (!isProductAvailable) {
      // If the product is not available, show [NotifyMeCard].
      return NotifyMeCard(isNotify: false, onChanged: (value) {});
    }
    return CartButton(
      price: product.effectivePrice,
      press: () => _openSheet(context, ProductBuyNowScreen(product: product)),
    );
  }

  /// Everything below the images; shared by the one- and two-column layouts.
  List<Widget> _detailSlivers(
    BuildContext context,
    List<ProductModel> relatedProducts, {
    required bool includeBuyButton,
  }) {
    return [
      ProductInfo(
        brand: product.brandName,
        title: product.title,
        isAvailable: isProductAvailable,
        description:
            "${product.title} by ${product.brandName}. Crafted from quality materials for everyday comfort and style.",
        rating: 4.4,
        numOfReviews: 126,
      ),
      if (includeBuyButton) SliverToBoxAdapter(child: _buyButton(context)),
      ProductListTile(
        svgSrc: "assets/icons/Product.svg",
        title: "Product Details",
        press: () => _openSheet(
          context,
          const BuyFullKit(images: ["assets/screens/Product detail.png"]),
        ),
      ),
      ProductListTile(
        svgSrc: "assets/icons/Delivery.svg",
        title: "Shipping Information",
        press: () => _openSheet(
          context,
          const BuyFullKit(
            images: ["assets/screens/Shipping information.png"],
          ),
        ),
      ),
      ProductListTile(
        svgSrc: "assets/icons/Return.svg",
        title: "Returns",
        isShowBottomBorder: true,
        press: () => _openSheet(context, const ProductReturnsScreen()),
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
      if (relatedProducts.isNotEmpty) ...[
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
      ],
      const SliverToBoxAdapter(child: SizedBox(height: defaultPadding)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final relatedProducts = context
        .watch<ProductProvider>()
        .products
        .where((p) => p.id != product.id)
        .take(8)
        .toList();

    return ResponsivePage(
      maxWidth: Responsive.contentMaxWidth,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final twoColumns = constraints.maxWidth >= _twoColumnBreakpoint;
          final images = ProductImages(images: [product.image]);

          if (twoColumns) {
            return Scaffold(
              appBar: AppBar(
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                actions: [_wishlistButton()],
              ),
              body: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: Padding(
                      padding: const EdgeInsets.only(left: defaultPadding),
                      child: CustomScrollView(slivers: [images]),
                    ),
                  ),
                  Expanded(
                    flex: 6,
                    child: CustomScrollView(
                      slivers: _detailSlivers(
                        context,
                        relatedProducts,
                        includeBuyButton: true,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return Scaffold(
            bottomNavigationBar: _buyButton(context),
            body: SafeArea(
              child: CustomScrollView(
                slivers: [
                  SliverAppBar(
                    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                    floating: true,
                    actions: [_wishlistButton()],
                  ),
                  images,
                  ..._detailSlivers(
                    context,
                    relatedProducts,
                    includeBuyButton: false,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
