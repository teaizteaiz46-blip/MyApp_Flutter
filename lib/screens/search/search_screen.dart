import 'package:flutter/material.dart';
import '../../main.dart'; // لاستخدام supabase
import '../details/details_screen.dart'; // للانتقال للتفاصيل
import 'package:myapprun/screens/home/components/product_grid.dart'; // لاستخدام ProductCard

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  Future<List<Map<String, dynamic>>>? _searchFuture;

  // دالة تنفيذ البحث
  void _performSearch(String query) {
    if (query.isEmpty) {
      setState(() {
        _searchFuture = null; // مسح النتائج إذا كان البحث فارغًا
      });
      return;
    }

    // .ilike() للبحث عن النص بغض النظر عن حالة الأحرف (كبير/صغير)
    // نستخدم %query% للبحث عن أي منتج "يحتوي" على هذا النص
    setState(() {
      _searchFuture = supabase
          .from('products')
          .select()
          .ilike('name', '%$query%')
          .gt('stock', 0); // <-- تم إضافة الفلتر هنا
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true, // فتح لوحة المفاتيح تلقائيًا
          decoration: InputDecoration(
            hintText: 'ابحث عن منتج...',
            border: InputBorder.none,
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                _performSearch(''); // مسح النتائج
              },
            ),
          ),
          onSubmitted: _performSearch, // تنفيذ البحث عند الضغط على "تم"
        ),
      ),
      body: _buildResults(),
    );
  }

  Widget _buildResults() {
    if (_searchFuture == null) {
      return const Center(child: Text('ابدأ بكتابة اسم المنتج للبحث.'));
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _searchFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('خطأ في البحث.'));
        }

        final products = snapshot.data;
        if (products == null || products.isEmpty) {
          return const Center(child: Text('لم يتم العثور على منتجات.'));
        }

        // عرض النتائج في شبكة
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

            // استخراج البيانات
            final List<dynamic> imageList = product['image_url'] ?? [];
            final String imageUrl = imageList.isNotEmpty ? imageList.first as String : '';
            final int productId = product['id'] ?? 0;
            final String name = product['name'] ?? 'No Name';
            final double price = (product['price'] ?? 0.0).toDouble();

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => DetailsScreen(productId: productId)),
                );
              },
              child: ProductCard(
                imageUrl: imageUrl,
                name: name,
                price: price,
              ),
            );
          },
        );
      },
    );
  }
}