import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/offline_cache.dart';
import '../../core/product_options.dart' show pieces;
import '../../main.dart';
import '../../services/cart_service.dart';
import '../../services/offers_service.dart';
import '../../services/splash_ad_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/chat_fab.dart';
import '../../widgets/welcome_coupon_dialog.dart';
import '../auth/profile_screen.dart';
import '../cart/cart_screen.dart';
import '../categories/all_categories_screen.dart';
import '../clips/clips_screen.dart';
import '../details/details_screen.dart';
import '../offers/offers_screen.dart';
import '../search/search_screen.dart';
import 'components/home_product_grid.dart';
import 'components/promo_carousel.dart';

typedef _Rows = List<Map<String, dynamic>>;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ترتيب التبويبات: الأول يظهر يمين الشاشة لأن التطبيق عربي
  static const int _homeTab = 0;
  static const int _categoriesTab = 1;
  static const int _clipsTab = 2;
  static const int _cartTab = 3;
  static const double _toolbarHeight = 64;

  final ScrollController _scroll = ScrollController();
  final GlobalKey _gridAnchor = GlobalKey();

  int _tab = _homeTab;
  int _selectedCategoryId = 0;
  String _selectedCategoryName = '';
  HomeSort _sort = HomeSort.bestSelling;
  int _refreshTick = 0;

  late Future<_Rows> _categoriesFuture;
  _Rows? _categories;
  List<BannerSlide> _slides = const [];

  bool _showTop = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _loadSections();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted && _tab == _homeTab) _showCouponAfterSplash();
      });
    });
  }

  /// كوبون الترحيب ما يطلع فوق إعلان الافتتاح: ينتظره يتسكّر
  void _showCouponAfterSplash() {
    final splash = SplashAdService.showing;
    if (!splash.value) {
      maybeShowWelcomeCoupon(context);
      return;
    }
    void listener() {
      if (splash.value) return;
      splash.removeListener(listener);
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted && _tab == _homeTab) maybeShowWelcomeCoupon(context);
      });
    }
    splash.addListener(listener);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  // --------------------------------------------------------------------------
  // البيانات

  // كل قسم يفتح فوراً من آخر نسخة محفوظة بالجهاز، ويتحدث من السيرفر بالخلفية.
  void _loadSections() {
    void setCategories(_Rows rows) {
      if (!mounted) return;
      setState(() {
        _categories = rows;
        _categoriesFuture = Future.value(rows);
      });
    }

    _categoriesFuture = _fetch(() => OfflineCache.fetch(
          'home_categories_v2',
          () async => await supabase
              .from('categories_home')
              .select('id, name, image_url, products_in_stock, total_sales, sort_order')
              // الترتيب يتحكم بي المشرف (sort_order)، والأقسام بدون رقم تجي بالأخير حسب id
              .order('sort_order', ascending: true, nullsFirst: false)
              .order('id', ascending: true),
          onFresh: setCategories,
        ));
    _categoriesFuture.then((rows) {
      if (mounted) setState(() => _categories = rows);
    });

    void setSlides(_Rows rows) {
      if (!mounted) return;
      setState(() => _slides = slidesFromRows(rows));
    }

    _fetch(() => OfflineCache.fetch(
          'home_banners',
          () async => await supabase
              .from('active_banners')
              .select()
              .order('sort_order', ascending: true)
              .order('id', ascending: true),
          onFresh: setSlides,
        )).then(setSlides);
  }

  /// يرجّع قائمة فارغة بدل الخطأ للأقسام الثانوية، والقسم يختفي بهدوء.
  Future<_Rows> _fetch(Future<_Rows> Function() run) async {
    try {
      return await run();
    } catch (e) {
      debugPrint('Home section error: $e');
      return const [];
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _loadSections();
      _refreshTick++;
    });
    await _categoriesFuture;
  }

  // --------------------------------------------------------------------------
  // التمرير والتنقل

  void _onScroll() {
    final showTop = _scroll.offset > 1400;
    if (showTop != _showTop) setState(() => _showTop = showTop);
  }

  void _scrollToGrid() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _gridAnchor.currentContext;
      if (ctx == null || !_scroll.hasClients) return;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null) return;
      final y = box.localToGlobal(Offset.zero).dy;
      final pinned = MediaQuery.paddingOf(context).top + _toolbarHeight + _FiltersDelegate._height;
      final target = (_scroll.offset + y - pinned).clamp(0.0, _scroll.position.maxScrollExtent).toDouble();
      if ((target - _scroll.offset).abs() < 4) return;
      _scroll.animateTo(target, duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic);
    });
  }

  void _scrollToTop() {
    if (_scroll.hasClients) {
      _scroll.animateTo(0, duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
    }
  }

  void _onTabSelected(int index) {
    if (index == _homeTab && _tab == _homeTab) {
      setState(() {
        _selectedCategoryId = 0;
        _selectedCategoryName = '';
      });
      _scrollToTop();
      return;
    }
    setState(() {
      _tab = index;
      _showTop = false;
    });
  }

  void _selectCategory(int id, String name) {
    setState(() {
      _selectedCategoryId = id;
      _selectedCategoryName = name;
    });
    _scrollToGrid();
  }

  void _setSort(HomeSort sort) {
    if (sort == _sort) return;
    setState(() => _sort = sort);
    _scrollToGrid();
  }

  void _push(Widget screen) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  void _onBannerTap(BannerSlide slide) {
    final id = int.tryParse(slide.linkValue ?? '');
    switch (slide.linkType) {
      case 'none':
        return;
      case 'product':
        if (id != null) _push(DetailsScreen(productId: id));
        return;
      case 'category':
        if (id == null) return;
        final match = (_categories ?? const []).where((c) => (c['id'] as num).toInt() == id);
        final name = match.isEmpty ? (slide.row['title'] ?? '').toString() : (match.first['name'] ?? '').toString();
        _selectCategory(id, name);
        return;
      default:
        _push(const OffersScreen());
    }
  }

  // --------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: switch (_tab) {
        _homeTab => _buildHome(context),
        _categoriesTab => const AllCategoriesScreen(),
        _clipsTab => const ClipsScreen(),
        _cartTab => const CartScreen(),
        _ => const ProfileScreen(),
      },
      floatingActionButton: _tab == _homeTab
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_showTop) ...[
                  FloatingActionButton.small(
                    heroTag: 'home-top',
                    tooltip: 'للأعلى',
                    backgroundColor: AppColors.ink.withValues(alpha: 0.88),
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shape: const CircleBorder(),
                    onPressed: _scrollToTop,
                    child: const Icon(Icons.arrow_upward_rounded),
                  ),
                  const SizedBox(height: 10),
                ],
                const ChatFab(),
              ],
            )
          : null,
      bottomNavigationBar: _BottomNav(selected: _tab, onSelected: _onTabSelected),
    );
  }

  Widget _buildHome(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    final cats = (_categories ?? const <Map<String, dynamic>>[])
        .where((c) => ((c['products_in_stock'] as num?)?.toInt() ?? 0) > 0)
        .toList();
    final total = cats.fold<int>(0, (s, c) => s + ((c['products_in_stock'] as num?)?.toInt() ?? 0));
    final shownCount = _selectedCategoryId == 0
        ? total
        : cats
            .where((c) => (c['id'] as num).toInt() == _selectedCategoryId)
            .fold<int>(0, (s, c) => s + ((c['products_in_stock'] as num?)?.toInt() ?? 0));

    return ColoredBox(
      color: Colors.white,
      child: RefreshIndicator(
        onRefresh: _refresh,
        edgeOffset: topPadding + _toolbarHeight,
        child: CustomScrollView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              automaticallyImplyLeading: false,
              toolbarHeight: _toolbarHeight,
              titleSpacing: 14,
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              systemOverlayStyle: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
              title: Row(
                children: [
                  const Text(
                    'MODO',
                    textDirection: TextDirection.ltr,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.brand, letterSpacing: 2),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: _SearchField(onTap: () => _push(const SearchScreen()))),
                  const SizedBox(width: 10),
                  _CartIcon(onTap: () => _onTabSelected(_cartTab)),
                ],
              ),
            ),
            const SliverToBoxAdapter(child: _TrustRow()),
            if (_slides.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: PromoCarousel(slides: _slides, onSlideTap: _onBannerTap, onColorChanged: (_) {}),
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: _WholesaleNotice()),
            SliverPersistentHeader(
              pinned: true,
              delegate: _FiltersDelegate(
                categories: cats,
                total: total,
                selectedId: _selectedCategoryId,
                sort: _sort,
                onCategory: _selectCategory,
                onSort: _setSort,
              ),
            ),
            SliverToBoxAdapter(
              child: KeyedSubtree(
                key: _gridAnchor,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: Text(
                          _selectedCategoryId == 0 ? 'كل التشكيلة' : _selectedCategoryName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.ink),
                        ),
                      ),
                      if (shownCount > 0)
                        Text('$shownCount منتج', style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
                    ],
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
              sliver: HomeProductGrid(
                key: ValueKey('home-grid-$_refreshTick'),
                categoryId: _selectedCategoryId,
                sort: _sort,
                pinnedExtent: topPadding + _toolbarHeight + _FiltersDelegate._height,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// عناصر الصفحة

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.selected, required this.onSelected});

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return NavigationBarTheme(
      data: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.brandSoft,
        height: 66,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => TextStyle(
            fontSize: 12,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            color: s.contains(WidgetState.selected) ? AppColors.brandDark : AppColors.muted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(color: s.contains(WidgetState.selected) ? AppColors.brandDark : AppColors.muted),
        ),
      ),
      child: DecoratedBox(
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.line))),
        child: ValueListenableBuilder<List<CartLine>>(
          valueListenable: CartService.instance.lines,
          builder: (context, lines, _) {
            final count = lines.fold<int>(0, (sum, l) => sum + l.quantity);
            Widget cartIcon(IconData icon) => Badge(
                  isLabelVisible: count > 0,
                  backgroundColor: AppColors.sale,
                  label: Text(count > 99 ? '99+' : '$count'),
                  child: Icon(icon),
                );
            return NavigationBar(
              selectedIndex: selected,
              onDestinationSelected: onSelected,
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: 'الرئيسية',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.grid_view_outlined),
                  selectedIcon: Icon(Icons.grid_view_rounded),
                  label: 'الفئات',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.play_circle_outline_rounded),
                  selectedIcon: Icon(Icons.play_circle_rounded),
                  label: 'مقاطع',
                ),
                NavigationDestination(
                  icon: cartIcon(Icons.shopping_bag_outlined),
                  selectedIcon: cartIcon(Icons.shopping_bag_rounded),
                  label: 'السلة',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.person_outline_rounded),
                  selectedIcon: Icon(Icons.person_rounded),
                  label: 'حسابي',
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: const SizedBox(
          height: 42,
          child: Row(
            children: [
              SizedBox(width: 14),
              Icon(Icons.search_rounded, color: AppColors.ink, size: 21),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'ابحثي عن حجاب، شال، عباية...',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.muted, fontSize: 13.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// سلة صغيرة بالهيدر وعليها عدد القطع
class _CartIcon extends StatelessWidget {
  const _CartIcon({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ValueListenableBuilder<List<CartLine>>(
        valueListenable: CartService.instance.lines,
        builder: (context, lines, _) {
          final count = lines.fold<int>(0, (sum, l) => sum + l.quantity);
          return SizedBox(
            width: 34,
            height: 34,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                const Text('🛍️', style: TextStyle(fontSize: 20)),
                if (count > 0)
                  Positioned(
                    top: -2,
                    left: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(color: AppColors.brand, borderRadius: BorderRadius.circular(9)),
                      child: Text(
                        count > 99 ? '99+' : '$count',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// سطر الثقة تحت الهيدر
class _TrustRow extends StatelessWidget {
  const _TrustRow();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF666666));
    // إذا المتجر مشغّل التوصيل المجاني حسب عدد القطع، يطلع بدل "توصيل لكل العراق"
    return ValueListenableBuilder<int?>(
      valueListenable: OffersService.freeDeliveryPieces,
      builder: (context, freeFrom, _) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 2, 8, 10),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(freeFrom != null ? '🚚 توصيل مجاني من ${pieces(freeFrom)}' : '🚚 توصيل لكل العراق', style: style),
              const SizedBox(width: 14),
              const Text('💵 الدفع عند الاستلام', style: style),
              const SizedBox(width: 14),
              const Text('↩️ إرجاع سهل', style: style),
            ],
          ),
        ),
      ),
    );
  }
}

/// شريط أسعار الجملة (إطار متقطع)
class _WholesaleNotice extends StatelessWidget {
  const _WholesaleNotice();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      child: CustomPaint(
        painter: const DashedRRectPainter(color: Color(0xFFF5B183), radius: 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(color: const Color(0xFFFFF4EC), borderRadius: BorderRadius.circular(12)),
          child: const Text(
            '✨ أسعار جملة من 6 قطع – كل ما تزيدين ينزل سعر القطعة تلقائياً',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFFB4501A), height: 1.5),
          ),
        ),
      ),
    );
  }
}

