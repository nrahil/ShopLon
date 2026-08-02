import 'package:flutter/material.dart';
import 'package:shop/components/product/product_card.dart';
import 'package:shop/constants.dart';
import 'package:shop/models/product_model.dart';
import 'package:shop/route/route_constants.dart';
import 'package:shop/screens/search/views/components/search_form.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<ProductModel> _allProducts = [];
  List<ProductModel> _filteredProducts = [];

  @override
  void initState() {
    super.initState();
    _allProducts = [
      ...demoPopularProducts,
      ...demoBestSellersProducts,
      ...demoFlashSaleProducts,
    ];
    // Remove duplicates based on title
    final Set<String> titles = {};
    _allProducts.retainWhere((product) {
      if (titles.contains(product.title)) return false;
      titles.add(product.title);
      return true;
    });
    _filteredProducts = _allProducts;
  }

  void _filterProducts(String? query) {
    if (query == null || query.isEmpty) {
      setState(() {
        _filteredProducts = _allProducts;
      });
      return;
    }
    
    setState(() {
      _filteredProducts = _allProducts.where((product) {
        return product.title.toLowerCase().contains(query.toLowerCase()) ||
               product.brandName.toLowerCase().contains(query.toLowerCase());
      }).toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: defaultPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: defaultPadding),
              Text(
                "Search",
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: defaultPadding),
              SearchForm(
                focusNode: FocusNode(),
                autofocus: true,
                onChanged: _filterProducts,
              ),
              const SizedBox(height: defaultPadding),
              Expanded(
                child: _filteredProducts.isEmpty
                    ? const Center(
                        child: Text("No products found"),
                      )
                    : GridView.builder(
                        itemCount: _filteredProducts.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.7,
                          crossAxisSpacing: defaultPadding,
                          mainAxisSpacing: defaultPadding,
                        ),
                        itemBuilder: (context, index) {
                          return ProductCard(
                            image: _filteredProducts[index].image,
                            brandName: _filteredProducts[index].brandName,
                            title: _filteredProducts[index].title,
                            price: _filteredProducts[index].price,
                            priceAfetDiscount: _filteredProducts[index].priceAfetDiscount,
                            dicountpercent: _filteredProducts[index].dicountpercent,
                            press: () {
                              Navigator.pushNamed(context, productDetailsScreenRoute);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
