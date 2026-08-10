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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // دالة لتوليد بدائل الكلمة العربية (التاء المربوطة/الهاء والألف بأشكالها)
  List<String> _generateArabicVariations(String term) {
    Set<String> variations = {term};

    // 1. معالجة التاء المربوطة والهاء في نهاية الكلمة
    if (term.endsWith('ة')) {
      variations.add('${term.substring(0, term.length - 1)}ه');
    } else if (term.endsWith('ه')) {
      variations.add('${term.substring(0, term.length - 1)}ة');
    }

    // 2. معالجة همزات الألف في بداية أو وسط الكلمة
    List<String> currentList = variations.toList();
    for (String variant in currentList) {
      // استبدال أشكال الألف بالألف العادية
      String normalized = variant
          .replaceAll(RegExp(r'[أإآ]'), 'ا')
          .replaceAll('ى', 'ي');
      variations.add(normalized);
    }

    return variations.toList();
  }

  void _performSearch(String query) {
    final cleanQuery = query.trim();

    if (cleanQuery.isEmpty) {
      setState(() {
        _searchFuture = null;
      });
      return;
    }

    // تقسيم النص إلى كلمات
    final terms = cleanQuery.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

    // بداية الاستعلام الأساسي
    var request = supabase.from('products').select().gt('stock', 0);

    for (final term in terms) {
      final variations = _generateArabicVariations(term);

      if (variations.length == 1) {
        // إذا لم تكن هناك بدائل، نستخدم ilike العادي
        request = request.ilike('name', '%$term%');
      } else {
        // إذا كان للكلمة بدائل (مثل ربطة/ربطه)، نستخدم or للبحث عن أي منها
        final orCondition = variations.map((v) => 'name.ilike.%$v%').join(',');
        request = request.or(orCondition);
      }
    }

    // زيادة الحد الأقصى للنتائج إلى 50 نتيجة (يمكنك تغيير 49 إلى العدد الذي تناسبك)
    setState(() {
      _searchFuture = request.range(0, 49);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
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



////////////////////////////////////////////////////////////////////////////////
/*import 'package:flutter/material.dart';

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
 /* void _performSearch(String query) {
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
  }*/
///////////////////////////////
  void _performSearch(String query) {
    final cleanQuery = query.trim();

    if (cleanQuery.isEmpty) {
      setState(() {
        _searchFuture = null;
      });
      return;
    }

    // تقسيم النص المكتوب إلى كلمات فردية
    final terms = cleanQuery.split(RegExp(r'\s+')).where((term) => term.isNotEmpty).toList();

    // البدء بالاستعلام الأساسي
    var request = supabase.from('products').select().gt('stock', 0);

    // إضافة شرط ilike لكل كلمة كتبها المستخدم
    for (final term in terms) {
      request = request.ilike('name', '%$term%');
    }

    setState(() {
      _searchFuture = request;
    });
  }

///////////////////////////////
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
}*/