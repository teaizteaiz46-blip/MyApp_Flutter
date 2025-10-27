import 'package:flutter/material.dart';
import '../../main.dart'; // لاستخدام supabase
// لاحقًا، قد نحتاج للانتقال لشاشة تعرض منتجات فئة معينة
// import '../home/components/home_product_grid.dart';
import 'category_products_screen.dart'; // <-- أضف هذا


class AllCategoriesScreen extends StatelessWidget {
  const AllCategoriesScreen({super.key});

  // دالة جلب الفئات
  Future<List<Map<String, dynamic>>> _fetchCategories() async {
    final data = await supabase
        .from('categories')
        .select()
        .order('id', ascending: true);
    return data;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('جميع الفئات'),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchCategories(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('خطأ في جلب الفئات'));
          }

          final categories = snapshot.data;
          if (categories == null || categories.isEmpty) {
            return const Center(child: Text('لا توجد فئات متاحة حاليًا.'));
          }

          // عرض الفئات في قائمة
          return ListView.builder(
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  // يمكنك إضافة أيقونة هنا إذا أردت (category['icon_name'])
                  // leading: Icon(_getIconData(category['icon_name'] ?? '')),
                  title: Text(
                    category['name'] ?? 'فئة غير مسماة',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    // TODO: الانتقال إلى شاشة تعرض منتجات هذه الفئة فقط
                    // --- بداية التعديل ---
                    // الانتقال إلى شاشة منتجات الفئة وتمرير الـ ID والاسم
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CategoryProductsScreen(
                          categoryId: category['id'],
                          categoryName: category['name'],
                        ),
                      ),
                    );
                    //
                    //print('تم الضغط على الفئة: ${category['name']}');
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

// يمكنك نسخ دالة _getIconData هنا إذا أردت استخدام الأيقونات
// IconData _getIconData(String iconName) { ... }
}