import 'package:flutter/material.dart';
// لا نحتاج supabase هنا بعد الآن
// استيراد شبكة المنتجات
import '../home/components/home_product_grid.dart';

class OffersScreen extends StatelessWidget {
  const OffersScreen({super.key});

  // --- لا نحتاج دالة _fetchOfferProducts هنا بعد الآن ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('العروض الخاصة'),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      // --- إزالة FutureBuilder ---
      // استبداله بـ CustomScrollView مباشرة
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(8.0),

            // --- هذا هو التعديل الأهم ---
            sliver: HomeProductGrid(
              categoryId: 0,     // لا نريد فلترة حسب الفئة
              onlyOffers: true,  // <-- تفعيل فلتر العروض
              // لا نمرر productsFuture لكي يعمل نظام التصفح (Pagination)
            ),
          ),
        ],
      ),
    );
  }
}