import 'package:flutter/material.dart';
import '../../../main.dart'; // لجلب متغير supabase
import 'product_grid.dart'; // لجلب ProductCard
import '../../details/details_screen.dart'; // أضف هذا السطر
class PopularProducts extends StatelessWidget {
  const PopularProducts({super.key});

  @override
  Widget build(BuildContext context) {
    // نستخدم FutureBuilder لجلب المنتجات "الشائعة"
    return FutureBuilder<List<Map<String, dynamic>>>(
      // نطلب فقط المنتجات التي يكون فيها 'is_popular' صحيحًا
      future: supabase.from('products').select().eq('is_popular', true),

      builder: (context, snapshot) {
        // حالة التحميل
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        // حالة الخطأ
        if (snapshot.hasError) {
          //print('--- PRODUCT FETCH ERROR: ${snapshot.error} ---');
          return const Center(child: Text('Error loading products'));
        }
        // حالة عدم وجود بيانات
        final products = snapshot.data;
        if (products == null || products.isEmpty) {
          return const Center(child: Text('No popular products found.'));
        }

        // حالة النجاح: عرض المنتجات
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: GridView.builder(
            shrinkWrap: true, // مهم جدًا داخل SingleChildScrollView
            physics: const NeverScrollableScrollPhysics(), // لمنع التمرير داخل GridView
            itemCount: products.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
              childAspectRatio: 0.75, // نسبة العرض إلى الارتفاع للبطاقة
            ),


            itemBuilder: (context, index) {
              final product = products[index];

              // --- 1. إصلاح قائمة الصور (الذي قمنا به) ---
              final List<dynamic> imageList = product['image_url'] ?? [];
              final String imageUrl = imageList.isNotEmpty ? imageList.first as String : '';

              // --- 2. استخراج بقية البيانات (نحتاج الـ ID للنقر) ---
              final int productId = product['id'] ?? 0;
              final String name = product['name'] ?? 'No Name';
              final double price = (product['price'] ?? 0.0).toDouble();

              // --- 3. الكود المفقود: تغليف البطاقة بـ GestureDetector ---
              return GestureDetector(
                onTap: () {
                  // الانتقال إلى شاشة التفاصيل مع الـ ID الحقيقي
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DetailsScreen(productId: productId),
                    ),
                  );
                },
                child: ProductCard(
                  imageUrl: imageUrl,
                  name: name,
                  price: price,
                ),
              );
            },



          ),
        );
      },
    );
  }
}