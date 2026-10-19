import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/offline_cache.dart';
import '../../../core/product_options.dart';
import '../../../main.dart';
import '../../../services/recently_viewed.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/modo_product_card.dart';
import '../../clips/video_clip_player.dart';
import '../../details/details_screen.dart';
import '../product_list_screen.dart';
import 'home_product_grid.dart';

// أقسام الواجهة الرئيسية (1.7.7): شريط الثقة، الستوريات، تسوّقي حسب السعر،
// الأكثر طلباً، اطلالة اليوم، شفتيها مؤخراً. كل قسم يختفي بهدوء إذا ماكو بيانات.

typedef _Rows = List<Map<String, dynamic>>;

/// رقم قسم الجملة (نفس الي بالسيرفر: private.products_auto_wholesale)
const int kWholesaleCategoryId = 12;

void _openProduct(BuildContext context, int id) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => DetailsScreen(productId: id)));

Widget _sectionTitle(String title, {IconData? icon, Color? iconColor, VoidCallback? onSeeAll}) {
  return Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 4, 8),
    child: Row(
      children: [
        Flexible(
          child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink)),
        ),
        if (icon != null) ...[const SizedBox(width: 4), Icon(icon, color: iconColor ?? AppColors.brand, size: 21)],
        const Spacer(),
        if (onSeeAll != null)
          TextButton(
            onPressed: onSeeAll,
            child: const Text('الكل', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
      ],
    ),
  );
}

// ============================================================================
// 1) شريط ثقة صغير (بدل المربعات الأربعة)

class TrustTicker extends StatelessWidget {
  const TrustTicker({super.key});

  static const _items = [
    (Icons.local_shipping_outlined, 'توصيل خلال 48 ساعة'),
    (Icons.payments_outlined, 'الدفع عند الاستلام'),
    (Icons.assignment_return_outlined, 'إرجاع سهل'),
    (Icons.verified_user_outlined, 'ضمان السعر'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      color: AppColors.ink,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: _items.length,
        separatorBuilder: (_, _) => const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: Center(child: Text('•', style: TextStyle(color: Colors.white38))),
        ),
        itemBuilder: (_, i) => Row(
          children: [
            Icon(_items[i].$1, color: AppColors.brand, size: 16),
            const SizedBox(width: 5),
            Text(_items[i].$2, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 2) ستوريات: كل مقطع دائرة، والي انشافت تصير رمادية وتروح للأخير

class StoriesBar extends StatefulWidget {
  const StoriesBar({super.key});

  @override
  State<StoriesBar> createState() => _StoriesBarState();
}

class _StoriesBarState extends State<StoriesBar> {
  static const String _seenKey = 'stories_seen_v1';
  _Rows? _clips;
  Set<String> _seen = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _seen = (prefs.getStringList(_seenKey) ?? const []).toSet();
    } catch (_) {}
    try {
      final rows = await OfflineCache.fetch(
        'home_stories',
        () async => await supabase
            .from('clips')
            .select('id, video_url, product_id, products(name, image_url, stock)')
            .order('created_at', ascending: false)
            .limit(30),
        onFresh: (fresh) {
          if (mounted) setState(() => _clips = _usable(fresh));
        },
      );
      if (mounted) setState(() => _clips = _usable(rows));
    } catch (e) {
      debugPrint('Stories error: $e');
      if (mounted) setState(() => _clips = const []);
    }
  }

  /// بس المقاطع الي منتجها متوفر، وما نكرر نفس المنتج
  static _Rows _usable(_Rows rows) {
    final seenProducts = <int>{};
    return rows.where((c) {
      final p = c['products'];
      final pid = (c['product_id'] as num?)?.toInt();
      if (p is! Map || pid == null || ((p['stock'] as num?) ?? 0) <= 0) return false;
      return seenProducts.add(pid);
    }).toList();
  }

  bool _isSeen(Map<String, dynamic> c) => _seen.contains('${c['id']}');

  Future<void> _open(_Rows ordered, int index) async {
    setState(() => _seen.add('${ordered[index]['id']}'));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_seenKey, _seen.take(300).toList());
    } catch (_) {}
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => StoryClipsScreen(clips: ordered, initialIndex: index),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final clips = _clips;
    if (clips != null && clips.isEmpty) return const SizedBox.shrink();
    final ordered = clips == null ? const <Map<String, dynamic>>[] : [...clips.where((c) => !_isSeen(c)), ...clips.where(_isSeen)];

    return Container(
      color: AppColors.surface,
      height: 108,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
        scrollDirection: Axis.horizontal,
        itemCount: clips == null ? 5 : ordered.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          if (clips == null) return const _StoryBubble.loading();
          final c = ordered[i];
          final p = c['products'] as Map;
          final images = ((p['image_url'] as List?) ?? const []).map((e) => '$e').where((e) => e.isNotEmpty);
          return _StoryBubble(
            imageUrl: images.isEmpty ? null : images.first,
            label: (p['name'] ?? '').toString().trim(),
            seen: _isSeen(c),
            onTap: () => _open(ordered, i),
          );
        },
      ),
    );
  }
}

