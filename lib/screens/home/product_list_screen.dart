import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'components/home_product_grid.dart';

/// قائمة منتجات بفلتر (تسوّقي حسب السعر، عروض القطعتين، قسم...)، أو منتجات جاهزة ([productsFuture]).
class ProductListScreen extends StatelessWidget {
  const ProductListScreen({
    super.key,
    required this.title,
    this.categoryId = 0,
    this.maxPrice,
    this.onlyBulk = false,
    this.sort = HomeSort.bestSelling,
    this.productsFuture,
  });

  final String title;
  final int categoryId;
  final double? maxPrice;
  final bool onlyBulk;
  final HomeSort sort;

  /// منتجات محددة بدل الفلتر (مثلاً "عرض الكل" لصف المنتجات المختارة بالرئيسية)
  final Future<List<Map<String, dynamic>>>? productsFuture;

  @override
  Widget build(BuildContext context) {
    final m = context.modo;
    return Scaffold(
      backgroundColor: m.background,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: m.page,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 24),
            sliver: HomeProductGrid(
              categoryId: categoryId,
              maxPrice: maxPrice,
              onlyBulk: onlyBulk,
              sort: sort,
              productsFuture: productsFuture,
            ),
          ),
        ],
      ),
    );
  }
}
