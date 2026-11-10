import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;

import '../core/bulk_pricing.dart';
import '../core/offline_cache.dart';
import '../core/product_options.dart';
import '../services/wishlist_service.dart';
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
      child: LayoutBuilder(
        builder: (context, constraints) => Image(
          // نرسمها بحجم المساحة الي تنعرض بيها بس (مو 1400 بكسل كاملة)
          image: cachedImage(u, decodeWidth: decodeWidthFor(context, constraints.maxWidth, constraints.maxHeight)),
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

// ============================================================================
// كارت المنتج بالشبكة (تصميم الواجهة الجديدة)

const Color _kOfferGreen = Color(0xFF2E7D32);

/// أرخص سعر للقطعة الوحدة (من عروض الكمية) — "يبدأ من".
double fromPriceOf(Map<String, dynamic> p) {
  var best = priceOf(p);
  if (usesUnitTiers(p)) {
    for (final c in unitTierCells(best, UnitTier.ofProduct(p))) {
      if (c.$3 < best) best = c.$3;
    }
    return best;
  }
  for (final t in BulkTier.ofProduct(p)) {
    final per = (t.price / t.qty).ceilToDouble();
    if (per > 0 && per < best) best = per;
  }
  return best;
}

/// السعر المشطوب جنب "يبدأ من": السعر القديم، أو سعر القطعة إذا العرض أرخص.
double strikePriceOf(Map<String, dynamic> p) {
  final shown = fromPriceOf(p);
  final old = oldPriceOf(p);
  if (old > shown) return old;
  final price = priceOf(p);
  return price > shown ? price : 0;
}

/// "10 موديلات" / "15 لون" / "5 قياسات"
String optionsCountLabel(List<String> options) {
  final n = options.length;
  if (n < 2) return '';
  if (options.every((o) => o.startsWith('موديل'))) return '$n موديلات';
  return switch (optionKindOf(options)) {
    OptionKind.color => '$n لون',
    OptionKind.size => '$n قياسات',
    _ => '$n خيار',
  };
}

class ModoProductCard extends StatefulWidget {
  const ModoProductCard({super.key, required this.product, required this.onTap});

  final Map<String, dynamic> product;
  final VoidCallback onTap;

  @override
  State<ModoProductCard> createState() => _ModoProductCardState();
}

class _ModoProductCardState extends State<ModoProductCard> {
  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final images = imagesOf(p);
    final name = (p['name'] ?? '').toString().trim();
    final tiers = BulkTier.ofProduct(p);
    final price = priceOf(p);
    final unitCells = usesUnitTiers(p) ? unitTierCells(price, UnitTier.ofProduct(p)) : const <(int, int?, double)>[];
    final from = fromPriceOf(p);
    final strike = strikePriceOf(p);
    final discount = strike > from ? ((strike - from) / strike * 100).round() : 0;
    final created = DateTime.tryParse('${p['created_at'] ?? ''}');
    final isNew = created != null && DateTime.now().difference(created).inDays < 7;
    final minQty = minQtyOf(p);
    // عرض على مجموعة منتجات (OffersService.apply)
    final offerShort = p['_offer_short'] is String ? p['_offer_short'] as String : null;

    final badges = <(String, Color, Color)>[
      if (isNew) ('جديد ✨', const Color(0xFFFFF3E0), const Color(0xFFE65100)),
      if (discount > 0) ('-$discount%', const Color(0xFFD93A2B), Colors.white),
      if (offerShort != null)
        ('🎁 عرض', const Color(0xFFE8F5E9), _kOfferGreen)
      else if (isWholesale(p))
        (minQty != null ? 'جملة من ${pieces(minQty)}' : 'جملة', const Color(0xFFFDE7EF), const Color(0xFFC2185B))
      else if (tiers.isNotEmpty)
        ('عرض ${pieces(tiers.first.qty)}', const Color(0xFFE8F5E9), _kOfferGreen)
      else if (unitCells.length > 1)
        ('جملة من ${pieces(unitCells[1].$1)}', const Color(0xFFFDE7EF), const Color(0xFFC2185B)),
    ].take(2).toList();

    final String extra;
    if (offerShort != null) {
      extra = offerShort;
    } else if (unitCells.length > 1) {
      final first = unitCells[1];
      final fd = UnitTier.ofProduct(p).any((t) => !t.mix && t.freeDelivery && t.min == first.$1);
      extra = '${first.$1}+ قطع بـ ${kMoney.format(first.$3)} للقطعة${fd ? ' + توصيل مجاني' : ''}';
    } else if (tiers.isNotEmpty) {
      final best = tiers.last;
      extra = '${pieces(best.qty)} بـ ${kMoney.format(best.price)}${best.freeDelivery ? ' + توصيل مجاني' : ''}';
    } else {
      extra = optionsCountLabel(optionsOf(p));
    }

    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 4 / 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (images.length <= 1)
                    ProductImage(url: images.isEmpty ? null : images.first)
                  else
                    PageView.builder(
                      itemCount: images.length,
                      itemBuilder: (_, i) => ProductImage(url: images[i]),
                    ),
                  PositionedDirectional(
                    top: 8,
                    start: 8,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final b in badges)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: _Pill(text: b.$1, bg: b.$2, fg: b.$3),
                          ),
                      ],
                    ),
                  ),
                  if (images.isNotEmpty)
                    PositionedDirectional(
                      bottom: 8,
                      end: 8,
                      child: _Pill(text: '📷 ${images.length}', bg: Colors.black.withValues(alpha: 0.55), fg: Colors.white),
                    ),
                  PositionedDirectional(
                    bottom: 8,
                    start: 8,
                    child: WishHeart(productId: (p['id'] as num?)?.toInt() ?? 0),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.ink, height: 1.3),
          ),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            children: [
              if (from < price)
                const Text('يبدأ من', style: TextStyle(fontSize: 11, color: Color(0xFF888888))),
              Text(
                kMoney.format(from),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.brand),
              ),
              if (strike > from)
                Text(
                  kMoney.format(strike),
                  style: const TextStyle(fontSize: 11, color: Color(0xFFAAAAAA), decoration: TextDecoration.lineThrough),
                ),
            ],
          ),
          if (extra.isNotEmpty)
            Text(
              extra,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _kOfferGreen),
            ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.bg, required this.fg});

  final String text;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(text, style: TextStyle(color: fg, fontSize: 10.5, fontWeight: FontWeight.w800)),
    );
  }
}

