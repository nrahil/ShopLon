import 'package:flutter/material.dart';
import 'package:shop/components/product/product_card.dart';
import 'package:shop/constants.dart';
import 'package:shop/models/product_model.dart';
import 'package:shop/route/route_constants.dart';
import 'package:shop/screens/search/views/components/search_form.dart';
import 'package:provider/provider.dart';
import 'package:shop/providers/product_provider.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<ProductModel> _filteredProducts = [];
  bool _isSearching = false;

  void _filterProducts(String? query, List<ProductModel> allProducts) {
    if (query == null || query.isEmpty) {
      setState(() {
        _isSearching = false;
        _filteredProducts = allProducts;
      });
      return;
    }
    
    setState(() {
      _isSearching = true;
      _filteredProducts = allProducts.where((product) {
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
          child: Consumer<ProductProvider>(
            builder: (context, provider, child) {
              final allProducts = provider.products;
              final displayProducts = _isSearching ? _filteredProducts : allProducts;
              
              return Column(
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
                    onChanged: (value) => _filterProducts(value, allProducts),
                  ),
                  const SizedBox(height: defaultPadding),
                  Expanded(
                    child: provider.isLoading 
                        ? const Center(child: CircularProgressIndicator())
                        : displayProducts.isEmpty
                        ? const Center(
                            child: Text("No products found"),
                          )
                        : GridView.builder(
                            itemCount: displayProducts.length,
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.7,
                              crossAxisSpacing: defaultPadding,
                              mainAxisSpacing: defaultPadding,
                            ),
                            itemBuilder: (context, index) {
                              return ProductCard(
                                image: displayProducts[index].image,
                                brandName: displayProducts[index].brandName,
                                title: displayProducts[index].title,
                                price: displayProducts[index].price,
                                priceAfetDiscount: displayProducts[index].priceAfetDiscount,
                                dicountpercent: displayProducts[index].dicountpercent,
                                press: () {
                                  Navigator.pushNamed(context, productDetailsScreenRoute);
                                },
                              );
                            },
                          ),
                  ),
                ],
              );
            }
          ),
        ),
      ),
    );
  }
}
