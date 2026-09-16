import 'package:flutter/material.dart';

import '../../core/shop_api.dart';
import '../../main.dart';
import '../details/details_screen.dart';
import '../home/components/product_grid.dart'; // ProductCard

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  Future<List<Map<String, dynamic>>>? _searchFuture;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// بدائل الكلمة العربية (ة/ه، أ/إ/آ/ا، ى/ي)
  List<String> _generateArabicVariations(String term) {
    final variations = <String>{term};
    if (term.endsWith('ة')) {
      variations.add('${term.substring(0, term.length - 1)}ه');
    } else if (term.endsWith('ه')) {
      variations.add('${term.substring(0, term.length - 1)}ة');
    }
    for (final variant in variations.toList()) {
      variations.add(variant.replaceAll(RegExp(r'[أإآ]'), 'ا').replaceAll('ى', 'ي'));
    }
    return variations.toList();
  }

  void _performSearch(String query) {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      setState(() => _searchFuture = null);
      return;
    }

    final terms = cleanQuery.split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
    var request = supabase.from('products').select(kProductColumns).gt('stock', 0);

    for (final term in terms) {
      final variations = _generateArabicVariations(term);
      if (variations.length == 1) {
        request = request.ilike('name', '%$term%');
      } else {
        request = request.or(variations.map((v) => 'name.ilike.%$v%').join(','));
      }
    }

    setState(() => _searchFuture = request.range(0, 49));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'ابحث عن منتج...',
            border: InputBorder.none,
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                _performSearch('');
              },
            ),
          ),
          onSubmitted: _performSearch,
        ),
      ),
      body: _buildResults(),
    );
  }

  Widget _buildResults() {
    if (_searchFuture == null) {
      return const Center(child: Text('اكتب اسم المنتج واضغط بحث.'));
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _searchFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text(ShopApi.friendlyError(snapshot.error!)));
        }

        final products = snapshot.data ?? const [];
        if (products.isEmpty) {
          return const Center(child: Text('لم يتم العثور على منتجات.'));
        }

        return GridView.builder(
          padding: const EdgeInsets.all(20),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
            childAspectRatio: 0.75,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final product = products[index];
            final List<dynamic> imageList = product['image_url'] ?? [];
            final productId = (product['id'] as num).toInt();

            return GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => DetailsScreen(productId: productId)),
              ),
              child: ProductCard(
                imageUrl: imageList.isNotEmpty ? '${imageList.first}' : '',
                name: product['name'] ?? '',
                price: (product['price'] as num?)?.toDouble() ?? 0,
              ),
            );
          },
        );
      },
    );
  }
}