/// إطار متقطع بزوايا دائرية
class DashedRRectPainter extends CustomPainter {
  const DashedRRectPainter({required this.color, this.radius = 12, this.dash = 5, this.gap = 4});

  final Color color;
  final double radius;
  final double dash;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)).deflate(0.5));
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + dash), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(DashedRRectPainter oldDelegate) => oldDelegate.color != color;
}

/// الفئات (مع العدد) + الترتيب — تبقى ثابتة فوق وية التمرير
class _FiltersDelegate extends SliverPersistentHeaderDelegate {
  _FiltersDelegate({
    required this.categories,
    required this.total,
    required this.selectedId,
    required this.sort,
    required this.onCategory,
    required this.onSort,
  });

  final List<Map<String, dynamic>> categories;
  final int total;
  final int selectedId;
  final HomeSort sort;
  final void Function(int id, String name) onCategory;
  final ValueChanged<HomeSort> onSort;

  static const double _height = 98;

  static const _sorts = [
    (HomeSort.bestSelling, '🔥 الأكثر طلباً'),
    (HomeSort.newest, 'الأحدث'),
    (HomeSort.cheapest, 'الأرخص'),
    (HomeSort.bulkOffers, 'عروض الكمية'),
  ];

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  Widget _catChip(String name, int? count, bool on, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
        decoration: BoxDecoration(
          color: on ? AppColors.brand : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: on ? AppColors.brand : const Color(0xFFEEEEEE)),
        ),
        child: Text.rich(
          TextSpan(children: [
            TextSpan(text: name),
            if (count != null)
              TextSpan(
                text: ' $count',
                style: TextStyle(
                  fontSize: 11,
                  color: on ? Colors.white.withValues(alpha: 0.75) : const Color(0xFF555555).withValues(alpha: 0.75),
                ),
              ),
          ]),
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: on ? Colors.white : const Color(0xFF555555)),
        ),
      ),
    );
  }

  Widget _sortChip(String label, bool on, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: on ? const Color(0xFFFFF0F3) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: on ? const Color(0xFFF8C8D6) : const Color(0xFFEEEEEE)),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: on ? const Color(0xFFC2185B) : const Color(0xFF555555)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      height: _height,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF2F2F2))),
      ),
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Column(
        children: [
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              children: [
                _catChip('الكل', total > 0 ? total : null, selectedId == 0, () => onCategory(0, '')),
                for (final c in categories) ...[
                  const SizedBox(width: 8),
                  _catChip(
                    (c['name'] ?? '').toString(),
                    (c['products_in_stock'] as num?)?.toInt(),
                    (c['id'] as num).toInt() == selectedId,
                    () => onCategory((c['id'] as num).toInt(), (c['name'] ?? '').toString()),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 28,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              children: [
                const Center(child: Text('ترتيب: ', style: TextStyle(fontSize: 12, color: Color(0xFF888888)))),
                for (final t in _sorts) ...[
                  const SizedBox(width: 8),
                  Center(child: _sortChip(t.$2, t.$1 == sort, () => onSort(t.$1))),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_FiltersDelegate old) =>
      old.sort != sort || old.selectedId != selectedId || old.categories != categories || old.total != total;
}
