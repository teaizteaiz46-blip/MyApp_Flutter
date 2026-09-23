import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../../core/offline_cache.dart';
import '../../../core/shop_api.dart';
import '../../../main.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/modo_product_card.dart';
import '../../details/details_screen.dart';

/// ترتيب المنتجات بالتبويبات.
enum HomeSort { mix, bestSelling, newest }

/// الأعمدة من عرض products_ranked (نفس أعمدة المنتج + الترتيب داخل الفئة).
/// العرض ما بيه bulk_tiers بعد، فنستخدم الأعمدة الأساسية حتى ما يفشل الاستعلام.
/// لما ينضاف العمود للعرض بالسيرفر بدّلها لـ kProductColumns.
const String kRankedColumns = '$kProductBaseColumns, offer_ends_at, category_name, category_rank';

class HomeProductGrid extends StatefulWidget {
  final int categoryId;
  final Future<List<Map<String, dynamic>>>? productsFuture;
  final bool onlyOffers;
  final bool isMix;
  final HomeSort sort;

  const HomeProductGrid({
    super.key,
    required this.categoryId,
    this.productsFuture,
    this.onlyOffers = false,
    this.isMix = false,
    this.sort = HomeSort.newest,
  });

  HomeSort get effectiveSort => isMix ? HomeSort.mix : sort;

  @override
  State<HomeProductGrid> createState() => _HomeProductGridState();
}

class _HomeProductGridState extends State<HomeProductGrid> {
  static const int _pageSize = 10;

  final List<Map<String, dynamic>> _products = [];
  int _currentPage = 0;
  bool _isLoading = false;
  bool _hasMore = true;
  bool _isInitialLoad = true;
  bool _didError = false;

  /// يزيد كل ما تتغير الفئة، حتى نتجاهل نتائج الطلبات القديمة.
  int _generation = 0;

  bool get _isExternal => widget.productsFuture != null;

  @override
  void initState() {
    super.initState();
    if (_isExternal) {
      _hasMore = false;
      _loadExternalFuture();
    } else {
      _fetchProducts();
    }
  }

  @override
  void didUpdateWidget(HomeProductGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    final filtersChanged = oldWidget.categoryId != widget.categoryId ||
        oldWidget.onlyOffers != widget.onlyOffers ||
        oldWidget.isMix != widget.isMix ||
        oldWidget.sort != widget.sort;

    if (!_isExternal && filtersChanged) {
      _generation++;
      _products.clear();
      _currentPage = 0;
      _isLoading = false;
      _hasMore = true;
      _isInitialLoad = true;
      _didError = false;
      _fetchProducts();
    }
  }

  Future<void> _loadExternalFuture() async {
    try {
      final data = await widget.productsFuture!;
      if (!mounted) return;
      setState(() {
        _products.addAll(data);
        _isInitialLoad = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isInitialLoad = false;
        _didError = true;
      });
    }
  }

  Future<void> _fetchProducts() async {
    if (_isLoading || !_hasMore) return;
    final generation = _generation;
    setState(() => _isLoading = true);

    try {
      final from = _currentPage * _pageSize;
      final to = from + _pageSize - 1;

      var query = supabase.from('products_ranked').select(kRankedColumns).gt('stock', 0);
      if (widget.categoryId != 0) {
        query = query.eq('category_id', widget.categoryId);
      }
      if (widget.onlyOffers) {
        query = query.eq('is_offer', true);
      }

      Future<List<Map<String, dynamic>>> load() async => switch (widget.effectiveSort) {
            HomeSort.mix => await query.order('random_id', ascending: true).order('id').range(from, to),
            HomeSort.bestSelling => await query
                .order('sales_count', ascending: false, nullsFirst: false)
                .order('id')
                .range(from, to),
            HomeSort.newest => await query.order('created_at', ascending: false).order('id').range(from, to),
          };

      // الصفحة الأولى تفتح فوراً من الجهاز وتتحدث بالخلفية؛ الصفحات الباقية من السيرفر مباشرة.
      final data = _currentPage == 0
          ? await OfflineCache.fetch(
              'grid_${widget.categoryId}_${widget.onlyOffers}_${widget.effectiveSort.name}',
              load,
              onFresh: (fresh) {
                if (!mounted || generation != _generation || _currentPage != 1) return;
                setState(() {
                  _products
                    ..clear()
                    ..addAll(fresh);
                  _hasMore = fresh.length >= _pageSize;
                });
              },
            )
          : await load();

      // الفئة تغيّرت أثناء التحميل: نتجاهل هاي النتيجة
      if (!mounted || generation != _generation) return;

      setState(() {
        _products.addAll(data);
        _currentPage++;
        _isLoading = false;
        _isInitialLoad = false;
        if (data.length < _pageSize) _hasMore = false;
      });
    } catch (e) {
      debugPrint('HomeProductGrid: $e');
      if (!mounted || generation != _generation) return;
      setState(() {
        _isLoading = false;
        _isInitialLoad = false;
        _didError = _products.isEmpty;
        _hasMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitialLoad) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (_didError || _products.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
          child: Column(
            children: [
              Icon(
                _didError ? Icons.wifi_off_rounded : Icons.inventory_2_outlined,
                size: 44,
                color: AppColors.muted,
              ),
              const SizedBox(height: 10),
              Text(
                _didError ? 'تعذر تحميل المنتجات، اسحب للأسفل للتحديث' : 'لا توجد منتجات هنا حالياً',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted),
              ),
            ],
          ),
        ),
      );
    }

    return SliverMasonryGrid(
      gridDelegate: const SliverSimpleGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index >= _products.length) {
            if (!_isExternal && !_isLoading) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _fetchProducts();
              });
            }
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
            );
          }

          final product = _products[index];
          return ModoProductCard(
            key: ValueKey(product['id']),
            product: product,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DetailsScreen(productId: (product['id'] as num).toInt()),
              ),
            ),
          );
        },
        childCount: _products.length + (_hasMore ? 1 : 0),
      ),
    );
  }
}
