import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../../../main.dart'; // لجلب supabase
import 'new_product_card.dart';
import '../../details/details_screen.dart';

class HomeProductGrid extends StatelessWidget {
  // 1. تغيير اسم المتغير إلى categoryId واستقبال رقم
  final int categoryId;
  final Future<List<Map<String, dynamic>>>? productsFuture;
  const HomeProductGrid({super.key, required this.categoryId, this.productsFuture,});

  // 2. تعديل دالة جلب المنتجات لتستخدم الفلتر
  Future<List<Map<String, dynamic>>> _fetchProducts() {
    //////////////
    if (productsFuture != null) {
      return productsFuture!;
    }

    //////////////
    // إنشاء الاستعلام الأساسي
    var query = supabase.from('products').select();

    // إذا لم تكن الفئة هي "الكل" (id = 0)، أضف شرط الفلترة
    if (categoryId != 0) {
      // نفترض أن جدول products لديه عمود اسمه category_id
      query = query.eq('category_id', categoryId);
    }

    // إضافة الترتيب وتنفيذ الاستعلام
    return query.order('created_at', ascending: false);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchProducts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          print('--- PRODUCT GRID ERROR: ${snapshot.error} ---');
          return const SliverFillRemaining(
            child: Center(child: Text('خطأ في جلب المنتجات')),
          );
        }

        final products = snapshot.data;

        // **الحل:** إذا كانت المنتجات موجودة، نعرضها كشبكة
        if (products != null && products.isNotEmpty) {
          return SliverMasonryGrid(
            delegate: SliverChildBuilderDelegate(
                  (context, index) {
                final product = products[index];
                return NewProductCard(
                  product: product,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DetailsScreen(productId: product['id']),
                      ),
                    );
                  },
                );
              },
              childCount: products.length,
            ),
            gridDelegate: const SliverSimpleGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
            ),
          );
        }

        // إذا كانت القائمة فارغة (لا توجد منتجات)، نملأ باقي المساحة برسالة
        else {
          return const SliverFillRemaining(
            child: Center(child: Text('لا توجد منتجات في هذه الفئة حاليًا.')),
          );
        }
      },
    );
  }

}

// في ملف home_product_grid.dart (داخل كلاس HomeProductGrid)

