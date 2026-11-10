import 'package:flutter/material.dart';

import '../../core/shop_api.dart';
import '../../services/offers_service.dart';
import '../../theme/app_theme.dart';
import '../home/components/home_product_grid.dart';

/// منتجات عرض وحد (باقة أو توصيل مجاني): الزبون يجمع منها بالسلة والعرض ينطبق على المجموع.
class OfferProductsScreen extends StatefulWidget {
  const OfferProductsScreen({super.key, required this.offer});

  final Offer offer;

  @override
  State<OfferProductsScreen> createState() => _OfferProductsScreenState();
}

class _OfferProductsScreenState extends State<OfferProductsScreen> {
  late final Future<List<Map<String, dynamic>>> _products = _load();

  Offer get offer => widget.offer;

  Future<List<Map<String, dynamic>>> _load() async {
    final byId = await ShopApi.fetchProductsByIds(offer.productIds);
    // نفس ترتيب العرض، والمتوفر بس
    return [
      for (final id in offer.productIds)
        if (byId[id] != null && ((byId[id]!['stock'] as num?) ?? 0) > 0) byId[id]!,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(offer.title),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
              child: OfferBanner(offer: offer),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(10, 12, 10, 24),
            sliver: HomeProductGrid(categoryId: 0, productsFuture: _products),
          ),
        ],
      ),
    );
  }
}

/// بطاقة العرض: العنوان والقاعدة ("أي 3 قطع بـ 20,000 + توصيل مجاني")، ووقت الانتهاء إذا قريب.
/// [onShowProducts] إذا انطى يطلع زر "شوفوا منتجات العرض".
class OfferBanner extends StatelessWidget {
  const OfferBanner({super.key, required this.offer, this.onShowProducts});

  final Offer offer;
  final VoidCallback? onShowProducts;

  static const _green = Color(0xFF1B7F3B);

  @override
  Widget build(BuildContext context) {
    final ends = offer.endsLabel;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7EE),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFB9E2C5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text('🎁', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  offer.title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _green),
                ),
              ),
              if (ends != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.sale, borderRadius: BorderRadius.circular(20)),
                  child: Text(ends, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            offer.rule,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.ink, height: 1.4),
          ),
          if (offer.productIds.length > 1)
            const Text(
              'تگدرون تجمعون من أكثر من موديل، والعرض ينحسب على مجموع القطع بالسلة.',
              style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.4),
            ),
          if (onShowProducts != null && offer.productIds.length > 1) ...[
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilledButton.icon(
                onPressed: onShowProducts,
                style: FilledButton.styleFrom(
                  backgroundColor: _green,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                icon: const Icon(Icons.grid_view_rounded, size: 18),
                label: Text('شوفوا منتجات العرض (${offer.productIds.length})'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
