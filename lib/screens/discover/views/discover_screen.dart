import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shop/components/load_error.dart';
import 'package:shop/providers/product_provider.dart';
import 'package:shop/route/route_constants.dart';
import 'package:shop/constants.dart';
import 'package:provider/provider.dart';
import 'package:shop/providers/category_provider.dart';
import 'package:shop/screens/search/views/components/search_form.dart';

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
              child: Consumer2<CategoryProvider, ProductProvider>(
                builder: (context, provider, products, child) {
                  if (provider.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (provider.error != null && provider.categories.isEmpty) {
                    return LoadError(
                      message: provider.error!,
                      onRetry: provider.fetchCategories,
                    );
                  }
                  if (provider.categories.isEmpty) {
                    return const Center(child: Text("No categories found"));
                  }
                  final iconColor = Theme.of(context).iconTheme.color!;
                  return ListView.separated(
                    itemCount: provider.categories.length + 1,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final category =
                          index == 0 ? null : provider.categories[index - 1];
                      final count = category == null
                          ? products.products.length
                          : products.inCategory(category.slug).length;
                      return ListTile(
                        leading: SvgPicture.asset(
                          category?.svgSrc ?? "assets/icons/Category.svg",
                          height: 24,
                          width: 24,
                          colorFilter:
                              ColorFilter.mode(iconColor, BlendMode.srcIn),
                        ),
                        title: Text(
                          category?.title ?? "All products",
                          style: const TextStyle(fontSize: 14),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (count > 0)
                              Text("$count",
                                  style: Theme.of(context).textTheme.bodySmall),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            categoryProductsScreenRoute,
                            arguments: category,
                          );
                        },
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
