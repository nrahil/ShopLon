import 'package:flutter/material.dart';
import 'package:shop/constants.dart';
import 'package:provider/provider.dart';
import 'package:shop/providers/category_provider.dart';
import 'package:shop/screens/search/views/components/search_form.dart';

import 'components/expansion_category.dart';

class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(defaultPadding),
              child: SearchForm(),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: defaultPadding, vertical: defaultPadding / 2),
              child: Text(
                "Categories",
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            Expanded(
              child: Consumer<CategoryProvider>(
                builder: (context, provider, child) {
                  if (provider.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (provider.categories.isEmpty) {
                    return const Center(child: Text("No categories found"));
                  }
                  return ListView.builder(
                    itemCount: provider.categories.length,
                    itemBuilder: (context, index) {
                      final category = provider.categories[index];
                      return ExpansionCategory(
                        svgSrc: category.svgSrc ?? "assets/icons/Category.svg",
                        title: category.title,
                        subCategory: category.subCategories ?? [],
                      );
                    },
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}
