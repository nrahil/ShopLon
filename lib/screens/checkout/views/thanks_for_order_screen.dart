import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shop/constants.dart';
import 'package:shop/providers/cart_provider.dart';
import 'package:shop/route/route_constants.dart';

class ThanksForOrderScreen extends StatefulWidget {
  const ThanksForOrderScreen({super.key});

  @override
  State<ThanksForOrderScreen> createState() => _ThanksForOrderScreenState();
}

class _ThanksForOrderScreenState extends State<ThanksForOrderScreen> {
  @override
  void initState() {
    super.initState();
    // Clear the cart when the thanks screen is shown
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CartProvider>().clearCart();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(defaultPadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              const Icon(
                Icons.check_circle_outline,
                color: primaryColor,
                size: 120,
              ),
              const SizedBox(height: defaultPadding),
              Text(
                "Thanks for your order!",
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: defaultPadding / 2),
              const Text(
                "Your order will be delivered soon.\nYou can track the delivery in the orders section.",
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    entryPointScreenRoute,
                    (route) => false,
                  );
                },
                child: const Text("Continue Shopping"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
