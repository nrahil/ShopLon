import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:shop/components/info_sheet.dart';
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

  bool get _available => isProductAvailable && product.isAvailable;

  int _starCount(int stars) =>
      product.reviews.where((r) => r.rating == stars).length;

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
    if (!_available) {
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
        isAvailable: _available,
        description: product.description.isNotEmpty
            ? product.description
            : "${product.title} by ${product.brandName}.",
        rating: product.rating,
        numOfReviews: product.reviews.length,
      ),
      if (includeBuyButton) SliverToBoxAdapter(child: _buyButton(context)),
      ProductListTile(
        svgSrc: "assets/icons/Product.svg",
        title: "Product Details",
        press: () => _openSheet(
          context,
          InfoSheet(title: "Product details", rows: {
            "Brand": product.brandName,
            if (product.category.isNotEmpty)
              "Category": product.category.replaceAll('-', ' '),
            "Price": "\$${product.effectivePrice.toStringAsFixed(2)}",
            "In stock": _available ? "${product.stock} left" : "Out of stock",
            if (product.warrantyInformation != null)
              "Warranty": product.warrantyInformation!,
            if (product.description.isNotEmpty)
              "Description": product.description,
          }),
        ),
      ),
      ProductListTile(
        svgSrc: "assets/icons/Delivery.svg",
        title: "Shipping Information",
        press: () => _openSheet(
          context,
          InfoSheet(title: "Shipping information", rows: {
            "Delivery":
                product.shippingInformation ?? "Ships in 3-5 business days",
            "Shipping cost": "Free on orders over \$100",
          }),
        ),
      ),
      ProductListTile(
        svgSrc: "assets/icons/Return.svg",
        title: "Returns",
        isShowBottomBorder: true,
        press: () => product.returnPolicy != null
            ? _openSheet(
                context,
                InfoSheet(
                  title: "Returns",
                  rows: {"Return policy": product.returnPolicy!},
                ),
              )
            : _openSheet(context, const ProductReturnsScreen()),
      ),
      if (product.reviews.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(defaultPadding),
            child: ReviewCard(
              rating: product.rating,
              numOfReviews: product.reviews.length,
              numOfFiveStar: _starCount(5),
              numOfFourStar: _starCount(4),
              numOfThreeStar: _starCount(3),
              numOfTwoStar: _starCount(2),
              numOfOneStar: _starCount(1),
            ),
          ),
        ),
        ProductListTile(
          svgSrc: "assets/icons/Chat.svg",
          title: "Reviews",
          isShowBottomBorder: true,
          press: () {
            Navigator.pushNamed(context, productReviewsScreenRoute,
                arguments: product);
          },
        ),
      ],
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
          final images = ProductImages(images: product.gallery);

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