class _StoryBubble extends StatelessWidget {
  const _StoryBubble({required this.imageUrl, required this.label, required this.seen, required VoidCallback this.onTap})
      : loading = false;

  const _StoryBubble.loading()
      : imageUrl = null,
        label = '',
        seen = true,
        onTap = null,
        loading = true;

  final String? imageUrl;
  final String label;
  final bool seen;
  final bool loading;
  final VoidCallback? onTap;

  static const double _size = 66;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: _size + 6,
        child: Column(
          children: [
            Container(
              width: _size,
              height: _size,
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: seen
                    ? null
                    : const SweepGradient(colors: [AppColors.brand, Color(0xFFFFB347), AppColors.brandDark, AppColors.brand]),
                color: seen ? AppColors.line : null,
              ),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: ClipOval(
                  child: loading
                      ? const ColoredBox(color: AppColors.placeholder)
                      : Stack(
                          fit: StackFit.expand,
                          children: [
                            ProductImage(url: imageUrl),
                            const Center(
                              child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28, shadows: [Shadow(blurRadius: 6)]),
                            ),
                          ],
                        ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, fontWeight: seen ? FontWeight.w500 : FontWeight.w700, color: AppColors.ink),
            ),
          ],
        ),
      ),
    );
  }
}

/// المقاطع بشاشة كاملة، تبدي من الستوري الي انضغطت
class StoryClipsScreen extends StatefulWidget {
  const StoryClipsScreen({super.key, required this.clips, required this.initialIndex});

  final List<Map<String, dynamic>> clips;
  final int initialIndex;

  @override
  State<StoryClipsScreen> createState() => _StoryClipsScreenState();
}

