import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shop/components/network_image_with_loader.dart';
import 'package:shop/constants.dart';
import 'package:shop/models/cart_item_model.dart';
import 'package:shop/providers/cart_provider.dart';
import 'package:shop/route/route_constants.dart';
import 'package:shop/services/api_client.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key, this.showAppBar = true});

  /// False when shown as a tab inside [EntryPoint], which has its own AppBar.
  final bool showAppBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: showAppBar ? AppBar(title: const Text("Cart")) : null,
      body: Consumer<CartProvider>(
        builder: (context, cart, child) {
          if (cart.cartItems.isEmpty) {
            if (cart.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            return Center(
              child: Text(cart.error ?? "Your cart is empty"),
            );
          }
          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: cart.cartItems.length,
                  itemBuilder: (context, index) {
                    return CartItemCard(item: cart.cartItems[index]);
                  },
                ),
              ),
              const CartSummary(),
            ],
          );
        },
      ),
    );
  }
}

class CartItemCard extends StatelessWidget {
  const CartItemCard({super.key, required this.item});

  final CartItemModel item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: defaultPadding, vertical: defaultPadding / 2),
      child: Container(
        padding: const EdgeInsets.all(defaultPadding / 2),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(defaultBorderRadious),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 80,
              child: AspectRatio(
                aspectRatio: 1,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(defaultBorderRadious),
                  child: NetworkImageWithLoader(item.product.image),
                ),
              ),
            ),
            const SizedBox(width: defaultPadding),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.product.title,
                    style: Theme.of(context).textTheme.titleSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (item.selectedSize != null || item.selectedColor != null)
                    _CartItemOptions(
                      size: item.selectedSize,
                      color: item.selectedColor,
                    ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "\$${(item.product.priceAfetDiscount ?? item.product.price).toStringAsFixed(2)}",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: primaryColor),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline,
                                size: 20),
                            onPressed: () => _changeQuantity(
                                context, item, item.quantity - 1),
                          ),
                          Text("${item.quantity}"),
                          IconButton(
                            icon:
                                const Icon(Icons.add_circle_outline, size: 20),
                            onPressed: () => _changeQuantity(
                                context, item, item.quantity + 1),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _changeQuantity(BuildContext context, CartItemModel item, int quantity) {
  final messenger = ScaffoldMessenger.of(context);
  context
      .read<CartProvider>()
      .updateQuantity(item, quantity)
      .catchError((Object e) {
    messenger.showSnackBar(SnackBar(
        content: Text(e is ApiException ? e.message : "Couldn't update cart")));
  });
}

class _CartItemOptions extends StatelessWidget {
  const _CartItemOptions({this.size, this.color});

  final String? size;
  final String? color;

  /// Parses "#AARRGGBB" / "#RRGGBB". Returns null for anything else
  /// (e.g. legacy "Color(...)" strings saved by older versions).
  static Color? _parseHex(String? value) {
    if (value == null || !value.startsWith('#')) return null;
    var hex = value.substring(1);
    if (hex.length == 6) hex = 'FF$hex';
    if (hex.length != 8) return null;
    final parsed = int.tryParse(hex, radix: 16);
    return parsed == null ? null : Color(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    final swatch = _parseHex(color);
    return Row(
      children: [
        Text("Size: ${size ?? 'N/A'}", style: style),
        if (color != null) ...[
          const SizedBox(width: 12),
          Text("Color: ", style: style),
          if (swatch != null)
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: swatch,
                shape: BoxShape.circle,
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
            )
          else
            Text("—", style: style),
        ],
      ],
    );
  }
}

class CartSummary extends StatelessWidget {
  const CartSummary({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(defaultPadding),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(defaultBorderRadious * 2),
          topRight: Radius.circular(defaultBorderRadious * 2),
        ),
      ),
      child: SafeArea(
        child: Consumer<CartProvider>(
          builder: (context, cart, child) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Subtotal"),
                    Text("\$${cart.subtotal.toStringAsFixed(2)}"),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Shipping"),
                    Text(cart.shippingTotal == 0
                        ? "Free"
                        : "\$${cart.shippingTotal.toStringAsFixed(2)}"),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Tax"),
                    Text("\$${cart.taxTotal.toStringAsFixed(2)}"),
                  ],
                ),
                const Divider(height: defaultPadding * 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Total",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18)),
                    Text(
                      "\$${cart.totalPrice.toStringAsFixed(2)}",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: primaryColor),
                    ),
                  ],
                ),
                const SizedBox(height: defaultPadding),
                if (cart.shippingTotal > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: defaultPadding / 2),
                    child: Text(
                      "Add \$${(CartProvider.freeShippingThreshold - cart.subtotal).toStringAsFixed(2)} more for free shipping",
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                const SizedBox(
                  width: double.infinity,
                  child: _CheckoutButton(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CheckoutButton extends StatefulWidget {
  const _CheckoutButton();

  @override
  State<_CheckoutButton> createState() => _CheckoutButtonState();
}

class _CheckoutButtonState extends State<_CheckoutButton> {
  bool _placing = false;

  Future<void> _checkout() async {
    setState(() => _placing = true);
    try {
      final order = await context.read<CartProvider>().checkout();
      if (!mounted) return;
      Navigator.pushNamed(context, checkoutPaymentScreenRoute,
          arguments: order);
    } catch (e) {
      debugPrint("Checkout error: $e");
      if (!mounted) return;
      final message = e is StateError
          ? e.message
          : e is ApiException
              ? e.message
              : "Couldn't place your order. Please try again.";
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _placing ? null : _checkout,
      child: _placing
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            )
          : const Text("Checkout"),
    );
  }
}
