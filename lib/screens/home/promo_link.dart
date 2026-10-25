import 'package:flutter/widgets.dart';

import '../../widgets/modo_product_card.dart' show kMoney;
import '../details/details_screen.dart';
import 'components/home_product_grid.dart' show HomeSort;
import 'product_list_screen.dart';

/// وين يودّي زر الستوري/إعلان الافتتاح: none, product, category, price, bulk, offers.
/// null إذا ماكو رابط أو القيمة غلط.
Widget? promoTarget(String type, String? value, {String label = '', String source = 'app'}) {
  final v = value ?? '';
  return switch (type) {
    'product' when int.tryParse(v) != null => DetailsScreen(productId: int.parse(v), source: source),
    'category' when int.tryParse(v) != null => ProductListScreen(
        title: label.isEmpty ? 'القسم' : label,
        categoryId: int.parse(v),
        sort: HomeSort.newest,
      ),
    'price' when double.tryParse(v) != null =>
      ProductListScreen(title: 'تحت ${kMoney.format(double.parse(v))} د.ع', maxPrice: double.parse(v)),
    'bulk' => const ProductListScreen(title: 'عروض الكمية', onlyBulk: true),
    'offers' => const ProductListScreen(title: 'العروض', sort: HomeSort.bestSelling),
    _ => null,
  };
}
