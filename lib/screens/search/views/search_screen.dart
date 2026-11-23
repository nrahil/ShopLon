import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shop/components/responsive.dart';
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
  final FocusNode _focusNode = FocusNode();

  // ML Kit only works on Android/iOS, so it's created lazily and never on web.
  MLService? _mlService;
  ImagePicker? _picker;

  String _query = '';
  bool _isAnalyzing = false;
  List<String> _visualSearchLabels = [];

  bool get _isVisualSearching => _isAnalyzing || _visualSearchLabels.isNotEmpty;

  /// Recomputed on every build, so results stay correct when products load late.
  List<ProductModel> _filter(List<ProductModel> allProducts) {
    Iterable<ProductModel> result = allProducts;

    final query = _query.trim().toLowerCase();
    if (query.isNotEmpty) {
      result = result.where((p) =>
          p.title.toLowerCase().contains(query) ||
          p.brandName.toLowerCase().contains(query));
    }

    if (_visualSearchLabels.isNotEmpty) {
      final labels = _visualSearchLabels.map((l) => l.toLowerCase()).toList();
      result = result.where((p) {
        final text = "${p.title} ${p.brandName}".toLowerCase();
        return labels.any(text.contains);
      });
    }

    return result.toList();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      _picker ??= ImagePicker();
      final XFile? image = await _picker!.pickImage(source: source);
      if (image == null) return;

      setState(() => _isAnalyzing = true);

      _mlService ??= MLService();
      final labels = await _mlService!.extractLabels(image.path);

      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
        _visualSearchLabels = labels.take(3).toList();
      });
      if (labels.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't recognise anything in that image.")),
        );
      }
    } catch (e) {
      debugPrint("Visual search error: $e");
      if (!mounted) return;
      _clearVisualSearch();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Visual search failed. Please try again.")),
      );
    }
  }

  void _showCameraOptions() {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _clearVisualSearch() {
    setState(() {
      _isAnalyzing = false;
      _visualSearchLabels = [];
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _mlService?.dispose();
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
              final displayProducts = _filter(provider.products);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: defaultPadding),
                  Row(
                    children: [
                      if (Navigator.canPop(context)) const BackButton(),
                      Text(
                        "Search",
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: defaultPadding),
                  SearchForm(
                    focusNode: _focusNode,
                    autofocus: true,
                    onChanged: (value) => setState(() => _query = value ?? ''),
                    onCameraTap: kIsWeb ? null : _showCameraOptions,
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
                              _isAnalyzing
                                  ? "Visual Search: Analyzing..."
                                  : "Visual Search: ${_visualSearchLabels.join(', ')}",
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, color: primaryColor),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: _clearVisualSearch,
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: defaultPadding),
                  Expanded(
                    child: (provider.isLoading || _isAnalyzing)
                        ? const Center(child: CircularProgressIndicator())
                        : displayProducts.isEmpty
                            ? const Center(child: Text("No products found"))
                            : GridView.builder(
                                itemCount: displayProducts.length,
                                gridDelegate:
                                    productGridDelegate,
                                itemBuilder: (context, index) {
                                  final product = displayProducts[index];
                                  return ProductCard(
                                    image: product.image,
                                    brandName: product.brandName,
                                    title: product.title,
                                    price: product.price,
                                    priceAfetDiscount: product.priceAfetDiscount,
                                    dicountpercent: product.dicountpercent,
                                    press: () {
                                      Navigator.pushNamed(
                                        context,
                                        productDetailsScreenRoute,
                                        arguments: product,
                                      );
                                    },
                                  );
                                },
                              ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
