import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shop/components/cart_button.dart';
import 'package:shop/components/custom_modal_bottom_sheet.dart';
import 'package:shop/components/network_image_with_loader.dart';
import 'package:shop/screens/product/views/added_to_cart_message_screen.dart';
import 'package:shop/screens/product/views/components/product_list_tile.dart';
import 'package:shop/screens/product/views/location_permission_store_availability_screen.dart';
import 'package:shop/screens/product/views/size_guide_screen.dart';

import '../../../constants.dart';
import 'components/product_quantity.dart';
import 'components/selected_colors.dart';
import 'components/selected_size.dart';
import 'components/unit_price.dart';

import 'package:provider/provider.dart';
import 'package:shop/providers/cart_provider.dart';
import 'package:shop/providers/wishlist_provider.dart';
import 'package:shop/models/product_model.dart';

class ProductBuyNowScreen extends StatefulWidget {
  const ProductBuyNowScreen({super.key, required this.product});

  final ProductModel product;

  @override
  State<ProductBuyNowScreen> createState() => _ProductBuyNowScreenState();
}

class _ProductBuyNowScreenState extends State<ProductBuyNowScreen> {
  int _quantity = 1;
  int _selectedColorIndex = 0;
  int _selectedSizeIndex = 0;

  final List<Color> _colors = const [
    Color(0xFFEA6262),
    Color(0xFFB1CC63),
    Color(0xFFFFBF5F),
    Color(0xFF9FE1DD),
    Color(0xFFC482DB),
  ];

  final List<String> _sizes = const ["S", "M", "L", "XL", "XXL"];
  final List<String> _shoeSizes = const ["38", "39", "40", "41", "42", "43"];
  bool _isAdding = false;

  static const _apparel = {
    'tops',
    'womens-dresses',
    'mens-shirts',
  };
  static const _shoes = {'mens-shoes', 'womens-shoes'};

  String get _category => widget.product.category;

  /// Colour and size only make sense for clothing and shoes.
  /// (Products saved before categories existed keep the old behaviour.)
  bool get _hasVariants =>
      _category.isEmpty ||
      _apparel.contains(_category) ||
      _shoes.contains(_category);

  List<String> get _activeSizes =>
      _shoes.contains(_category) ? _shoeSizes : _sizes;

  int get _maxQuantity => widget.product.stock > 0 ? widget.product.stock : 1;

  /// Stores colors as "#AARRGGBB" so the cart can show a swatch.
  String _colorToHex(Color color) =>
      '#${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';

  Future<void> _addToCart() async {
    if (_isAdding) return;
    setState(() => _isAdding = true);
    try {
      await context.read<CartProvider>().addToCart(
            widget.product,
            quantity: _quantity,
            color:
                _hasVariants ? _colorToHex(_colors[_selectedColorIndex]) : null,
            size: _hasVariants ? _activeSizes[_selectedSizeIndex] : null,
          );
      if (!mounted) return;
      customModalBottomSheet(
        context,
        isDismissible: false,
        child: const AddedToCartMessageScreen(),
      );
    } catch (e) {
      if (!mounted) return;
      final message = e is StateError
          ? e.message
          : "Couldn't add to cart. Please try again.";
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    return Scaffold(
      bottomNavigationBar: CartButton(
        price: product.effectivePrice * _quantity,
        title: "Add to cart",
        subTitle: "Total price",
        press: _addToCart,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: defaultPadding / 2, vertical: defaultPadding),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const BackButton(),
                Expanded(
                  child: Text(
                    product.title,
                    style: Theme.of(context).textTheme.titleSmall,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Consumer<WishlistProvider>(
                  builder: (context, wishlist, _) {
                    final isWishlisted = wishlist.isWishlisted(product.id);
                    return IconButton(
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
                ),
              ],
            ),
          ),
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: defaultPadding),
                    child: AspectRatio(
                      aspectRatio: 1.05,
                      child: NetworkImageWithLoader(product.image),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.all(defaultPadding),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: UnitPrice(
                            price: product.price,
                            priceAfterDiscount: product.priceAfetDiscount,
                          ),
                        ),
                        ProductQuantity(
                          numOfItem: _quantity,
                          onIncrement: () {
                            if (_quantity >= _maxQuantity) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content:
                                      Text("Only $_maxQuantity left in stock."),
                                ),
                              );
                              return;
                            }
                            setState(() {
                              _quantity++;
                            });
                          },
                          onDecrement: () {
                            if (_quantity > 1) {
                              setState(() {
                                _quantity--;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: Divider()),
                if (_hasVariants) ...[
                  SliverToBoxAdapter(
                    child: SelectedColors(
                      colors: _colors,
                      selectedColorIndex: _selectedColorIndex,
                      press: (value) {
                        setState(() {
                          _selectedColorIndex = value;
                        });
                      },
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SelectedSize(
                      sizes: _activeSizes,
                      selectedIndex: _selectedSizeIndex,
                      press: (value) {
                        setState(() {
                          _selectedSizeIndex = value;
                        });
                      },
                    ),
                  ),
                  SliverPadding(
                    padding:
                        const EdgeInsets.symmetric(vertical: defaultPadding),
                    sliver: ProductListTile(
                      title: "Size guide",
                      svgSrc: "assets/icons/Sizeguid.svg",
                      isShowBottomBorder: true,
                      press: () {
                        customModalBottomSheet(
                          context,
                          height: MediaQuery.of(context).size.height * 0.9,
                          child: const SizeGuideScreen(),
                        );
                      },
                    ),
                  ),
                ],
                SliverPadding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: defaultPadding),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: defaultPadding / 2),
                        Text(
                          "Store pickup availability",
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: defaultPadding / 2),
                        const Text(
                            "Select a size to check store availability and In-Store pickup options.")
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(vertical: defaultPadding),
                  sliver: ProductListTile(
                    title: "Check stores",
                    svgSrc: "assets/icons/Stores.svg",
                    isShowBottomBorder: true,
                    press: () {
                      customModalBottomSheet(
                        context,
                        height: MediaQuery.of(context).size.height * 0.92,
                        child: const LocationPermissonStoreAvailabilityScreen(),
                      );
                    },
                  ),
                ),
                const SliverToBoxAdapter(
                    child: SizedBox(height: defaultPadding))
              ],
            ),
          )
        ],
      ),
    );
  }
}
