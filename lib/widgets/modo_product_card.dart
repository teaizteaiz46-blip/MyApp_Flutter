import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;

import '../core/offline_cache.dart';
import '../facebook_service.dart';
import '../services/cart_service.dart';
import '../theme/app_theme.dart';

final NumberFormat kMoney = NumberFormat('#,###');

double priceOf(Map<String, dynamic> p) => (p['price'] as num?)?.toDouble() ?? 0;
double oldPriceOf(Map<String, dynamic> p) => (p['old_price'] as num?)?.toDouble() ?? 0;

List<String> imagesOf(Map<String, dynamic> p) =>
    ((p['image_url'] as List?) ?? const []).map((e) => '$e').where((e) => e.isNotEmpty).toList();

int discountPercentOf(Map<String, dynamic> p) {
  final price = priceOf(p);
  final old = oldPriceOf(p);
  if (old <= 0 || old <= price) return 0;
  return ((old - price) / old * 100).round();
}

/// صورة منتج بخلفية هادئة وظهور تدريجي.
class ProductImage extends StatelessWidget {
  const ProductImage({super.key, required this.url, this.fit = BoxFit.cover});

  final String? url;
  final BoxFit fit;

  static const Widget _placeholder = ColoredBox(
    color: AppColors.placeholder,
    child: Center(child: Icon(Icons.image_outlined, color: AppColors.muted)),
  );

  @override
  Widget build(BuildContext context) {
    final u = url ?? '';
    if (u.isEmpty) return _placeholder;
    return ColoredBox(
      color: AppColors.placeholder,
      child: Image(
        image: cachedImage(u),
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        frameBuilder: (context, child, frame, wasSync) => wasSync
            ? child
            : AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: const Duration(milliseconds: 250),
                child: child,
              ),
        errorBuilder: (_, _, _) => _placeholder,
      ),
    );
  }
}

/// شارة الخصم الحمراء (تنستخدم فوق الصور).
class DiscountBadge extends StatelessWidget {
  const DiscountBadge({super.key, required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: AppColors.sale, borderRadius: BorderRadius.circular(8)),
      child: Text(
        '-$percent%',
        textDirection: TextDirection.ltr,
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// سعر برتقالي عريض + السعر القديم + نسبة الخصم بمربع فاتح.
class PriceLine extends StatelessWidget {
  const PriceLine({super.key, required this.product, this.big = true});

  final Map<String, dynamic> product;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final price = priceOf(product);
    final old = oldPriceOf(product);
    final discount = discountPercentOf(product);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 2,
      children: [
        Text.rich(
          TextSpan(children: [
            TextSpan(
              text: kMoney.format(price),
              style: TextStyle(fontSize: big ? 18 : 16, fontWeight: FontWeight.w800, color: AppColors.brandDark),
            ),
            const TextSpan(
              text: ' د.ع',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.brandDark),
            ),
          ]),
        ),
        if (old > price)
          Text(
            kMoney.format(old),
            style: const TextStyle(fontSize: 11, color: AppColors.muted, decoration: TextDecoration.lineThrough),
          ),
        if (discount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(color: AppColors.brandSoft, borderRadius: BorderRadius.circular(4)),
            child: Text(
              '-$discount%',
              textDirection: TextDirection.ltr,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.brandDark),
            ),
          ),
      ],
    );
  }
}

class StarRating extends StatelessWidget {
  const StarRating({super.key, required this.rating, this.size = 14});

  final double rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    final r = rating.clamp(0, 5).toDouble();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            r >= i
                ? Icons.star_rounded
                : (r >= i - 0.5 ? Icons.star_half_rounded : Icons.star_outline_rounded),
            size: size,
            color: AppColors.star,
          ),
        const SizedBox(width: 4),
        Text(
          '(${r.toStringAsFixed(1)})',
          textDirection: TextDirection.ltr,
          style: const TextStyle(fontSize: 11, color: AppColors.muted),
        ),
      ],
    );
  }
}

