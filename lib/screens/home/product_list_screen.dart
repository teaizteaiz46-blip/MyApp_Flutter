import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'components/home_product_grid.dart';

/// قائمة منتجات بفلتر (تسوّقي حسب السعر، عروض القطعتين، قسم...).
class ProductListScreen extends StatelessWidget {
  const ProductListScreen({
    super.key,
    required this.title,
    this.categoryId = 0,
    this.maxPrice,
    this.onlyBulk = false,
    this.sort = HomeSort.bestSelling,
  });

  final String title;
  final int categoryId;
  final double? maxPrice;
  final bool onlyBulk;
  final HomeSort sort;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 24),
            sliver: HomeProductGrid(categoryId: categoryId, maxPrice: maxPrice, onlyBulk: onlyBulk, sort: sort),
          ),
        ],
      ),
    );
  }
}
