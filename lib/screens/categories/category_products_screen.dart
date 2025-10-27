import 'package:flutter/material.dart';
import '../home/components/home_product_grid.dart'; // استيراد شبكة المنتجات

class CategoryProductsScreen extends StatelessWidget {
  final int categoryId;
  final String categoryName;

  const CategoryProductsScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(categoryName), // عرض اسم الفئة في العنوان
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body:
      // استخدام CustomScrollView للسماح لشبكة المنتجات (التي هي Sliver) بالعمل
      CustomScrollView(
        slivers: [
          // إضافة حشوة حول الشبكة
          SliverPadding(
            padding: const EdgeInsets.all(8.0),
            // استخدام HomeProductGrid مباشرة وتمرير معرف الفئة
            sliver: HomeProductGrid(categoryId: categoryId),
          ),
        ],
      ),
    );
  }
}