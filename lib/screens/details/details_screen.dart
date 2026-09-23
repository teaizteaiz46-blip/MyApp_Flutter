import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/bulk_pricing.dart';
import '../../core/offline_cache.dart';
import '../../core/shop_api.dart';
import '../../facebook_service.dart';
import '../../main.dart';
import '../../services/cart_service.dart';
import '../cart/cart_screen.dart';

class DetailsScreen extends StatefulWidget {
  final int productId;

  const DetailsScreen({super.key, required this.productId});

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

  @override
  void initState() {
    super.initState();
    _productFuture = _fetchProductDetails();
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
    if (_colors(product).isNotEmpty && _selectedColor == null) {
      setState(() => _colorMissing = true);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('اختر اللون أولاً'),
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
              child: SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: (stock <= 0 || _adding) ? null : () => _addToCart(product),
                  icon: const Icon(Icons.add_shopping_cart_outlined),
                  label: Text(
                    stock <= 0 ? 'نفد من المخزون' : 'أضف إلى السلة',
                    style: const TextStyle(fontSize: 18),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
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
                        _BulkOffers(tiers: tiers, quote: stock > 0 ? quoteProduct(product, _quantity) : null),
                      ],
                      const SizedBox(height: 8),
                      _StockLabel(stock: stock),
                      if (colors.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Text(
                          'اللون',
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
                          const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Text('اختر اللون قبل الإضافة للسلة', style: TextStyle(color: Colors.red, fontSize: 12)),
                          ),
                      ],
                      if (stock > 0) ...[
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
                  image: cachedImage(images[index]),
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
  const _BulkOffers({required this.tiers, required this.quote});

  final List<BulkTier> tiers;
  final BulkQuote? quote;

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
