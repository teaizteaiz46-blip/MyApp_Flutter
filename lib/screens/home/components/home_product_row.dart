import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/offline_cache.dart';
import '../../../main.dart';
import '../../../services/app_config.dart';
import '../../../services/offers_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/modo_product_card.dart';
import '../../details/details_screen.dart';
import '../product_list_screen.dart';
import 'home_product_grid.dart';

/// صف منتجات بالعرض بالرئيسية (بدل البانر)، من صفحة الأدمن: قسم أو منتجات مختارة.
/// إذا ماكو منتجات متوفرة يطلع [fallback] (البانر)، حتى الرئيسية ما تبقى فارغة.
class HomeProductRow extends StatefulWidget {
  const HomeProductRow({super.key, required this.config, required this.fallback});

  final HomeRowConfig config;
  final Widget fallback;

  @override
  State<HomeProductRow> createState() => _HomeProductRowState();
}

class _HomeProductRowState extends State<HomeProductRow> {
  List<Map<String, dynamic>>? _rows;

  HomeRowConfig get _c => widget.config;

  @override
  void initState() {
    super.initState();
    // شارات العروض ("🎁 عرض") على الكارت
    OffersService.load().then((offers) {
      if (mounted && offers.isNotEmpty) setState(() {});
    });
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await OfflineCache.fetch(
        'home_row_${_c.cacheKey}',
        () => _query(),
        onFresh: (fresh) {
          if (mounted) setState(() => _rows = fresh);
        },
      );
      if (mounted) setState(() => _rows = rows);
    } catch (e) {
      debugPrint('Home row error: $e');
      if (mounted) setState(() => _rows = const []);
    }
  }

  /// المتوفر بس. المختارة بترتيب المدير، والقسم الأحدث أولاً.
  Future<List<Map<String, dynamic>>> _query({bool all = false}) async {
    final base = supabase.from('products_ranked').select(kRankedColumns).gt('stock', 0);
    if (_c.isPicked) {
      final rows = await base.inFilter('id', _c.productIds);
      final byId = {for (final r in rows) (r['id'] as num).toInt(): r};
      final ordered = [for (final id in _c.productIds) if (byId[id] case final r?) r];
      return all ? ordered : ordered.take(_c.limit).toList();
    }
    final rows = await base
        .eq('category_id', _c.categoryId!)
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .limit(_c.limit);
    return List<Map<String, dynamic>>.from(rows);
  }

  /// "عرض الكل": قسم (المختار للزر، أو قسم الصف)، أو كل المنتجات المختارة
  VoidCallback? get _onSeeAll {
    final title = _c.title.isEmpty ? 'مختارات لكم' : _c.title;
    final cat = _c.allCategoryId ?? _c.categoryId;
    if (cat != null) {
      return () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ProductListScreen(title: title, categoryId: cat, sort: HomeSort.newest),
          ));
    }
    if (_c.productIds.length <= _c.limit) return null; // كلهن ظاهرات أصلاً
    return () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ProductListScreen(title: title, productsFuture: _query(all: true)),
        ));
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    if (rows != null && rows.isEmpty) return widget.fallback;
    return HomeProductRowView(
      title: _c.title.isEmpty ? 'مختارات لكم' : _c.title,
      subtitle: _c.subtitle,
      products: rows == null ? null : [for (final p in rows) OffersService.apply(p)],
      onSeeAll: _onSeeAll,
      onProductTap: (p) => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => DetailsScreen(productId: (p['id'] as num).toInt()),
      )),
    );
  }
}

/// شكل الصف (بدون تحميل): عنوان + "عرض الكل" + كروت تنسحب يمين ويسار.
/// [products] = null يعني بعده يحمّل (مربعات رمادية بنفس الحجم حتى الصفحة ما تنط).
class HomeProductRowView extends StatelessWidget {
  const HomeProductRowView({
    super.key,
    required this.title,
    required this.subtitle,
    required this.products,
    required this.onProductTap,
    this.onSeeAll,
  });

  final String title;
  final String subtitle;
  final List<Map<String, dynamic>>? products;
  final void Function(Map<String, dynamic> product) onProductTap;
  final VoidCallback? onSeeAll;

  static const double cardWidth = 156;
  static const double _gap = 10;

  /// ارتفاع الصف: صورة 4:5 + الاسم والسعر (والسعر ممكن ينزل لسطرين بالكارت الضيق)
  static double heightFor(BuildContext context) =>
      cardWidth * 5 / 4 + MediaQuery.textScalerOf(context).scale(78);

  @override
  Widget build(BuildContext context) {
    final m = context.modo;
    final items = products;
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // العنوان والسطر الصغير بنص واحد ياخذ كل المساحة (Flexible ويه Spacer كان يقص العنوان بالنص)
                Expanded(
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(text: title),
                      if (subtitle.isNotEmpty)
                        TextSpan(
                          text: '  $subtitle',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: m.muted),
                        ),
                    ]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: m.ink),
                  ),
                ),
                if (onSeeAll != null)
                  Material(
                    color: AppColors.brand.withValues(alpha: m.isDark ? 0.18 : 0.12),
                    borderRadius: BorderRadius.circular(99),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(99),
                      onTap: onSeeAll,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        child: Text(
                          'عرض الكل ←',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: m.isDark ? AppColors.brand : AppColors.brandDark,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: heightFor(context),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              physics: const BouncingScrollPhysics(),
              itemCount: items?.length ?? 3,
              separatorBuilder: (_, _) => const SizedBox(width: _gap),
              itemBuilder: (context, i) {
                if (items == null) {
                  return Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      width: cardWidth,
                      height: cardWidth * 5 / 4,
                      decoration: BoxDecoration(color: m.placeholder, borderRadius: BorderRadius.circular(16)),
                    ),
                  );
                }
                final p = items[i];
                return SizedBox(
                  width: cardWidth,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ModoProductCard(
                      key: ValueKey(p['id']),
                      product: p,
                      swipeImages: false,
                      singleBadge: true,
                      onTap: () => onProductTap(p),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