class ModoProductCard extends StatefulWidget {
  const ModoProductCard({super.key, required this.product, required this.onTap});

  final Map<String, dynamic> product;
  final VoidCallback onTap;

  @override
  State<ModoProductCard> createState() => _ModoProductCardState();
}

class _ModoProductCardState extends State<ModoProductCard> {
  int _page = 0;
  bool _adding = false;

  Future<void> _addToCart() async {
    final product = widget.product;
    final productId = (product['id'] as num?)?.toInt();
    if (productId == null || _adding) return;

    final messenger = ScaffoldMessenger.of(context);
    final colors = (product['colors'] as List?) ?? const [];

    if (colors.isNotEmpty) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('اختر اللون من صفحة المنتج'),
          duration: Duration(seconds: 2),
        ));
      widget.onTap();
      return;
    }

    setState(() => _adding = true);
    try {
      await CartService.instance.add(productId);
      FacebookAnalyticsService.logAddToCart(id: '$productId', price: priceOf(product));
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('تمت الإضافة للسلة'),
          duration: Duration(milliseconds: 1200),
        ));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
        content: Text('تعذر حفظ السلة، حاول مرة ثانية'),
        backgroundColor: AppColors.sale,
      ));
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final images = imagesOf(p);
    final name = (p['name'] ?? '').toString().trim();
    final rating = (p['rating'] as num?)?.toDouble() ?? 0;
    final stock = (p['stock'] as num?)?.toInt() ?? 0;
    final rank = (p['category_rank'] as num?)?.toInt();
    final categoryName = (p['category_name'] ?? '').toString().trim();
    final showRank = rank != null && rank <= 10 && categoryName.isNotEmpty;

    return Material(
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: widget.onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 4 / 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (images.length <= 1)
                    ProductImage(url: images.isEmpty ? null : images.first)
                  else
                    PageView.builder(
                      itemCount: images.length,
                      onPageChanged: (i) => setState(() => _page = i),
                      itemBuilder: (_, i) => ProductImage(url: images[i]),
                    ),
                  if (stock > 0 && stock <= 3)
                    PositionedDirectional(
                      top: 8,
                      start: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.sale,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'آخر $stock قطع',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  if (images.length > 1)
                    Positioned(
                      bottom: 10,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < images.length && i < 6; i++)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: i == _page ? 12 : 5,
                              height: 5,
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(3),
                                color: i == _page ? Colors.white : Colors.white.withValues(alpha: 0.6),
                              ),
                            ),
                        ],
                      ),
                    ),
                  PositionedDirectional(
                    bottom: 8,
                    end: 8,
                    child: _CartButton(busy: _adding, onPressed: _addToCart),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PriceLine(product: p),
                  const SizedBox(height: 4),
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, height: 1.35, color: AppColors.ink),
                  ),
                  if (showRank) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF4EC),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.workspace_premium_rounded, size: 14, color: AppColors.brand),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text.rich(
                              TextSpan(children: [
                                const TextSpan(text: 'الأكثر مبيعاً '),
                                TextSpan(text: '#$rank', style: const TextStyle(fontWeight: FontWeight.w800)),
                                TextSpan(text: ' $categoryName', style: const TextStyle(fontWeight: FontWeight.w500)),
                              ]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, color: AppColors.brandDark, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (rating > 0) ...[
                    const SizedBox(height: 6),
                    StarRating(rating: rating),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartButton extends StatelessWidget {
  const _CartButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'أضف للسلة',
      child: Material(
        color: Colors.white.withValues(alpha: 0.95),
        shape: const CircleBorder(),
        elevation: 1,
        shadowColor: Colors.black26,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: busy ? null : onPressed,
          child: SizedBox(
            width: 36,
            height: 36,
            child: busy
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_shopping_cart_rounded, color: AppColors.ink, size: 19),
          ),
        ),
      ),
    );
  }
}
