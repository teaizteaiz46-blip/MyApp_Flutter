import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/offline_cache.dart';
import '../../core/product_options.dart' show pieces;
import '../../main.dart';
import '../../services/app_config.dart';
import '../../services/cart_service.dart';
import '../../services/offers_service.dart';
import '../../services/splash_ad_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_controller.dart';
import '../../widgets/chat_fab.dart';
import '../../widgets/welcome_coupon_dialog.dart';
import '../appearance/appearance_screen.dart';
import '../auth/profile_screen.dart';
import '../cart/cart_screen.dart';
import '../categories/all_categories_screen.dart';
import '../clips/clips_screen.dart';
import '../details/details_screen.dart';
import '../offers/offers_screen.dart';
import '../search/search_screen.dart';
import 'components/home_product_grid.dart';
import 'components/home_product_row.dart';
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

  /// الزبونة غيّرت القسم أو الترتيب بنفسها: بعدها ما نطبق إعداد الأدمن فوك اختيارها
  bool _userPicked = false;

  late Future<_Rows> _categoriesFuture;
  _Rows? _categories;
  List<BannerSlide> _slides = const [];

  bool _showTop = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    // القسم والترتيب الافتراضي من صفحة الأدمن (آخر نسخة بالجهاز فوراً، والجديدة من السيرفر)
    _applyHomeDefaults();
    AppConfig.changes.addListener(_onConfigChanged);
    unawaited(AppConfig.refresh());
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
      _afterSplash();
      return;
    }
    void listener() {
      if (splash.value) return;
      splash.removeListener(listener);
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted && _tab == _homeTab) _afterSplash();
      });
    }
    splash.addListener(listener);
  }

  /// أول فتحة: شاشة اختيار المظهر، وبعد ما تتسكّر كوبون الترحيب
  Future<void> _afterSplash() async {
    if (!ThemeController.hasChoice) {
      final keepGoing = await maybeShowThemeChooser(context);
      if (!keepGoing || !mounted || _tab != _homeTab) return;
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (!mounted || _tab != _homeTab) return;
    }
    if (!mounted) return;
    maybeShowWelcomeCoupon(context);
  }

  @override
  void dispose() {
    AppConfig.changes.removeListener(_onConfigChanged);
    _scroll.dispose();
    super.dispose();
  }

  // --------------------------------------------------------------------------
  // الرئيسية الافتراضية (store_settings.home_default_category / home_default_sort)

  void _applyHomeDefaults() {
    if (_userPicked) return;
    _sort = HomeSort.values.where((s) => s.name == AppConfig.homeSort).firstOrNull ?? HomeSort.bestSelling;
    _selectedCategoryId = AppConfig.homeCategory;
    _selectedCategoryName = '';
    _checkDefaultCategory();
  }

  void _onConfigChanged() {
    if (!mounted) return;
    // صف المنتجات بدل البانر ممكن تغيّر من الأدمن: نعيد الرسم دائماً
    setState(_applyHomeDefaults);
  }

  /// القسم الافتراضي لازم يكون بيه منتجات متوفرة، وإلا "الكل". ونجيب اسمه للعنوان.
  void _checkDefaultCategory() {
    if (_userPicked || _selectedCategoryId == 0) return;
    final rows = _categories;
    if (rows == null) return; // الأقسام بعدها ما وصلت: نتأكد من توصل
    final match = rows.where((c) =>
        (c['id'] as num).toInt() == _selectedCategoryId && ((c['products_in_stock'] as num?)?.toInt() ?? 0) > 0);
    if (match.isEmpty) {
      _selectedCategoryId = 0;
      _selectedCategoryName = '';
    } else {
      _selectedCategoryName = (match.first['name'] ?? '').toString();
    }
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
        _checkDefaultCategory();
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
      if (mounted) {
        setState(() {
          _categories = rows;
          _checkDefaultCategory();
        });
      }
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
        _userPicked = true;
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
      _userPicked = true;
      _selectedCategoryId = id;
      _selectedCategoryName = name;
    });
    _scrollToGrid();
  }

  void _setSort(HomeSort sort) {
    if (sort == _sort) return;
    setState(() {
      _userPicked = true;
      _sort = sort;
    });
    _scrollToGrid();
  }

  Future<void> _pickSort() async {
    final picked = await showModalBottomSheet<HomeSort>(
      context: context,
      showDragHandle: true,
      backgroundColor: context.modo.surface,
      builder: (_) => _SortSheet(current: _sort),
    );
    if (picked != null) _setSort(picked);
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
    final m = context.modo;
    return Scaffold(
      backgroundColor: m.background,
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
                    backgroundColor: m.strong.withValues(alpha: 0.88),
                    foregroundColor: m.onStrong,
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

  Widget _banner() {
    if (_slides.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: PromoCarousel(slides: _slides, onSlideTap: _onBannerTap, onColorChanged: (_) {}),
      ),
    );
  }

  Widget _buildHome(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    final m = context.modo;
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
      color: m.page,
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
              backgroundColor: m.page,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              systemOverlayStyle: m.overlay,
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
            // صف منتجات بالعرض (من الأدمن) بدل البانر؛ إذا مطفي أو ماكو منتجات متوفرة يرجع البانر
            if (AppConfig.homeRow case final row?)
              SliverToBoxAdapter(
                child: HomeProductRow(
                  key: ValueKey('home-row-${row.cacheKey}-$_refreshTick'),
                  config: row,
                  fallback: _banner(),
                ),
              )
            else if (_slides.isNotEmpty)
              SliverToBoxAdapter(child: _banner()),
            // الأقسام بس تبقى ثابتة فوك وقت التمرير؛ الترتيب صار زر يم العنوان
            SliverPersistentHeader(
              pinned: true,
              delegate: _FiltersDelegate(
                categories: cats,
                total: total,
                selectedId: _selectedCategoryId,
                onCategory: _selectCategory,
              ),
            ),
            SliverToBoxAdapter(
              child: KeyedSubtree(
                key: _gridAnchor,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // العنوان والعدد بنص واحد ياخذ كل المساحة لحد زر الترتيب
                          Expanded(
                            child: Text.rich(
                              TextSpan(children: [
                                TextSpan(text: _selectedCategoryId == 0 ? 'كل التشكيلة' : _selectedCategoryName),
                                if (shownCount > 0)
                                  TextSpan(
                                    text: '  $shownCount منتج',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: m.textHint),
                                  ),
                              ]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: m.ink),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _SortButton(sort: _sort, onTap: _pickSort),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const _WholesaleLine(),
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
    final m = context.modo;
    return NavigationBarTheme(
      data: NavigationBarThemeData(
        backgroundColor: m.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: m.brandSoft,
        height: 66,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => TextStyle(
            fontSize: 12,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            color: s.contains(WidgetState.selected) ? m.brandText : m.muted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(color: s.contains(WidgetState.selected) ? m.brandText : m.muted),
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: m.line))),
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
    final m = context.modo;
    return Material(
      color: m.fill,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          height: 42,
          child: Row(
            children: [
              const SizedBox(width: 14),
              Icon(Icons.search_rounded, color: m.ink, size: 21),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'ابحثي عن حجاب، شال، عباية...',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: m.muted, fontSize: 13.5),
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
    final style = TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.modo.textSoft);
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
              Text('💵 الدفع عند الاستلام', style: style),
              const SizedBox(width: 14),
              Text('↩️ إرجاع سهل', style: style),
            ],
          ),
        ),
      ),
    );
  }
}

