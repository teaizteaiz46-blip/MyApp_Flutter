import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../main.dart';
import '../../services/cart_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/welcome_coupon_dialog.dart';
import '../auth/profile_screen.dart';
import '../cart/cart_screen.dart';
import '../categories/all_categories_screen.dart';
import '../clips/clips_screen.dart';
import '../details/details_screen.dart';
import '../offers/offers_screen.dart';
import '../search/search_screen.dart';
import 'components/flash_deals.dart';
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
  HomeSort _sort = HomeSort.mix;
  int _refreshTick = 0;

  late Future<_Rows> _categoriesFuture;
  late Future<_Rows> _dealsFuture;
  _Rows _categories = const [];
  List<BannerSlide> _slides = const [];
  Color _heroColor = AppColors.brandSoft;

  bool _collapsed = false;
  bool _showTop = false;
  double _bannerHeight = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _loadSections();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted && _tab == _homeTab) maybeShowWelcomeCoupon(context);
      });
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  // --------------------------------------------------------------------------
  // البيانات

  void _loadSections() {
    _categoriesFuture = _fetch(() async => await supabase
        .from('categories_home')
        .select('id, name, image_url, total_sales')
        .order('id', ascending: true));
    _categoriesFuture.then((rows) {
      if (mounted) setState(() => _categories = rows);
    });

    _dealsFuture = _fetch(() async => await supabase
        .from('products_ranked')
        .select(kRankedColumns)
        .eq('is_offer', true)
        .gt('stock', 0)
        .order('offer_ends_at', ascending: true, nullsFirst: false)
        .order('sales_count', ascending: false, nullsFirst: false)
        .limit(12));

    _fetch(() async => await supabase
        .from('active_banners')
        .select()
        .order('sort_order', ascending: true)
        .order('id', ascending: true)).then((rows) {
      if (!mounted) return;
      setState(() {
        _slides = slidesFromRows(rows);
        if (_slides.isEmpty) _heroColor = AppColors.surface;
      });
    });
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
    await Future.wait([_categoriesFuture, _dealsFuture]);
  }

  // --------------------------------------------------------------------------
  // التمرير والتنقل

  void _onScroll() {
    final offset = _scroll.offset;
    final collapsed = offset > _bannerHeight - 12;
    final showTop = offset > 1400;
    if (collapsed != _collapsed || showTop != _showTop) {
      setState(() {
        _collapsed = collapsed;
        _showTop = showTop;
      });
    }
  }

  void _scrollToGrid() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _gridAnchor.currentContext;
      if (ctx == null || !_scroll.hasClients) return;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null) return;
      final y = box.localToGlobal(Offset.zero).dy;
      final pinned = MediaQuery.paddingOf(context).top + _toolbarHeight;
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
      _collapsed = false;
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

  void _openProduct(Map<String, dynamic> product) =>
      _push(DetailsScreen(productId: (product['id'] as num).toInt()));

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
        final match = _categories.where((c) => (c['id'] as num).toInt() == id);
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
      floatingActionButton: _tab == _homeTab && _showTop
          ? FloatingActionButton.small(
              heroTag: 'home-top',
              tooltip: 'للأعلى',
              backgroundColor: AppColors.ink.withValues(alpha: 0.88),
              foregroundColor: Colors.white,
              elevation: 2,
              shape: const CircleBorder(),
              onPressed: _scrollToTop,
              child: const Icon(Icons.arrow_upward_rounded),
            )
          : null,
      bottomNavigationBar: _BottomNav(selected: _tab, onSelected: _onTabSelected),
    );
  }

  Widget _buildHome(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final topPadding = MediaQuery.paddingOf(context).top;
    _bannerHeight = _slides.isEmpty ? 0 : width / PromoCarousel.aspectRatio;

    final onHero = _slides.isNotEmpty && !_collapsed;
    final heroIsDark = ThemeData.estimateBrightnessForColor(_heroColor) == Brightness.dark;
    final overlay = (onHero && heroIsDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
        .copyWith(statusBarColor: Colors.transparent);

    return RefreshIndicator(
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
            expandedHeight: _toolbarHeight + _bannerHeight,
            titleSpacing: 12,
            backgroundColor: AppColors.surface,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0.5,
            systemOverlayStyle: overlay,
            title: _SearchField(onTap: () => _push(const SearchScreen()), onColor: onHero),
            flexibleSpace: _slides.isEmpty
                ? null
                : FlexibleSpaceBar(
                    collapseMode: CollapseMode.pin,
                    background: AnimatedContainer(
                      duration: const Duration(milliseconds: 450),
                      color: _heroColor,
                      alignment: Alignment.bottomCenter,
                      child: PromoCarousel(
                        slides: _slides,
                        onSlideTap: _onBannerTap,
                        onColorChanged: (c) {
                          if (mounted && c != _heroColor) setState(() => _heroColor = c);
                        },
                      ),
                    ),
                  ),
          ),
          const SliverToBoxAdapter(child: _TrustStrip()),
          SliverToBoxAdapter(child: _buildCategories(width)),
          SliverToBoxAdapter(
            child: FlashDealsSection(
              dealsFuture: _dealsFuture,
              onProductTap: _openProduct,
              onSeeAll: () => _push(const OffersScreen()),
            ),
          ),
          SliverToBoxAdapter(
            child: KeyedSubtree(
              key: _gridAnchor,
              child: _selectedCategoryId == 0
                  ? const SizedBox(height: 8)
                  : Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 8, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _selectedCategoryName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.ink),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => _selectCategory(0, ''),
                            icon: const Icon(Icons.close_rounded, size: 18),
                            label: const Text('كل الفئات'),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _SortTabsDelegate(sort: _sort, onChanged: _setSort),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 24),
            sliver: HomeProductGrid(
              key: ValueKey('home-grid-$_refreshTick'),
              categoryId: _selectedCategoryId,
              sort: _sort,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategories(double width) {
    return FutureBuilder<_Rows>(
      future: _categoriesFuture,
      builder: (context, snapshot) {
        final rows = snapshot.data;
        if (rows != null && rows.isEmpty) return const SizedBox(height: 4);

        var hotId = -1;
        num hotSales = 0;
        for (final c in rows ?? const <Map<String, dynamic>>[]) {
          final s = (c['total_sales'] as num?) ?? 0;
          if (s > hotSales) {
            hotSales = s;
            hotId = (c['id'] as num).toInt();
          }
        }

        final items = <Widget>[
          if (rows == null)
            for (var i = 0; i < 6; i++) const _CategoryBubble.loading()
          else ...[
            _CategoryBubble(
              name: 'الكل',
              icon: Icons.apps_rounded,
              selected: _selectedCategoryId == 0,
              onTap: () => _selectCategory(0, ''),
            ),
            for (final c in rows)
              _CategoryBubble(
                name: (c['name'] ?? '').toString(),
                imageUrl: c['image_url']?.toString(),
                hot: (c['id'] as num).toInt() == hotId,
                selected: _selectedCategoryId == (c['id'] as num).toInt(),
                onTap: () => _selectCategory((c['id'] as num).toInt(), (c['name'] ?? '').toString()),
              ),
          ],
        ];

        const itemHeight = 100.0;
        if (items.length > 8) {
          // فئات كثيرة: سطرين يتمررون بالعرض
          return SizedBox(
            height: itemHeight * 2 + 30,
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 4),
              scrollDirection: Axis.horizontal,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisExtent: 86,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
              ),
              itemCount: items.length,
              itemBuilder: (_, i) => items[i],
            ),
          );
        }

        final cols = items.length <= 6 ? 3 : 4;
        final itemWidth = (width - 24) / cols;
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
          child: GridView.count(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: cols,
            mainAxisSpacing: 6,
            childAspectRatio: itemWidth / itemHeight,
            children: items,
          ),
        );
      },
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
  const _SearchField({required this.onTap, required this.onColor});

  final VoidCallback onTap;
  final bool onColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: onColor ? Colors.white : AppColors.background,
      borderRadius: BorderRadius.circular(24),
      elevation: onColor ? 1 : 0,
      shadowColor: Colors.black26,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: const SizedBox(
          height: 44,
          child: Row(
            children: [
              SizedBox(width: 14),
              Icon(Icons.search_rounded, color: AppColors.ink),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'ابحث عن حجاب، شال، عطر...',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.muted, fontSize: 14, fontWeight: FontWeight.w400),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrustStrip extends StatelessWidget {
  const _TrustStrip();

  static const _items = [
    (Icons.verified_user_outlined, 'ضمان السعر', 'سعرنا مضمون'),
    (Icons.local_offer_outlined, 'خصومات', 'على منتجات مختارة'),
    (Icons.assignment_return_outlined, 'إرجاع سهل', 'لأي سبب كان'),
    (Icons.local_shipping_outlined, 'توصيل سريع', 'خلال 48 ساعة'),
  ];

  @override
  Widget build(BuildContext context) {
    Widget tile((IconData, String, String) item) => Expanded(
          child: Container(
            height: 58,
            padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 10, 0),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0EE),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.$2,
                        maxLines: 1,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.sale, height: 1.2),
                      ),
                      Text(
                        item.$3,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: Color(0xFFB0443B), height: 1.3),
                      ),
                    ],
                  ),
                ),
                Icon(item.$1, color: AppColors.sale, size: 22),
              ],
            ),
          ),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Column(
        children: [
          Row(children: [tile(_items[0]), const SizedBox(width: 8), tile(_items[1])]),
          const SizedBox(height: 8),
          Row(children: [tile(_items[2]), const SizedBox(width: 8), tile(_items[3])]),
        ],
      ),
    );
  }
}

