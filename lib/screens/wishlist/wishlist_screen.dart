import 'package:flutter/material.dart';

import '../../core/shop_api.dart';
import '../../main.dart';
import '../../services/wishlist_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/modo_product_card.dart';
import '../details/details_screen.dart';

/// مفضلتي: القطع المحفوظة. إذا نزل سعر وحدة أو رجعت متوفرة يوصل إشعار.
class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  List<Map<String, dynamic>>? _products;

  @override
  void initState() {
    super.initState();
    WishlistService.instance.ids.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    WishlistService.instance.ids.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final ids = WishlistService.instance.ids.value.toList();
    if (ids.isEmpty) {
      if (mounted) setState(() => _products = const []);
      return;
    }
    try {
      final rows = await supabase.from('products').select(kProductBaseColumns).inFilter('id', ids);
      if (mounted) setState(() => _products = rows.cast<Map<String, dynamic>>());
    } catch (_) {
      if (mounted) setState(() => _products = const []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = _products;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('مفضلتي ♡'),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: products == null
          ? const Center(child: CircularProgressIndicator())
          : products.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'ماكو قطع بالمفضلة لحد هسه.\nاضغطي ♡ على أي قطعة تعجبج، ونبلغج إذا نزل سعرها أو رجعت متوفرة 🔔',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted, height: 1.6),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: products.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final p = products[i];
                    final images = imagesOf(p);
                    final stock = (p['stock'] as num?)?.toInt() ?? 0;
                    return Material(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => DetailsScreen(productId: (p['id'] as num).toInt()),
                        )),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: SizedBox(width: 74, height: 74, child: ProductImage(url: images.isEmpty ? null : images.first)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${p['name'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 4),
                                    PriceLine(product: p, big: false),
                                    if (stock <= 0)
                                      const Text('خلصت · نبلغج إذا رجعت 🔔',
                                          style: TextStyle(color: AppColors.sale, fontSize: 12, fontWeight: FontWeight.w700))
                                    else if (stock <= 5)
                                      Text('باقي $stock بس', style: const TextStyle(color: AppColors.sale, fontSize: 12, fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'شيليها من المفضلة',
                                onPressed: () => WishlistService.instance.toggle((p['id'] as num).toInt()),
                                icon: const Icon(Icons.favorite_rounded, color: AppColors.brand),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