/// سطر الجملة الصغير تحت العنوان (بدل المربع المتقطع الكبير)
class _WholesaleLine extends StatelessWidget {
  const _WholesaleLine();

  @override
  Widget build(BuildContext context) {
    final m = context.modo;
    return Text.rich(
      TextSpan(children: [
        const TextSpan(text: '✨ '),
        TextSpan(text: 'جملة من 6 قطع', style: TextStyle(color: m.success, fontWeight: FontWeight.w900)),
        const TextSpan(text: ': سعر القطعة ينزل تلقائياً'),
      ]),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: m.hintText),
    );
  }
}

/// خيارات الترتيب: (الترتيب، الأيقونة، الاسم). الأيقونة منفصلة عن الكلام
/// (بالآيفون الإيموجي ويه الكلام بنفس السطر كان يخفي "طلباً").
const List<(HomeSort, String, String)> _kSorts = [
  (HomeSort.bestSelling, '🔥', 'الأكثر طلباً'),
  (HomeSort.newest, '✨', 'الأحدث'),
  (HomeSort.cheapest, '💰', 'الأرخص'),
  (HomeSort.bulkOffers, '🛍️', 'عروض الكمية'),
];

/// زر الترتيب الصغير يم العنوان: "⇅ الأكثر طلباً ▾"
class _SortButton extends StatelessWidget {
  const _SortButton({required this.sort, required this.onTap});