class _CategoryBubble extends StatelessWidget {
  const _CategoryBubble({
    required this.name,
    required this.selected,
    required this.onTap,
    this.imageUrl,
    this.icon,
    this.hot = false,
  }) : loading = false;

  const _CategoryBubble.loading()
      : name = '',
        selected = false,
        onTap = null,
        imageUrl = null,
        icon = null,
        hot = false,
        loading = true;

  final String name;
  final String? imageUrl;
  final IconData? icon;
  final bool selected;
  final bool hot;
  final bool loading;
  final VoidCallback? onTap;

  static const double _size = 70;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.trim().isNotEmpty;
    final fallback = ColoredBox(
      color: AppColors.brandSoft,
      child: Center(
        child: icon != null
            ? Icon(icon, color: AppColors.brandDark, size: 28)
            : Text(
                name.isEmpty ? '' : name.characters.first,
                style: const TextStyle(color: AppColors.brandDark, fontSize: 24, fontWeight: FontWeight.w800),
              ),
      ),
    );

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: _size,
                height: _size,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(
                    color: selected ? AppColors.brand : const Color(0xFFF1EDEA),
                    width: selected ? 2.5 : 1,
                  ),
                ),
                child: ClipOval(
                  child: loading
                      ? const ColoredBox(color: AppColors.placeholder)
                      : hasImage
                          ? Image.network(imageUrl!, fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback)
                          : fallback,
                ),
              ),
              if (hot)
                const PositionedDirectional(
                  top: -2,
                  start: -2,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: Padding(
                      padding: EdgeInsets.all(2),
                      child: Icon(Icons.local_fire_department_rounded, color: AppColors.sale, size: 20),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              color: selected ? AppColors.ink : const Color(0xFF3D3833),
            ),
          ),
        ],
      ),
    );
  }
}

class _SortTabsDelegate extends SliverPersistentHeaderDelegate {
  _SortTabsDelegate({required this.sort, required this.onChanged});

  final HomeSort sort;
  final ValueChanged<HomeSort> onChanged;

  static const double _height = 54;

  static const _tabs = [
    (HomeSort.mix, 'قطع قد تعجبك', Icons.auto_awesome_rounded, Color(0xFFF2A91D)),
    (HomeSort.bestSelling, 'الأكثر مبيعاً', Icons.emoji_events_rounded, Color(0xFFF2A91D)),
    (HomeSort.newest, 'وصل حديثاً', Icons.fiber_new_rounded, AppColors.brand),
  ];

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      height: _height,
      color: const Color(0xFFFFF6F0),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          for (final t in _tabs)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(t.$1),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: t.$1 == sort ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: t.$1 == sort ? AppColors.line : Colors.transparent),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(t.$3, size: 17, color: t.$4),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          t.$2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: t.$1 == sort ? FontWeight.w800 : FontWeight.w500,
                            color: t.$1 == sort ? AppColors.ink : AppColors.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_SortTabsDelegate oldDelegate) => oldDelegate.sort != sort;
}
