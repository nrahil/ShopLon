import 'package:flutter/material.dart';
import 'package:shop/constants.dart';

class AddressesScreen extends StatelessWidget {
  const AddressesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Addresses"),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // Show add address modal
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Add address coming in Phase 2")),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(defaultPadding),
        children: [
          const Text("Saved Addresses", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: defaultPadding),
          Container(
            padding: const EdgeInsets.all(defaultPadding),
            decoration: BoxDecoration(
              border: Border.all(color: primaryColor),
              borderRadius: BorderRadius.circular(defaultBorderRadious),
              color: primaryColor.withValues(alpha: 0.1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Home",
                      style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () {},
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20, color: errorColor),
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text("10880 Malibu Point, \nMalibu, California 90265"),
                const SizedBox(height: 8),
                const Text("+1 (310) 555-0198"),
              ],
            ),
          ),
          const SizedBox(height: defaultPadding),
          Container(
            padding: const EdgeInsets.all(defaultPadding),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(defaultBorderRadious),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Office (Stark Tower)",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () {},
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20, color: errorColor),
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text("200 Park Avenue, \nManhattan, New York 10166"),
                const SizedBox(height: 8),
                const Text("+1 (212) 555-0199"),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