  final HomeSort sort;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final m = context.modo;
    final label = _kSorts.where((s) => s.$1 == sort).map((s) => s.$3).firstOrNull ?? 'ترتيب';
    return Material(
      color: m.surface,
      shape: StadiumBorder(side: BorderSide(color: m.border)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(10, 5, 6, 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.swap_vert_rounded, size: 16, color: AppColors.brand),
              const SizedBox(width: 4),
              Text(
                label,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: m.textBody),
              ),
              Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: m.textHint),
            ],
          ),
        ),
      ),
    );
  }
}

/// قائمة الترتيب من جوه
class _SortSheet extends StatelessWidget {
  const _SortSheet({required this.current});

  final HomeSort current;

  @override
  Widget build(BuildContext context) {
    final m = context.modo;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('ترتيب المنتجات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: m.ink)),
            ),
            for (final (sort, icon, label) in _kSorts)
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => Navigator.of(context).pop(sort),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: sort == current ? AppColors.brand.withValues(alpha: 0.14) : m.background,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(icon, style: const TextStyle(fontSize: 16)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: sort == current ? FontWeight.w900 : FontWeight.w600,
                            color: sort == current ? AppColors.brand : m.ink,
                          ),
                        ),
                      ),
                      if (sort == current) const Icon(Icons.check_rounded, color: AppColors.brand),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// الفئات (مع العدد) — تبقى ثابتة فوق وية التمرير (الترتيب صار زر يم العنوان)
class _FiltersDelegate extends SliverPersistentHeaderDelegate {
  _FiltersDelegate({
    required this.categories,
    required this.total,
    required this.selectedId,
    required this.onCategory,
  });

  final List<Map<String, dynamic>> categories;
  final int total;
  final int selectedId;
  final void Function(int id, String name) onCategory;

  /// صف الأقسام بس (كان 98 ويه صف الترتيب)
  static const double _height = 54;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  Widget _catChip(ModoColors m, String name, int? count, bool on, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
        decoration: BoxDecoration(
          color: on ? AppColors.brand : m.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: on ? AppColors.brand : m.border),
        ),
        child: Text.rich(
          TextSpan(children: [
            TextSpan(text: name),
            if (count != null)
              TextSpan(
                text: ' $count',
                style: TextStyle(
                  fontSize: 11,
                  color: on ? Colors.white.withValues(alpha: 0.75) : m.textBody.withValues(alpha: 0.75),
                ),
              ),
          ]),
          maxLines: 1,
          softWrap: false,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: on ? Colors.white : m.textBody),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final m = context.modo;
    return Container(
      height: _height,
      decoration: BoxDecoration(
        color: m.page,
        border: Border(bottom: BorderSide(color: m.pick(const Color(0xFFF2F2F2), m.line))),
      ),
      // 10 + 34 + 9 + خط 1 تحت = 54
      padding: const EdgeInsets.only(top: 10, bottom: 9),
      child: Column(
        children: [
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              children: [
                _catChip(m, 'الكل', total > 0 ? total : null, selectedId == 0, () => onCategory(0, '')),
                for (final c in categories) ...[
                  const SizedBox(width: 8),
                  _catChip(
                    m,
                    (c['name'] ?? '').toString(),
                    (c['products_in_stock'] as num?)?.toInt(),
                    (c['id'] as num).toInt() == selectedId,
                    () => onCategory((c['id'] as num).toInt(), (c['name'] ?? '').toString()),
                  ),
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
      old.selectedId != selectedId || old.categories != categories || old.total != total;
}