class _StoryClipsScreenState extends State<StoryClipsScreen> {
  late final PageController _page = PageController(initialPage: widget.initialIndex);

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _page,
            scrollDirection: Axis.vertical,
            itemCount: widget.clips.length,
            itemBuilder: (_, i) {
              final c = widget.clips[i];
              return VideoClipPlayer(
                key: ValueKey(c['video_url']),
                videoUrl: '${c['video_url']}',
                productId: (c['product_id'] as num).toInt(),
              );
            },
          ),
          PositionedDirectional(
            top: MediaQuery.paddingOf(context).top + 8,
            start: 8,
            child: IconButton.filled(
              style: IconButton.styleFrom(backgroundColor: Colors.black45),
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              tooltip: 'إغلاق',
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 4) تسوّقي حسب السعر

class PriceBuckets extends StatelessWidget {
  const PriceBuckets({super.key});

  @override
  Widget build(BuildContext context) {
    void open(Widget s) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => s));
    final tiles = [
      ('تحت', '5,000', 'د.ع', const Color(0xFFFFEEE6), const Color(0xFFC24A12),
          () => open(const ProductListScreen(title: 'تحت 5,000 د.ع', maxPrice: 5000))),
      ('تحت', '10,000', 'د.ع', const Color(0xFFFFF4D9), const Color(0xFF8A5A00),
          () => open(const ProductListScreen(title: 'تحت 10,000 د.ع', maxPrice: 10000))),
      ('عروض', 'قطعتين', 'وفّري أكثر', const Color(0xFFE8F5EC), const Color(0xFF1E7B3A),
          () => open(const ProductListScreen(title: 'عروض الكمية', onlyBulk: true))),
      ('قسم', 'الجملة', 'أقل طلب 6', const Color(0xFFEEE9FB), const Color(0xFF5B3FB0),
          () => open(const ProductListScreen(title: 'الجملة', categoryId: kWholesaleCategoryId, sort: HomeSort.newest))),
    ];
    return Container(
      color: AppColors.surface,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.only(top: 14, bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle('تسوّقي حسب السعر'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                for (var i = 0; i < tiles.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: Material(
                      color: tiles[i].$4,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: tiles[i].$6,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                          child: Column(
                            children: [
                              Text(tiles[i].$1, style: TextStyle(color: tiles[i].$5, fontSize: 13, fontWeight: FontWeight.w700)),
                              FittedBox(
                                child: Text(tiles[i].$2,
                                    style: TextStyle(color: tiles[i].$5, fontSize: 16, fontWeight: FontWeight.w800)),
                              ),
                              Text(tiles[i].$3,
                                  maxLines: 1,
                                  style: TextStyle(color: tiles[i].$5.withValues(alpha: 0.75), fontSize: 10.5, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 5) الأكثر طلباً هالشهر (أرقام حقيقية من الطلبات)

class TopProductsSection extends StatefulWidget {
  const TopProductsSection({super.key});

  @override
  State<TopProductsSection> createState() => _TopProductsSectionState();
}

class _TopProductsSectionState extends State<TopProductsSection> {
  _Rows? _rows;

  @override
  void initState() {
    super.initState();
    _load();
  }

  static Future<_Rows> _fetch() async {
    final ranks = (await supabase.rpc('top_products', params: {'p_days': 30, 'p_limit': 5}) as List)
        .cast<Map<String, dynamic>>();
    if (ranks.isEmpty) return const [];
    final ids = ranks.map((r) => (r['product_id'] as num).toInt()).toList();
    final products = (await supabase.from('products_ranked').select(kRankedColumns).inFilter('id', ids))
        .cast<Map<String, dynamic>>();
    final byId = {for (final p in products) (p['id'] as num).toInt(): p};
    return [
      for (final r in ranks)
        if (byId[(r['product_id'] as num).toInt()] case final p?) {...p, 'orders_count': r['orders_count']},
    ];
  }

  Future<void> _load() async {
    try {
      final rows = await OfflineCache.fetch('home_top', _fetch, onFresh: (fresh) {
        if (mounted) setState(() => _rows = fresh);
      });
      if (mounted) setState(() => _rows = rows);
    } catch (e) {
      debugPrint('Top products error: $e');
      if (mounted) setState(() => _rows = const []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    if (rows == null || rows.isEmpty) return const SizedBox.shrink();
    return Container(
      color: AppColors.surface,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle(
            'الأكثر طلباً هالشهر',
            icon: Icons.local_fire_department_rounded,
            iconColor: AppColors.sale,
            onSeeAll: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const ProductListScreen(title: 'الأكثر مبيعاً'),
            )),
          ),
          for (var i = 0; i < rows.length; i++) _TopRow(rank: i + 1, product: rows[i], last: i == rows.length - 1),
        ],
      ),
    );
  }
}

class _TopRow extends StatelessWidget {
  const _TopRow({required this.rank, required this.product, required this.last});

  final int rank;
  final Map<String, dynamic> product;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final images = imagesOf(product);
    final orders = (product['orders_count'] as num?)?.toInt() ?? 0;
    return InkWell(
      onTap: () => _openProduct(context, (product['id'] as num).toInt()),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: last ? null : const Border(bottom: BorderSide(color: AppColors.line)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text(
                '$rank',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: rank <= 3 ? const Color(0xFFFF9A66) : AppColors.line,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(width: 62, height: 62, child: ProductImage(url: images.isEmpty ? null : images.first)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (product['name'] ?? '').toString().trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, height: 1.35),
                  ),
                  if (orders >= 3)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        'بـ $orders طلب هالشهر',
                        style: const TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w700),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              kMoney.format(priceOf(product)),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.brandDark),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 6) اطلالة اليوم: صورة وعليها نقاط، كل نقطة تفتح القطعة

class LookOfTheDay extends StatefulWidget {
  const LookOfTheDay({super.key});

  @override
  State<LookOfTheDay> createState() => _LookOfTheDayState();
}

class _LookOfTheDayState extends State<LookOfTheDay> {
  Map<String, dynamic>? _look;
  Map<int, Map<String, dynamic>> _products = const {};
  int? _openSpot;

  @override
  void initState() {
    super.initState();
    _load();
  }

  static Future<_Rows> _fetch() async {
    final looks = (await supabase
            .from('looks')
            .select('id, title, image_url, hotspots')
            .order('sort_order', ascending: true)
            .order('created_at', ascending: false)
            .limit(1))
        .cast<Map<String, dynamic>>();
    if (looks.isEmpty) return const [];
    final look = looks.first;
    final ids = _spots(look).map((s) => s.$3).toSet().toList();
    final products = ids.isEmpty
        ? const <Map<String, dynamic>>[]
        : (await supabase.from('products').select('id, name, price, old_price, image_url, stock').inFilter('id', ids))
            .cast<Map<String, dynamic>>();
    return [
      {...look, 'products': products},
    ];
  }

  static List<(double, double, int)> _spots(Map<String, dynamic> look) {
    final raw = (look['hotspots'] as List?) ?? const [];
    return [
      for (final h in raw)
        if (h is Map && h['product_id'] != null)
          (
            ((h['x'] as num?)?.toDouble() ?? 0.5).clamp(0.04, 0.96),
            ((h['y'] as num?)?.toDouble() ?? 0.5).clamp(0.04, 0.96),
            (h['product_id'] as num).toInt(),
          ),
    ];
  }

  void _apply(_Rows rows) {
    if (!mounted) return;
    setState(() {
      _look = rows.isEmpty ? null : rows.first;
      final ps = ((_look?['products'] as List?) ?? const []).cast<Map<String, dynamic>>();
      _products = {
        for (final p in ps)
          if (((p['stock'] as num?) ?? 0) > 0) (p['id'] as num).toInt(): p,
      };
    });
  }

  Future<void> _load() async {
    try {
      _apply(await OfflineCache.fetch('home_look', _fetch, onFresh: _apply));
    } catch (e) {
      debugPrint('Look error: $e');
    }
  }

  void _shopAll(List<Map<String, dynamic>> items) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (sheet) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            const Text('قطع الاطلالة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            for (final p in items)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 54,
                    height: 54,
                    child: ProductImage(url: imagesOf(p).isEmpty ? null : imagesOf(p).first),
                  ),
                ),
                title: Text((p['name'] ?? '').toString(), maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: PriceLine(product: p, big: false),
                trailing: const Icon(Icons.chevron_left_rounded),
                onTap: () {
                  Navigator.of(sheet).pop();
                  _openProduct(context, (p['id'] as num).toInt());
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final look = _look;
    if (look == null) return const SizedBox.shrink();
    final spots = _spots(look).where((s) => _products.containsKey(s.$3)).toList();
    if (spots.isEmpty) return const SizedBox.shrink();
    final items = {for (final s in spots) s.$3: _products[s.$3]!}.values.toList();

    return Container(
      color: AppColors.surface,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.only(top: 14, bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle((look['title'] ?? 'اطلالة اليوم').toString(), icon: Icons.auto_awesome_rounded, iconColor: AppColors.star),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 4 / 5,
                child: LayoutBuilder(
                  builder: (context, box) => Stack(
                    children: [
                      Positioned.fill(
                        child: GestureDetector(
                          onTap: () => setState(() => _openSpot = null),
                          child: ProductImage(url: '${look['image_url']}'),
                        ),
                      ),
                      for (var i = 0; i < spots.length; i++)
                        _Hotspot(
                          // x محسوبة من اليسار مثل ما تنحط بصفحة الإدارة
                          left: spots[i].$1 * box.maxWidth,
                          top: spots[i].$2 * box.maxHeight,
                          maxWidth: box.maxWidth,
                          product: _products[spots[i].$3]!,
                          open: _openSpot == i,
                          onToggle: () => setState(() => _openSpot = _openSpot == i ? null : i),
                          onOpenProduct: () => _openProduct(context, spots[i].$3),
                        ),
                      PositionedDirectional(
                        bottom: 12,
                        end: 12,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.ink,
                            shape: const StadiumBorder(),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          onPressed: () => _shopAll(items),
                          icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                          label: Text(items.length > 1 ? 'تسوّقي الاطلالة (${pieces(items.length)})' : 'تسوّقي القطعة'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Hotspot extends StatelessWidget {
  const _Hotspot({
    required this.left,
    required this.top,
    required this.maxWidth,
    required this.product,
    required this.open,
    required this.onToggle,
    required this.onOpenProduct,
  });

  final double left;
  final double top;
  final double maxWidth;
  final Map<String, dynamic> product;
  final bool open;
  final VoidCallback onToggle;
  final VoidCallback onOpenProduct;

  static const double _dot = 26;
  static const double _tagWidth = 150;

  @override
  Widget build(BuildContext context) {
    // البطاقة تطلع جهة الوسط حتى ما تطلع برا الصورة
    final tagOnRight = left < maxWidth / 2;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: left - _dot / 2,
          top: top - _dot / 2,
          child: GestureDetector(
            onTap: onToggle,
            child: Container(
              width: _dot,
              height: _dot,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.5),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
              ),
              alignment: Alignment.center,
              child: Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              ),
            ),
          ),
        ),
        if (open)
          Positioned(
            left: tagOnRight ? left + _dot / 2 + 4 : null,
            right: tagOnRight ? null : maxWidth - left + _dot / 2 + 4,
            top: top - 22,
            child: GestureDetector(
              onTap: onOpenProduct,
              child: Container(
                width: _tagWidth,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 3))],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            (product['name'] ?? '').toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                          Text(
                            '${kMoney.format(priceOf(product))} د.ع',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.brandDark),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_left_rounded, size: 18),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ============================================================================
// 7) شفتيها مؤخراً (محفوظة على الجهاز بس)

class RecentlyViewedRow extends StatefulWidget {
  const RecentlyViewedRow({super.key});

  @override
  State<RecentlyViewedRow> createState() => _RecentlyViewedRowState();
}

class _RecentlyViewedRowState extends State<RecentlyViewedRow> {
  _Rows _rows = const [];
  List<int> _loadedFor = const [];

  @override
  void initState() {
    super.initState();
    RecentlyViewed.instance.ids.addListener(_reload);
    RecentlyViewed.instance.load().then((_) => _reload());
  }

  @override
  void dispose() {
    RecentlyViewed.instance.ids.removeListener(_reload);
    super.dispose();
  }

  Future<void> _reload() async {
    final ids = RecentlyViewed.instance.ids.value;
    if (ids.isEmpty || _sameIds(ids, _loadedFor)) return;
    _loadedFor = ids;
    try {
      final rows = (await supabase
              .from('products')
              .select('id, name, price, old_price, image_url, stock')
              .inFilter('id', ids)
              .gt('stock', 0))
          .cast<Map<String, dynamic>>();
      final byId = {for (final p in rows) (p['id'] as num).toInt(): p};
      if (!mounted) return;
      setState(() => _rows = [for (final id in ids) if (byId[id] case final p?) p]);
    } catch (e) {
      debugPrint('Recently viewed error: $e');
    }
  }

  static bool _sameIds(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (_rows.length < 2) return const SizedBox.shrink();
    return Container(
      color: AppColors.surface,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.only(top: 14, bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle('شفتيها مؤخراً', icon: Icons.history_rounded, iconColor: AppColors.muted),
          SizedBox(
            height: 140,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              itemCount: _rows.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final p = _rows[i];
                final images = imagesOf(p);
                return GestureDetector(
                  onTap: () => _openProduct(context, (p['id'] as num).toInt()),
                  child: SizedBox(
                    width: 92,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(width: 92, height: 110, child: ProductImage(url: images.isEmpty ? null : images.first)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${kMoney.format(priceOf(p))} د.ع',
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.brandDark),
                        ),
                      ],
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
