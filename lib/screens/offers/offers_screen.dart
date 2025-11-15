import 'package:flutter/material.dart';
import '../../main.dart'; // لاستخدام supabase
// استيراد شبكة المنتجات لعرض العروض بنفس التصميم
import '../home/components/home_product_grid.dart';

class OffersScreen extends StatelessWidget {
  const OffersScreen({super.key});

  // --- دالة جديدة لجلب منتجات العروض فقط ---
  Future<List<Map<String, dynamic>>> _fetchOfferProducts() {
    return supabase
        .from('products')
        .select()
        .eq('is_offer', true) // <-- جلب المنتجات التي is_offer = true
        .gt('stock', 0) // <-- تم إضافة الفلتر هنا
        .order('created_at', ascending: false); // ترتيب الأحدث أولاً
  }
  // --- نهاية الدالة ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('العروض الخاصة'),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      // استخدام FutureBuilder لجلب وعرض المنتجات
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchOfferProducts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
           // print('--- OFFERS FETCH ERROR: ${snapshot.error} ---');
            return const Center(child: Text('خطأ في جلب العروض'));
          }

          final products = snapshot.data;
          if (products == null || products.isEmpty) {
            return Center(
              child: Text(
                'لا توجد عروض خاصة متاحة حاليًا.',
                style: TextStyle(fontSize: 18, color: Colors.grey[600]),
              ),
            );
          }

          // --- استخدام CustomScrollView مع HomeProductGrid لعرض النتائج ---
          // هذا ضروري لأن HomeProductGrid مصمم كـ Sliver
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(8.0),
                // تمرير categoryId = 0 يعني عدم الفلترة حسب الفئة هنا
                sliver: HomeProductGrid(categoryId: 0, productsFuture: Future.value(products)),
              ),
            ],
          );
          // --- نهاية التعديل ---
        },
      ),
    );
  }
}

// --- تعديل HomeProductGrid لقبول Future خارجي ---
// افتح ملف lib/screens/home/components/home_product_grid.dart
// وقم بتعديل بسيط للسماح بتمرير Future جاهز

/*
// في ملف home_product_grid.dart عدّل الآتي:

import ... // أبقِ على الاستيرادات

class HomeProductGrid extends StatelessWidget {
  final int categoryId;
  // أضف هذا المتغير الاختياري
  final Future<List<Map<String, dynamic>>>? productsFuture;

  const HomeProductGrid({
    super.key,
    required this.categoryId,
    this.productsFuture, // أضفه هنا
  });

  Future<List<Map<String, dynamic>>> _fetchProducts() {
     // إذا تم تمرير Future جاهز، استخدمه، وإلا قم بالجلب
    if (productsFuture != null) return productsFuture!;

    var query = supabase.from('products').select();
    if (categoryId != 0) {
      query = query.eq('category_id', categoryId);
    }
    return query.order('created_at', ascending: false);
  }

  @override
  Widget build(BuildContext context) {
    // استخدم _fetchProducts() مباشرة هنا، لا حاجة لـ productsFuture في هذا السطر
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchProducts(),
      builder: (context, snapshot) {
          // ... باقي الكود يبقى كما هو ...
      },
    );
  }
}

*/