/// قلب المفضلة الأبيض فوق صورة الكارت
class WishHeart extends StatelessWidget {
  const WishHeart({super.key, required this.productId, this.size = 30});

  final int productId;
  final double size;

  @override
  Widget build(BuildContext context) {
    final wish = WishlistService.instance;
    return ValueListenableBuilder<Set<int>>(
      valueListenable: wish.ids,
      builder: (context, ids, _) {
        final on = ids.contains(productId);
        return GestureDetector(
          onTap: () => toggleWish(context, productId),
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Color(0x26000000), blurRadius: 6, offset: Offset(0, 2))],
            ),
            child: Text(on ? '❤️' : '🤍', style: TextStyle(fontSize: size * 0.5)),
          ),
        );
      },
    );
  }
}

/// يضيف/يشيل من المفضلة، ويطلب تسجيل الدخول إذا ماكو حساب.
Future<void> toggleWish(BuildContext context, int productId) async {
  final wish = WishlistService.instance;
  final messenger = ScaffoldMessenger.of(context);
  if (!wish.signedIn) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('سجّلي دخول من "حسابي" حتى تحفظين القطعة ونبلغج إذا نزل سعرها')));
    return;
  }
  try {
    final added = await wish.toggle(productId);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(added ? 'انحفظت بالمفضلة ♡ نبلغج إذا نزل سعرها أو رجعت متوفرة' : 'انشالت من المفضلة'),
        duration: const Duration(seconds: 2),
      ));
  } catch (_) {
    messenger.showSnackBar(const SnackBar(content: Text('تعذر الحفظ، حاولي مرة ثانية')));
  }
}
