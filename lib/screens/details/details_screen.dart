import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show NumberFormat;

import '../../core/bulk_pricing.dart';
import '../../core/offline_cache.dart';
import '../../core/product_options.dart';
import '../../core/shop_api.dart';
import '../../facebook_service.dart';
import '../../main.dart';
import '../../services/cart_service.dart';
import '../../services/recently_viewed.dart';
import '../../services/visit_logger.dart';
import '../../theme/app_theme.dart';
import '../../widgets/modo_product_card.dart' show WishHeart, optionsCountLabel;
import '../cart/cart_screen.dart';
import '../chat/chat_screen.dart';

const Color _kPink = Color(0xFFC2185B);
const Color _kGreen = Color(0xFF2E7D32);
const Color _kHintText = Color(0xFFB4501A);
const Color _kHintBg = Color(0xFFFFF4EC);

class DetailsScreen extends StatefulWidget {
  final int productId;

  /// من وين انفتح المنتج (لشجرة الإعلانات): 'app' أو 'meta' أو 'deeplink'.
  final String source;
  final String? campaign;

  const DetailsScreen({super.key, required this.productId, this.source = 'app', this.campaign});

  @override
  State<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> {
  final PageController _pageController = PageController();
  final NumberFormat _money = NumberFormat('#,###');
  late Future<Map<String, dynamic>> _productFuture;
  String _categoryName = '';

  int _currentPage = 0;

  /// العدد الكلي للقطع (كل الألوان)
  int? _qty;

  /// "مكس ألوان": إحنا نوزّع القطع على الألوان
  bool _mix = false;

  /// "أختار ألواني": كم قطعة من كل لون (بترتيب الاختيار)
  final Map<String, int> _counts = {};
  bool _showAllColors = false;
  bool _colorMissing = false;
  bool _adding = false;

  static const int _colorsPreview = 18;

  @override
  void initState() {
    super.initState();
    _productFuture = _fetchProductDetails();
    VisitLogger.productOpened(widget.productId, source: widget.source, campaign: widget.campaign);
    RecentlyViewed.instance.add(widget.productId);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// يفتح فوراً من آخر نسخة محفوظة بالجهاز (إذا الزبون فتح المنتج قبل)، ويتحدث من السيرفر بالخلفية.
  Future<Map<String, dynamic>> _fetchProductDetails() async {
    final rows = await OfflineCache.fetch(
      'product_${widget.productId}',
      () async => [
        await supabase.from('products').select(kProductColumns).eq('id', widget.productId).single(),
      ],
      onFresh: (fresh) {
        if (mounted) setState(() => _productFuture = Future.value(fresh.first));
      },
    );
    final data = rows.first;
    _loadCategoryName((data['category_id'] as num?)?.toInt());
    FacebookAnalyticsService.logViewContent(id: '${widget.productId}', price: _price(data));
    return data;
  }

  Future<void> _loadCategoryName(int? id) async {
    if (id == null || _categoryName.isNotEmpty) return;
    try {
      final rows = await OfflineCache.fetch(
        'category_name_$id',
        () async => [await supabase.from('categories').select('name').eq('id', id).single()],
      );
      final name = (rows.first['name'] ?? '').toString();
      if (mounted && name.isNotEmpty) setState(() => _categoryName = name);
    } catch (_) {}
  }

  static double _price(Map<String, dynamic> p) => (p['price'] as num?)?.toDouble() ?? 0;
  static double _oldPrice(Map<String, dynamic> p) => (p['old_price'] as num?)?.toDouble() ?? 0;
  static int _stock(Map<String, dynamic> p) => (p['stock'] as num?)?.toInt() ?? 0;
  static List<String> _images(Map<String, dynamic> p) =>
      ((p['image_url'] as List?) ?? const []).map((e) => '$e').where((e) => e.isNotEmpty).toList();

  int _minQty(Map<String, dynamic> p) => minQtyOf(p) ?? 1;

  /// "أختار ألواني": العدد من كل لون، مو من العداد الكلي
  bool _pickMode(Map<String, dynamic> p) => optionsOf(p).isNotEmpty && !_mix;

  int get _pickedTotal => _counts.values.fold(0, (s, n) => s + n);

  /// أكثر عدد بالعداد الكلي (مكس أو منتج بلا ألوان): المخزون، وسطر السلة حدّه maxQuantityPerLine
  int _maxQty(Map<String, dynamic> p) => math.min(_stock(p), CartService.maxQuantityPerLine);

  /// "أختار ألواني": مجموع قطع الألوان (وقبل الاختيار أقل كمية، حتى يبين السعر)
  int _qtyOf(Map<String, dynamic> p) {
    if (_pickMode(p)) return _pickedTotal > 0 ? _pickedTotal : _minQty(p);
    return _qty ?? _minQty(p);
  }

  void _setQty(Map<String, dynamic> p, int q) {
    final lo = _minQty(p);
    setState(() => _qty = q.clamp(math.min(lo, _maxQty(p)), math.max(_maxQty(p), 1)));
  }

  /// القطع حسب اللون: مكس = سطر واحد "مكس ألوان"، وإلا كل لون بعدده
  Map<String, int> _distribution(Map<String, dynamic> p) {
    if (optionsOf(p).isEmpty) return const {};
    // مكس: سطر واحد "مكس ألوان" وإنتو تختارون الألوان عند التجهيز
    if (_mix) {
      final qty = _qtyOf(p);
      return qty <= 0 ? const {} : {kMixColor: qty};
    }
    return Map.of(_counts);
  }

  /// يگدر يزيد قطعة من هذا اللون: سطر السلة حدّه maxQuantityPerLine، والمجموع ما يعدّي المخزون
  bool _canAddPiece(Map<String, dynamic> p, String color) =>
      (_counts[color] ?? 0) < CartService.maxQuantityPerLine && _pickedTotal < _stock(p);

  /// يزيد أو ينقص قطعة من لون؛ من يوصل صفر ينشال اللون
  void _changeCount(Map<String, dynamic> p, String color, int delta) {
    if (delta > 0 && !_canAddPiece(p, color)) return;
    setState(() {
      _colorMissing = false;
      final n = (_counts[color] ?? 0) + delta;
      if (n <= 0) {
        _counts.remove(color);
      } else {
        _counts[color] = n;
      }
    });
  }

  /// يرجع true إذا انضاف للسلة
  Future<bool> _addToCart(Map<String, dynamic> product) async {
    final messenger = ScaffoldMessenger.of(context);
    if (_stock(product) <= 0) {
      messenger.showSnackBar(const SnackBar(content: Text('هذا المنتج نفد حالياً')));
      return false;
    }
    final colors = optionsOf(product);
    final qty = _qtyOf(product);
    if (_pickMode(product) && _counts.isEmpty) {
      setState(() => _colorMissing = true);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('اختاري ${optionTitle(colors)} أولاً، أو اختاري "مكس ألوان"'),
          backgroundColor: AppColors.sale,
        ));
      return false;
    }
    // منتجات بحد أدنى: مجموع قطع الألوان لازم يوصله (السيرفر يتحقق بعد)
    final minQty = _minQty(product);
    if (_pickMode(product) && _pickedTotal < minQty) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('أقل طلب لهذا المنتج ${pieces(minQty)}، باقي ${pieces(minQty - _pickedTotal)}'),
          backgroundColor: AppColors.sale,
        ));
      return false;
    }

    setState(() => _adding = true);
    try {
      if (colors.isEmpty) {
        await CartService.instance.add(widget.productId, quantity: qty);
      } else {
        for (final e in _distribution(product).entries) {
          await CartService.instance.add(widget.productId, color: e.key, quantity: e.value);
        }
      }
      FacebookAnalyticsService.logAddToCart(id: '${widget.productId}', price: quoteProduct(product, qty, mixQty: _mix ? qty : 0).total);
      return true;
    } catch (e) {
      messenger.showSnackBar(const SnackBar(
        content: Text('تعذر حفظ السلة، حاول مرة ثانية'),
        backgroundColor: AppColors.sale,
      ));
      return false;
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _onAddToCart(Map<String, dynamic> product) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final qty = _qtyOf(product);
    if (!await _addToCart(product) || !mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('انضافت ${pieces(qty)} إلى السلة'),
        backgroundColor: _kGreen,
        persist: false,
        action: SnackBarAction(
          label: 'عرض السلة',
          textColor: Colors.white,
          onPressed: () => navigator.push(MaterialPageRoute(builder: (_) => const CartScreen())),
        ),
      ));
  }

  Future<void> _onBuyNow(Map<String, dynamic> product) async {
    final navigator = Navigator.of(context);
    if (!await _addToCart(product) || !mounted) return;
    navigator.push(MaterialPageRoute(builder: (_) => const CartScreen()));
  }

  void _share() {
    Clipboard.setData(ClipboardData(
      text: 'https://teaizteaiz46-blip.github.io/Modo-orders/p.html?id=${widget.productId}',
    ));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('تم نسخ رابط المنتج، تگدرين تدزينه لأي أحد')));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _productFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(backgroundColor: Colors.white, elevation: 0),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('تعذر تحميل المنتج، ربما لم يعد متوفراً.'),
                  TextButton(
                    onPressed: () => setState(() => _productFuture = _fetchProductDetails()),
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            ),
          );
        }

        final product = snapshot.data!;
        final images = _images(product);
        final name = (product['name'] ?? '').toString();
        final price = _price(product);
        final oldPrice = _oldPrice(product);
        final stock = _stock(product);
        final description = (product['description'] ?? '').toString().trim();
        final colors = optionsOf(product);
        final tiers = BulkTier.ofProduct(product);
        final unitTiers = usesUnitTiers(product) ? UnitTier.ofProduct(product) : const <UnitTier>[];
        final cells = unitTiers.isNotEmpty ? unitTierCells(price, unitTiers) : packTierCells(price, tiers);
        final mixCell = unitTiers.isNotEmpty && colors.isNotEmpty ? mixTierOf(price, unitTiers) : null;
        final qty = _qtyOf(product);
        final quote = quoteProduct(product, qty, mixQty: _mix ? qty : 0);
        final hint = stock > 0 ? nextBulkHintForProduct(product, qty) : null;
        final sales = (product['sales_count'] as num?)?.toInt() ?? 0;
        final rating = (product['rating'] as num?)?.toDouble() ?? 0;
        final optionsLabel = optionsCountLabel(colors);

        return Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildGallery(images),
                  if (images.length > 1) _buildThumbs(images),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_categoryName.isNotEmpty)
                          Text(_categoryName, style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
                        Text(
                          name,
                          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, height: 1.3, color: AppColors.ink),
                        ),
                        const SizedBox(height: 2),
                        Wrap(
                          spacing: 14,
                          children: [
                            if (sales > 0) _stat('🔥 ${_money.format(sales)} قطعة انطلبت'),
                            if (optionsLabel.isNotEmpty) _stat('🎨 $optionsLabel'),
                            if (rating > 0) _stat('⭐ ${rating.toStringAsFixed(1)}'),
                          ],
                        ),
                        if (cells.length > 1)
                          _TierBar(
                            cells: cells,
                            mixCell: mixCell,
                            mixMode: _mix,
                            qty: qty,
                            minQty: _minQty(product),
                            wholesale: isWholesale(product) || unitTiers.isNotEmpty,
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              children: [
                                Text(
                                  '${_money.format(price)} د.ع',
                                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.brand),
                                ),
                                if (oldPrice > price)
                                  Text(
                                    _money.format(oldPrice),
                                    style: const TextStyle(color: Color(0xFFAAAAAA), decoration: TextDecoration.lineThrough),
                                  ),
                              ],
                            ),
                          ),
                        if (colors.isNotEmpty && stock > 0) ...[
                          const SizedBox(height: 12),
                          _buildModeToggle(product),
                          if (!_mix) _buildColorPicker(product, colors),
                        ],
                        if (stock > 0) _buildTotal(product, qty, quote),
                        if (_hintText(product, hint, cells, mixCell, qty, quote).isNotEmpty)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(color: _kHintBg, borderRadius: BorderRadius.circular(12)),
                            child: Text(
                              _hintText(product, hint, cells, mixCell, qty, quote),
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: _kHintText),
                            ),
                          ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _ActionButton(
                                label: stock <= 0 ? 'نفد من المخزون' : 'اطلبي الآن',
                                filled: true,
                                busy: _adding,
                                onTap: stock <= 0 || _adding ? null : () => _onBuyNow(product),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _ActionButton(
                                label: '🛍️ أضيفي للسلة',
                                filled: false,
                                onTap: stock <= 0 || _adding ? null : () => _onAddToCart(product),
                              ),
                            ),
                          ],
                        ),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: TextButton.icon(
                            onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => ChatScreen(productId: widget.productId))),
                            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                            label: const Text('عندكم سؤال أو طلب كبير؟ راسلونا',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.fromLTRB(0, 4, 0, 22),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _TrustItem(emoji: '🚚', text: 'توصيل لكل العراق'),
                              _TrustItem(emoji: '💵', text: 'الدفع عند الاستلام'),
                              _TrustItem(emoji: '📸', text: 'ألوان حقيقية'),
                            ],
                          ),
                        ),
                        if (description.isNotEmpty) ...[
                          const Text('الوصف', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(description, style: const TextStyle(fontSize: 14, color: Color(0xFF555555), height: 1.6)),
                          const SizedBox(height: 24),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _stat(String t) => Text(t, style: const TextStyle(fontSize: 12, color: Color(0xFF666666)));

  /// التلميح يطلع بس إذا متوسط سعر القطعة بعد الإضافة أرخص من الحالي، أو ينفتح توصيل مجاني
  String _hintText(Map<String, dynamic> product, BulkHint? hint, List<(int, int?, double)> cells,
      (int, double)? mixCell, int qty, BulkQuote current) {
    if (_stock(product) <= 0 || qty <= 0) return '';
    // "أختار ألواني" بحد أدنى: كم باقي حتى يوصله
    final minQty = _minQty(product);
    if (_pickMode(product) && _pickedTotal > 0 && _pickedTotal < minQty) {
      return '📦 أقل طلب ${pieces(minQty)} – باقي ${pieces(minQty - _pickedTotal)}';
    }
    // مكس: كم باقي حتى يوصل سعر المكس
    if (_mix && mixCell != null && qty < mixCell.$1 && mixCell.$1 <= _stock(product)) {
      return '✨ ضيفي ${pieces(mixCell.$1 - qty)} وينزل سعر القطعة لـ ${_money.format(mixCell.$2)} (سعر المكس)';
    }
    if (hint == null) return '';
    final target = qty + hint.missing;
    final next = quoteProduct(product, target, mixQty: _mix ? target : 0);
    final per = (next.total / target).ceilToDouble();
    final add = 'ضيفي ${pieces(hint.missing)}';
    if (per < current.total / qty) {
      final isLast = cells.isNotEmpty && target >= cells.last.$1;
      final wholesale = isWholesale(product) || usesUnitTiers(product);
      return '✨ $add وينزل سعر القطعة لـ ${_money.format(per)}${isLast && wholesale ? ' (سعر الجملة)' : ''}';
    }
    if (next.freeDelivery && !current.freeDelivery) return '✨ $add وتاخذين توصيل مجاني';
    return '';
  }

  Widget _buildModeToggle(Map<String, dynamic> product) {
    Widget seg(String title, String sub, bool on, VoidCallback onTap) => Expanded(
          child: GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: on ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(11),
                boxShadow: on ? const [BoxShadow(color: Color(0x14000000), blurRadius: 4, offset: Offset(0, 1))] : null,
              ),
              child: Column(
                children: [
                  Text(title,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: on ? AppColors.ink : const Color(0xFF666666))),
                  Text(sub, style: const TextStyle(fontSize: 10.5, color: Color(0xFF888888))),
                ],
              ),
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: const Color(0xFFF6F3F1), borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          seg('أختار ألواني', 'أكتب أرقام الألوان', !_mix, () => setState(() => _mix = false)),
          seg('مكس ألوان 🎁', 'تشكيلة منوعة نختارها إلج', _mix, () {
            // المكس ياخذ نفس عدد القطع اللي اختارتها بالألوان
            final picked = _pickedTotal;
            setState(() {
              _mix = true;
              _colorMissing = false;
            });
            if (picked > 0) _setQty(product, picked);
          }),
        ],
      ),
    );
  }

  Widget _buildColorPicker(Map<String, dynamic> product, List<String> colors) {
    final shown = _showAllColors || colors.length <= _colorsPreview ? colors : colors.take(_colorsPreview).toList();
    final hidden = colors.length - shown.length;
    final title = optionTitle(colors);
    final each = switch (optionKindOf(colors)) {
      OptionKind.color => 'لون',
      OptionKind.size => 'قياس',
      _ => 'اختيار',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Row(
          children: [
            Text('اختاري ${title == 'اللون' ? 'الألوان' : title}',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _colorMissing ? AppColors.sale : AppColors.ink)),
            const Spacer(),
            Text('− و + لعدد كل $each',
                style: const TextStyle(fontSize: 12, color: AppColors.brand, fontWeight: FontWeight.w800)),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final c in shown)
              ColorCountChip(
                label: c,
                count: _counts[c] ?? 0,
                missing: _colorMissing,
                canAdd: _canAddPiece(product, c),
                onAdd: () => _changeCount(product, c, 1),
                onRemove: () => _changeCount(product, c, -1),
              ),
            if (hidden > 0)
              GestureDetector(
                onTap: () => setState(() => _showAllColors = true),
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(start: 6),
                  child: Text('+$hidden لون',
                      style: const TextStyle(fontSize: 12, color: AppColors.brand, fontWeight: FontWeight.w800)),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildTotal(Map<String, dynamic> product, int qty, BulkQuote quote) {
    final max = _maxQty(product);
    final lo = _minQty(product);
    final pick = _pickMode(product);
    Widget step(String t, bool enabled, Color color, VoidCallback onTap) => GestureDetector(
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(t,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: enabled ? color : const Color(0xFFCCCCCC))),
          ),
        );
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: const Color(0xFFFAFAFA), borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('المجموع · ${pieces(qty)}', style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
                Text.rich(
                  TextSpan(children: [
                    TextSpan(text: _money.format(quote.total)),
                    const TextSpan(text: ' د.ع', style: TextStyle(fontSize: 13)),
                  ]),
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.brand),
                ),
                if (quote.saving > 0)
                  Text('وفّرتي ${_money.format(quote.saving)} د.ع',
                      style: const TextStyle(fontSize: 12, color: _kGreen, fontWeight: FontWeight.w800)),
                if (quote.freeDelivery)
                  const Text('🚚 توصيل مجاني', style: TextStyle(fontSize: 12, color: _kGreen, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          // "أختار ألواني": العدد من كل لون فوك، وهنا بس المجموع
          if (pick && _pickedTotal > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: const Color(0xFFFFF1E8), borderRadius: BorderRadius.circular(10)),
              child: Text(pieces(_pickedTotal),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.brand)),
            )
          else if (!pick)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFEEEEEE)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  step('−', qty > lo, AppColors.ink, () => _setQty(product, qty - 1)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text('$qty', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  ),
                  step('+', qty < max, AppColors.brand, () => _setQty(product, qty + 1)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _circleButton(Widget child, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          child: child,
        ),
      );

  Widget _buildGallery(List<String> images) {
    return AspectRatio(
      aspectRatio: 390 / 400,
      child: Stack(
        children: [
          Positioned.fill(
            child: PageView.builder(
              controller: _pageController,
              itemCount: images.isEmpty ? 1 : images.length,
              onPageChanged: (value) => setState(() => _currentPage = value),
              itemBuilder: (context, index) {
                if (images.isEmpty) {
                  return Container(
                    color: AppColors.placeholder,
                    child: const Icon(Icons.hide_image_outlined, color: Colors.grey, size: 80),
                  );
                }
                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => FullScreenImageViewer(imageUrls: images, initialIndex: index)),
                  ),
                  child: Image(
                    image: cachedImage(
                      images[index],
                      decodeWidth: decodeWidthFor(context, MediaQuery.sizeOf(context).width, MediaQuery.sizeOf(context).width),
                    ),
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) => progress == null
                        ? child
                        : Container(color: AppColors.placeholder, child: const Center(child: CircularProgressIndicator())),
                    errorBuilder: (_, _, _) => Container(
                      color: AppColors.placeholder,
                      child: const Icon(Icons.broken_image, color: Colors.grey, size: 80),
                    ),
                  ),
                );
              },
            ),
          ),
          PositionedDirectional(
            top: 10,
            start: 12,
            child: _circleButton(
              const Icon(Icons.chevron_right_rounded, size: 24, color: AppColors.ink),
              () => Navigator.maybePop(context),
            ),
          ),
          PositionedDirectional(
            top: 10,
            end: 12,
            child: Row(
              children: [
                WishHeart(productId: widget.productId, size: 34),
                const SizedBox(width: 8),
                _circleButton(const Text('↗', style: TextStyle(fontSize: 16, color: AppColors.ink)), _share),
              ],
            ),
          ),
          if (images.length > 1)
            PositionedDirectional(
              bottom: 10,
              end: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(10)),
                child: Text(
                  '${_currentPage + 1} / ${images.length}',
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildThumbs(List<String> images) {
    return SizedBox(
      height: 68,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        itemCount: images.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final on = i == _currentPage;
          return GestureDetector(
            onTap: () => _pageController.animateToPage(i, duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: on ? Border.all(color: AppColors.brand, width: 2) : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(on ? 8 : 10),
                child: ProductThumb(url: images[i]),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// صورة مصغرة
class ProductThumb extends StatelessWidget {
  const ProductThumb({super.key, required this.url});

  final String url;

  @override
  Widget build(BuildContext context) => Image(
        image: cachedImage(url, decodeWidth: decodeWidthFor(context, 52, 52)),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const ColoredBox(color: AppColors.placeholder),
      );
}

/// شريط أسعار الكمية: سعر القطعة حسب العدد، والخانة الحالية بيضة
/// خانات عروض الباقات: (من، إلى، سعر القطعة)
List<(int, int?, double)> packTierCells(double unitPrice, List<BulkTier> tiers) {
  final usable = tiers.where((t) => (t.price / t.qty).ceilToDouble() < unitPrice || t.freeDelivery).toList();
  if (usable.isEmpty) return const [];
  final cells = <(int, int?, double)>[(1, usable.first.qty - 1, unitPrice)];
  for (var i = 0; i < usable.length; i++) {
    final t = usable[i];
    cells.add((t.qty, i + 1 < usable.length ? usable[i + 1].qty - 1 : null, (t.price / t.qty).ceilToDouble()));
  }
  return cells;
}

/// شريط أسعار الكمية: سعر القطعة حسب العدد، والخانة الحالية بيضة
class _TierBar extends StatelessWidget {
  const _TierBar({
    required this.cells,
    required this.mixCell,
    required this.mixMode,
    required this.qty,
    required this.minQty,
    required this.wholesale,
  });

  final List<(int, int?, double)> cells;
  final (int, double)? mixCell;
  final bool mixMode;
  final int qty;
  final int minQty;
  final bool wholesale;

  static final NumberFormat _money = NumberFormat('#,###');

  static String _range(int a, int b) {
    if (a == b) return pieces(a);
    final unit = b <= 2 ? 'قطعة' : (b <= 10 ? 'قطع' : 'قطعة');
    return '$a-$b $unit';
  }

  @override
  Widget build(BuildContext context) {
    // منتجات بحد أدنى: الخانات الأقل منه ما تنعرض
    final shown = <(int, int?, double, String)>[];
    for (final c in cells) {
      if (c.$2 != null && c.$2! < minQty) continue;
      final from = c.$1 < minQty ? minQty : c.$1;
      shown.add((from, c.$2, c.$3, c.$2 == null ? '$from+ ${wholesale ? 'قطع' : 'قطعة'}' : _range(from, c.$2!)));
    }
    final mix = mixCell;
    final mixActive = mixMode && mix != null && qty >= mix.$1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const Text('✨ أسعار الكمية – كل ما تزيدين ينزل السعر',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: _kPink)),
        Container(
          margin: const EdgeInsets.only(top: 6),
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFFF8A3D), AppColors.brand]),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              for (final c in [
                ...shown.map((c) => (c.$1, c.$2, c.$3, c.$4, false)),
                if (mix != null) (mix.$1, null, mix.$2, 'مكس ${mix.$1}+', true),
              ])
                Expanded(
                  child: Builder(builder: (context) {
                    final isMixCell = c.$5;
                    final on = isMixCell ? mixActive : !mixActive && qty >= c.$1 && (c.$2 == null || qty <= c.$2!);
                    final label = c.$4;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                      decoration: BoxDecoration(
                        color: on ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: on ? const [BoxShadow(color: Color(0x26000000), blurRadius: 8, offset: Offset(0, 2))] : null,
                      ),
                      child: Column(
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(_money.format(c.$3),
                                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: on ? AppColors.brand : Colors.white)),
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(label,
                                style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: on ? AppColors.brand : Colors.white.withValues(alpha: 0.9))),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text('سعر القطعة بالدينار – ينحسب تلقائياً حسب العدد',
              style: TextStyle(fontSize: 11, color: Color(0xFF888888))),
        ),
      ],
    );
  }
}

/// خانة لون بصفحة المنتج: دوسة = قطعة وحدة، وبعدها − و + جنب اللون.
/// بالعدد 1 الـ − يصير سلة مهملات ويشيل اللون.
class ColorCountChip extends StatelessWidget {
  const ColorCountChip({
    super.key,
    required this.label,
    required this.count,
    required this.canAdd,
    required this.onAdd,
    required this.onRemove,
    this.missing = false,
  });

  final String label;
  final int count;

  /// يگدر يزيد قطعة (حد السطر 100 والمخزون)
  final bool canAdd;

  /// ضغطت السلة بدون ما تختار: الحدود تصير حمرة
  final bool missing;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final on = count > 0;
    final text = Text(
      label,
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 12.5, fontWeight: on ? FontWeight.w900 : FontWeight.w600, color: AppColors.ink),
    );
    final box = BoxDecoration(
      color: on ? const Color(0xFFFFF1E8) : Colors.white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: on ? AppColors.brand : (missing ? AppColors.sale : const Color(0xFFEADFD8)),
        width: 1.5,
      ),
    );
    if (!on) {
      return GestureDetector(
        onTap: canAdd ? onAdd : null,
        child: Container(
          constraints: const BoxConstraints(minWidth: 38),
          margin: const EdgeInsets.all(3),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: box,
          child: text,
        ),
      );
    }

    Widget button({required String tip, required Widget child, VoidCallback? onTap, bool filled = false}) => Semantics(
          button: true,
          label: tip,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Container(
              width: 28,
              height: 26,
              alignment: Alignment.center,
              decoration: filled
                  ? BoxDecoration(
                      color: onTap == null ? const Color(0xFFDDDDDD) : AppColors.brand,
                      borderRadius: BorderRadius.circular(7),
                    )
                  : null,
              child: child,
            ),
          ),
        );

    return Container(
      margin: const EdgeInsets.all(3),
      padding: const EdgeInsetsDirectional.fromSTEB(8, 2, 3, 2),
      decoration: box,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: text),
          const SizedBox(width: 6),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFF3D9C9)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                button(
                  tip: count == 1 ? 'شيل $label' : 'نقّص $label',
                  onTap: onRemove,
                  child: count == 1
                      ? const Icon(Icons.delete_outline, size: 17, color: AppColors.sale)
                      : const Text('−', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.ink)),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 22),
                  child: Text('$count',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.brand)),
                ),
                button(
                  tip: 'زيد $label',
                  onTap: canAdd ? onAdd : null,
                  filled: true,
                  child: const Text('+', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.filled, required this.onTap, this.busy = false});

  final String label;
  final bool filled;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final color = enabled ? AppColors.brand : const Color(0xFFCCCCCC);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? color : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color, width: 1.5),
        ),
        child: busy
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: filled ? Colors.white : AppColors.brand),
              )
            : Text(label,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: filled ? Colors.white : color)),
      ),
    );
  }
}

class _TrustItem extends StatelessWidget {
  const _TrustItem({required this.emoji, required this.text});

  final String emoji;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        Text(text, style: const TextStyle(fontSize: 11, color: Color(0xFF666666))),
      ],
    );
  }
}

// --- عارض الصور بالحجم الكامل ---
class FullScreenImageViewer extends StatefulWidget {
  final List<dynamic> imageUrls;
  final int initialIndex;

  const FullScreenImageViewer({super.key, required this.imageUrls, required this.initialIndex});

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer> {
  late final PageController _controller = PageController(initialPage: widget.initialIndex);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.imageUrls.length,
        itemBuilder: (context, index) => InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Center(
            child: Image(
              image: cachedImage('${widget.imageUrls[index]}'),
              fit: BoxFit.contain,
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : const Center(child: CircularProgressIndicator(color: Colors.white)),
              errorBuilder: (_, _, _) => const Icon(Icons.broken_image, color: Colors.grey, size: 100),
            ),
          ),
        ),
      ),
    );
  }
}

