import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/product_options.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/modo_product_card.dart';

/// عروض فلاش: العدّاد يعتمد على offer_ends_at الحقيقي بالمنتجات.
/// إذا ماكو تاريخ نهاية، القسم يظهر باسم "عروض اليوم" بدون عدّاد.
class FlashDealsSection extends StatelessWidget {
  const FlashDealsSection({
    super.key,
    required this.dealsFuture,
    required this.onProductTap,
    required this.onSeeAll,
  });

  final Future<List<Map<String, dynamic>>> dealsFuture;
  final void Function(Map<String, dynamic> product) onProductTap;
  final VoidCallback onSeeAll;

  static DateTime? _endsAt(List<Map<String, dynamic>> deals) {
    final now = DateTime.now();
    DateTime? best;
    for (final d in deals) {
      final t = DateTime.tryParse('${d['offer_ends_at'] ?? ''}');
      if (t == null || !t.isAfter(now)) continue;
      if (best == null || t.isBefore(best)) best = t;
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: dealsFuture,
      builder: (context, snapshot) {
        final deals = snapshot.data;
        if (snapshot.hasError || (deals != null && deals.isEmpty)) return const SizedBox.shrink();
        final endsAt = deals == null ? null : _endsAt(deals);

        return Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.only(top: 14, bottom: 16),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFEDE6), Color(0xFFFFF8F5)],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 8, 10),
                child: Row(
                  children: [
                    Text(
                      endsAt != null ? 'عرض الساعة' : 'عروض اليوم',
                      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.ink),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.bolt_rounded, color: AppColors.brand, size: 22),
                    const Spacer(),
                    if (endsAt != null) ...[
                      const Text('ينتهي خلال', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                      const SizedBox(width: 6),
                      _Countdown(endsAt: endsAt),
                    ],
                    IconButton(
                      tooltip: 'عرض الكل',
                      onPressed: onSeeAll,
                      icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.ink),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 196,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: deals?.length ?? 4,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, i) {
                    if (deals == null) return const _FlashCard.loading();
                    final p = deals[i];
                    return _FlashCard(product: p, timed: endsAt != null, onTap: () => onProductTap(p));
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FlashCard extends StatelessWidget {
  const _FlashCard({required Map<String, dynamic> this.product, required this.timed, required VoidCallback this.onTap});

  const _FlashCard.loading()
      : product = null,
        timed = false,
        onTap = null;

  final Map<String, dynamic>? product;
  final bool timed;
  final VoidCallback? onTap;

  static const double _width = 118;
  static const double _imageHeight = 140;

  @override
  Widget build(BuildContext context) {
    final p = product;
    if (p == null) {
      return Container(
        width: _width,
        height: _imageHeight,
        decoration: BoxDecoration(color: AppColors.placeholder, borderRadius: BorderRadius.circular(12)),
      );
    }
    final images = imagesOf(p);
    final price = priceOf(p);
    final old = oldPriceOf(p);
    final discount = discountPercentOf(p);
    final stock = (p['stock'] as num?)?.toInt() ?? 0;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: _width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: _width,
                height: _imageHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ProductImage(url: images.isEmpty ? null : images.first),
                    if (discount > 0)
                      PositionedDirectional(
                        top: 6,
                        start: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(color: AppColors.sale, borderRadius: BorderRadius.circular(6)),
                          child: Text(
                            '-$discount%',
                            textDirection: TextDirection.ltr,
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    if (timed)
                      PositionedDirectional(
                        top: 6,
                        end: 6,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          child: const Icon(Icons.alarm_rounded, size: 14, color: AppColors.sale),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: Text(
                    kMoney.format(price),
                    maxLines: 1,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.brandDark),
                  ),
                ),
                if (old > price) ...[
                  const SizedBox(width: 6),
                  Text(
                    kMoney.format(old),
                    style: const TextStyle(fontSize: 11, color: AppColors.muted, decoration: TextDecoration.lineThrough),
                  ),
                ],
              ],
            ),
            // مخزون حقيقي، يطلع بس إذا قليل
            if (stock > 0 && stock <= 10)
              Text(
                'باقي ${pieces(stock)}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.sale),
              ),
          ],
        ),
      ),
    );
  }
}

class _Countdown extends StatefulWidget {
  const _Countdown({required this.endsAt});

  final DateTime endsAt;

  @override
  State<_Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<_Countdown> {
  Timer? _timer;
  Duration _left = Duration.zero;

  @override
  void initState() {
    super.initState();
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void didUpdateWidget(_Countdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.endsAt != widget.endsAt) _tick();
  }

  void _tick() {
    final left = widget.endsAt.difference(DateTime.now());
    if (!mounted) return;
    setState(() => _left = left.isNegative ? Duration.zero : left);
    if (left.isNegative) _timer?.cancel();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = _left.inHours;
    final m = _left.inMinutes.remainder(60);
    final s = _left.inSeconds.remainder(60);
    String two(int v) => v.toString().padLeft(2, '0');

    Widget box(String v) => Container(
          width: 26,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: AppColors.sale, borderRadius: BorderRadius.circular(6)),
          child: Text(
            v,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()]),
          ),
        );
    const colon = Padding(
      padding: EdgeInsets.symmetric(horizontal: 2),
      child: Text(':', style: TextStyle(fontWeight: FontWeight.w800)),
    );

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [box(two(h > 99 ? 99 : h)), colon, box(two(m)), colon, box(two(s))],
      ),
    );
  }
}
