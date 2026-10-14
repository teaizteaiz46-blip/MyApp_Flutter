import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/bulk_pricing.dart';
import '../../core/offline_cache.dart';
import '../../core/product_options.dart';
import '../../core/shop_api.dart';
import '../../facebook_service.dart';
import '../../main.dart';
import '../../services/cart_service.dart';
import '../../services/visit_logger.dart';
import '../cart/cart_screen.dart';

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

  int _currentPage = 0;
  String? _selectedColor;
  bool _colorMissing = false;
  int _quantity = 1;
  bool _adding = false;

  /// منتجات الجملة: عدد كل لون/خيار (الصفر ما ينضاف)
  final Map<String, int> _multiQty = {};

  int get _multiTotal => _multiQty.values.fold(0, (s, q) => s + q);

  bool _isMulti(Map<String, dynamic> p) => isWholesale(p) && _colors(p).isNotEmpty;

  @override
  void initState() {
    super.initState();
    _productFuture = _fetchProductDetails();
    VisitLogger.productOpened(widget.productId, source: widget.source, campaign: widget.campaign);
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
    FacebookAnalyticsService.logViewContent(id: '${widget.productId}', price: _price(data));
    return data;
  }

  static double _price(Map<String, dynamic> p) => (p['price'] as num?)?.toDouble() ?? 0;
  static double _oldPrice(Map<String, dynamic> p) => (p['old_price'] as num?)?.toDouble() ?? 0;
  static int _stock(Map<String, dynamic> p) => (p['stock'] as num?)?.toInt() ?? 0;
  static List<String> _colors(Map<String, dynamic> p) =>
      ((p['colors'] as List?) ?? const []).map((e) => '$e'.trim()).where((e) => e.isNotEmpty).toList();
  static List<String> _images(Map<String, dynamic> p) =>
      ((p['image_url'] as List?) ?? const []).map((e) => '$e').where((e) => e.isNotEmpty).toList();

  int _maxQty(Map<String, dynamic> p) {
    final stock = _stock(p);
    return stock < CartService.maxQuantityPerLine ? stock : CartService.maxQuantityPerLine;
  }

  Future<void> _addToCart(Map<String, dynamic> product) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    if (_stock(product) <= 0) {
      messenger.showSnackBar(const SnackBar(content: Text('هذا المنتج نفد حالياً')));
      return;
    }
    if (_isMulti(product)) {
      await _addMultiToCart(product);
      return;
    }
    if (_colors(product).isNotEmpty && _selectedColor == null) {
      setState(() => _colorMissing = true);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('اختر ${optionTitle(_colors(product))} أولاً'),
          backgroundColor: Colors.red,
        ));
      return;
    }

    setState(() => _adding = true);
    try {
      await CartService.instance.add(widget.productId, color: _selectedColor, quantity: _quantity);
      FacebookAnalyticsService.logAddToCart(
        id: '${widget.productId}',
        price: quoteProduct(product, _quantity).total,
      );
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: const Text('تمت الإضافة إلى السلة'),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: 'عرض السلة',
            textColor: Colors.white,
            onPressed: () => navigator.push(MaterialPageRoute(builder: (_) => const CartScreen())),
          ),
        ));
    } catch (e) {
      messenger.showSnackBar(const SnackBar(
        content: Text('تعذر حفظ السلة، حاول مرة ثانية'),
        backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  /// جملة: كل لون بعدده يتضاف كسطر بالسلة (نفس اللون يتجمع ويا الموجود)
  Future<void> _addMultiToCart(Map<String, dynamic> product) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final picks = {for (final e in _multiQty.entries) if (e.value > 0) e.key: e.value};
    if (picks.isEmpty) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('حددي عدد لـ ${optionTitle(_colors(product))} واحد على الأقل'),
          backgroundColor: Colors.red,
        ));
      return;
    }
    final total = picks.values.fold(0, (s, q) => s + q);
    setState(() => _adding = true);
    try {
      for (final e in picks.entries) {
        await CartService.instance.add(widget.productId, color: e.key, quantity: e.value);
      }
      FacebookAnalyticsService.logAddToCart(id: '${widget.productId}', price: quoteProduct(product, total).total);
      if (!mounted) return;
      setState(_multiQty.clear);
      final min = minQtyOf(product);
      final inCart = CartService.instance.lines.value
          .where((l) => l.productId == widget.productId)
          .fold(0, (s, l) => s + l.quantity);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(min != null && inCart < min
              ? 'انضافت $total قطعة. أقل طلب $min قطعة، باقي ${min - inCart}'
              : 'انضافت $total قطعة إلى السلة'),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: 'عرض السلة',
            textColor: Colors.white,
            onPressed: () => navigator.push(MaterialPageRoute(builder: (_) => const CartScreen())),
          ),
        ));
    } catch (e) {
      messenger.showSnackBar(const SnackBar(
        content: Text('تعذر حفظ السلة، حاول مرة ثانية'),
        backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  /// يوزّع [count] قطعة على كل الألوان بالتساوي (الباقي على الأوائل)
  void _distribute(List<String> colors, int count, int maxPer) {
    if (colors.isEmpty) return;
    final per = count ~/ colors.length;
    final rem = count % colors.length;
    setState(() {
      _multiQty.clear();
      for (var i = 0; i < colors.length; i++) {
        final q = (per + (i < rem ? 1 : 0)).clamp(0, maxPer);
        if (q > 0) _multiQty[colors[i]] = q;
      }
    });
  }

  Widget _buildWholesalePicker(Map<String, dynamic> product, List<String> colors, int maxPer) {
    final title = optionTitle(colors);
    final target = minQtyOf(product) ?? 12;
    Widget quick(String label, VoidCallback onTap) => ActionChip(
          label: Text(label, style: const TextStyle(fontSize: 13)),
          onPressed: onTap,
          backgroundColor: Colors.orange.shade50,
          side: BorderSide(color: Colors.orange.shade200),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text('اختاري $title والكمية', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            quick('+1 لكل $title', () => setState(() {
                  for (final c in colors) {
                    _multiQty[c] = ((_multiQty[c] ?? 0) + 1).clamp(0, maxPer);
                  }
                })),
            quick('وزّعي $target بالتساوي', () => _distribute(colors, target, maxPer)),
            if (_multiTotal > 0) quick('تصفير', () => setState(_multiQty.clear)),
          ],
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: colors.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            mainAxisExtent: 48,
          ),
          itemBuilder: (context, i) {
            final c = colors[i];
            final q = _multiQty[c] ?? 0;
            final on = q > 0;
            return Container(
              padding: const EdgeInsetsDirectional.only(start: 10, end: 4),
              decoration: BoxDecoration(
                color: on ? Colors.orange.shade50 : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: on ? Colors.deepOrange : Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(c, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: on ? Colors.deepOrange.shade800 : null)),
                  ),
                  _MiniStepButton(
                    icon: Icons.remove,
                    onTap: q > 0 ? () => setState(() => q == 1 ? _multiQty.remove(c) : _multiQty[c] = q - 1) : null,
                  ),
                  SizedBox(
                    width: 26,
                    child: Text('$q', textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.bold, color: on ? Colors.deepOrange.shade800 : Colors.grey)),
                  ),
                  _MiniStepButton(
                    icon: Icons.add,
                    onTap: q < maxPer ? () => setState(() => _multiQty[c] = q + 1) : null,
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _productFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
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
        final colors = _colors(product);
        final maxQty = _maxQty(product);
        final tiers = BulkTier.ofProduct(product);
        final discount = oldPrice > price && oldPrice > 0 ? ((oldPrice - price) / oldPrice * 100).round() : 0;
        final multi = _isMulti(product);
        final minQty = minQtyOf(product);
        final pickedQty = multi ? _multiTotal : _quantity;

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(backgroundColor: Colors.white, elevation: 0),
          bottomNavigationBar: SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (multi && stock > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Text(
                            '${_multiQty.values.where((q) => q > 0).length} ${optionTitle(colors)} · $_multiTotal قطعة',
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                          const Spacer(),
                          Text(
                            '${_money.format(quoteProduct(product, _multiTotal).total)} د.ع',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                          ),
                        ],
                      ),
                    ),
                  SizedBox(
                height: 52,
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (stock <= 0 || _adding) ? null : () => _addToCart(product),
                  icon: const Icon(Icons.add_shopping_cart_outlined),
                  label: Text(
                    stock <= 0
                        ? 'نفد من المخزون'
                        : multi && _multiTotal > 0
                            ? 'أضف $_multiTotal قطعة للسلة'
                            : 'أضف إلى السلة',
                    style: const TextStyle(fontSize: 18),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
                ],
              ),
            ),
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildGallery(images),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, height: 1.4)),
                      const SizedBox(height: 10),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 10,
                        children: [
                          Text(
                            '${_money.format(price)} د.ع',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.deepOrange),
                          ),
                          if (discount > 0) ...[
                            Text(
                              _money.format(oldPrice),
                              style: const TextStyle(color: Colors.grey, decoration: TextDecoration.lineThrough),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '-$discount%',
                                style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (tiers.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _BulkOffers(
                          tiers: tiers,
                          quote: stock > 0 ? quoteProduct(product, pickedQty) : null,
                          grouped: (product['offer_group'] ?? '').toString().trim().isNotEmpty,
                        ),
                      ],
                      const SizedBox(height: 8),
                      _StockLabel(stock: stock),
                      if (isWholesale(product))
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              minQty != null ? 'جملة · أقل طلب $minQty قطعة' : 'جملة',
                              style: TextStyle(color: Colors.deepOrange.shade800, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ),
                      if (multi && stock > 0) _buildWholesalePicker(product, colors, maxQty),
                      if (!multi && colors.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Text(
                          optionTitle(colors),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _colorMissing ? Colors.red : null,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final color in colors)
                              ChoiceChip(
                                label: Text(color),
                                selected: _selectedColor == color,
                                selectedColor: Colors.deepOrange,
                                labelStyle: TextStyle(
                                  color: _selectedColor == color ? Colors.white : Colors.black87,
                                ),
                                side: BorderSide(
                                  color: _colorMissing ? Colors.red : Colors.grey.shade300,
                                ),
                                onSelected: (selected) => setState(() {
                                  _selectedColor = selected ? color : null;
                                  _colorMissing = false;
                                }),
                              ),
                          ],
                        ),
                        if (_colorMissing)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              'اختر ${optionTitle(colors)} قبل الإضافة للسلة',
                              style: const TextStyle(color: Colors.red, fontSize: 12),
                            ),
                          ),
                      ],
                      if (stock > 0 && !multi) ...[
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            const Text('الكمية', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            const Spacer(),
                            IconButton.outlined(
                              onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                              icon: const Icon(Icons.remove),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text('$_quantity', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            ),
                            IconButton.outlined(
                              onPressed: _quantity < maxQty ? () => setState(() => _quantity++) : null,
                              icon: const Icon(Icons.add),
                            ),
                          ],
                        ),
                      ],
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        const Text('الوصف', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text(description, style: TextStyle(fontSize: 15, color: Colors.grey[800], height: 1.6)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGallery(List<String> images) {
    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: images.isEmpty ? 1 : images.length,
            onPageChanged: (value) => setState(() => _currentPage = value),
            itemBuilder: (context, index) {
              if (images.isEmpty) {
                return Container(
                  color: Colors.grey[200],
                  child: const Icon(Icons.hide_image_outlined, color: Colors.grey, size: 80),
                );
              }
              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FullScreenImageViewer(imageUrls: images, initialIndex: index),
                  ),
                ),
                child: Image(
                  image: cachedImage(
                    images[index],
                    decodeWidth: decodeWidthFor(context, MediaQuery.sizeOf(context).width, MediaQuery.sizeOf(context).width),
                  ),
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) => progress == null
                      ? child
                      : Container(color: Colors.grey[200], child: const Center(child: CircularProgressIndicator())),
                  errorBuilder: (_, _, _) => Container(
                    color: Colors.grey[200],
                    child: const Icon(Icons.broken_image, color: Colors.grey, size: 80),
                  ),
                ),
              );
            },
          ),
          if (images.length > 1)
            Positioned(
              bottom: 12,
              child: Row(
                children: List.generate(images.length, (index) {
                  final active = _currentPage == index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: active ? 18 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: active ? Colors.deepOrange : Colors.white.withValues(alpha: 0.8),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}

/// درجات عروض الكمية تحت السعر، ومعاها السعر الكلي والتوفير إذا الكمية المختارة وصلت درجة.
class _BulkOffers extends StatelessWidget {
  const _BulkOffers({required this.tiers, required this.quote, this.grouped = false});

  final List<BulkTier> tiers;
  final BulkQuote? quote;

  /// المنتج بمجموعة عرض: قطعه تتجمع ويا منتجات ثانية بنفس العرض.
  final bool grouped;

  static final NumberFormat _money = NumberFormat('#,###');

  @override
  Widget build(BuildContext context) {
    final quote = this.quote;
    final applied = quote != null && quote.applied;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_offer, size: 18, color: Colors.deepOrange.shade700),
              const SizedBox(width: 6),
              Text(
                'عروض الكمية',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange.shade700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final tier in tiers)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    quote?.packs.containsKey(tier) == true ? Icons.check_circle : Icons.circle_outlined,
                    size: 16,
                    color: quote?.packs.containsKey(tier) == true ? Colors.green.shade700 : Colors.grey,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(tier.label(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          if (grouped)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 2),
              child: Text(
                'العرض يشمل موديلات ثانية بنفس العرض، تگدرين تجمعين قطع منها بالسلة',
                style: TextStyle(fontSize: 12, color: Colors.deepOrange.shade800),
              ),
            ),
          if (applied) ...[
            const Divider(height: 16),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                Text(
                  '${piecesLabel(quote.qty)}: ${_money.format(quote.total)} د.ع',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                if (quote.saving > 0)
                  Text(
                    _money.format(quote.regularTotal),
                    style: const TextStyle(color: Colors.grey, decoration: TextDecoration.lineThrough),
                  ),
              ],
            ),
            if (quote.saving > 0 || quote.freeDelivery)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  [
                    if (quote.saving > 0) 'توفّر ${_money.format(quote.saving)} د.ع',
                    if (quote.freeDelivery) 'توصيل مجاني',
                  ].join(' + '),
                  style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _StockLabel extends StatelessWidget {
  const _StockLabel({required this.stock});

  final int stock;

  @override
  Widget build(BuildContext context) {
    final (String text, Color color) = switch (stock) {
      <= 0 => ('نفد من المخزون', Colors.red.shade700),
      <= 5 => ('باقي $stock قطع فقط', Colors.orange.shade800),
      _ => ('متوفر', Colors.green.shade700),
    };
    return Row(
      children: [
        Icon(Icons.inventory_2_outlined, size: 16, color: color),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
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

/// زر − / + صغير لشبكة ألوان الجملة
class _MiniStepButton extends StatelessWidget {
  const _MiniStepButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30,
      height: 30,
      child: IconButton.outlined(
        padding: EdgeInsets.zero,
        iconSize: 16,
        onPressed: onTap,
        icon: Icon(icon),
      ),
    );
  }
}
