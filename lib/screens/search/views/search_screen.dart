import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shop/components/product/product_card.dart';
import 'package:shop/constants.dart';
import 'package:shop/models/product_model.dart';
import 'package:shop/route/route_constants.dart';
import 'package:shop/screens/search/views/components/search_form.dart';
import 'package:provider/provider.dart';
import 'package:shop/providers/product_provider.dart';
import 'package:shop/services/ml_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final MLService _mlService = MLService();
  final ImagePicker _picker = ImagePicker();
  
  List<ProductModel> _filteredProducts = [];
  bool _isSearching = false;
  
  bool _isVisualSearching = false;
  List<String> _visualSearchLabels = [];

  void _filterProducts(String? query, List<ProductModel> allProducts) {
    if (query == null || query.isEmpty) {
      setState(() {
        _isSearching = _isVisualSearching;
        if (!_isVisualSearching) {
          _filteredProducts = allProducts;
        } else {
          // If we clear text but visual search is active, re-apply visual search filter
          _applyVisualSearchFilter(allProducts);
        }
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

  void _applyVisualSearchFilter(List<ProductModel> allProducts) {
    _filteredProducts = allProducts.where((product) {
      final combinedText = "${product.title} ${product.brandName}".toLowerCase();
      // If any of the ML labels are in the product title or brand, show it
      return _visualSearchLabels.any((label) => combinedText.contains(label.toLowerCase()));
    }).toList();
  }

  Future<void> _pickImage(ImageSource source, List<ProductModel> allProducts) async {
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image == null) return;

      setState(() {
        _isVisualSearching = true;
        _isSearching = true;
        _visualSearchLabels = ["Analyzing..."];
      });

      final labels = await _mlService.extractLabels(image.path);
      
      setState(() {
        // Take top 3 labels
        _visualSearchLabels = labels.take(3).toList();
        _applyVisualSearchFilter(allProducts);
      });
    } catch (e) {
      debugPrint("Error picking image: $e");
      _clearVisualSearch(allProducts);
    }
  }

  void _showCameraOptions(List<ProductModel> allProducts) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera, allProducts);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery, allProducts);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _clearVisualSearch(List<ProductModel> allProducts) {
    setState(() {
      _isVisualSearching = false;
      _visualSearchLabels = [];
      _filterProducts(_searchController.text, allProducts);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mlService.dispose();
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
                    onCameraTap: () => _showCameraOptions(allProducts),
                  ),
                  if (_isVisualSearching)
                    Padding(
                      padding: const EdgeInsets.only(top: defaultPadding),
                      child: Row(
                        children: [
                          const Icon(Icons.auto_awesome, color: primaryColor, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Visual Search: ${_visualSearchLabels.join(', ')}",
                              style: const TextStyle(fontWeight: FontWeight.bold, color: primaryColor),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () => _clearVisualSearch(allProducts),
                          ),
                        ],
                      ),
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
