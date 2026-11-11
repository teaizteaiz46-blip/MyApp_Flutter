import 'package:flutter/foundation.dart' show ValueNotifier, visibleForTesting;
import 'package:intl/intl.dart' show NumberFormat;

import '../core/product_options.dart' show pieces;
import '../main.dart';

/// عرض على مجموعة منتجات (بأي سعر):
/// - باقة: أي [qty] قطع من منتجات العرض بسعر [price] (والتوصيل مجاني إذا [freeDelivery])
/// - توصيل مجاني: الأسعار عادية، بس إذا مجموع القطع وصل [qty] التوصيل مجاني
/// السيرفر (private.cart_price) هو المرجع؛ هنا بس للعرض والحساب قبل الطلب.
class Offer {
  const Offer({
    required this.id,
    required this.title,
    required this.isBundle,
    required this.qty,
    required this.price,
    required this.freeDelivery,
    required this.endsAt,
    required this.productIds,
  });

  final int id;
  final String title;
  final bool isBundle;
  final int qty;
  final double price;
  final bool freeDelivery;
  final DateTime? endsAt;
  final List<int> productIds;

  static final NumberFormat _money = NumberFormat('#,###');

  factory Offer.fromJson(Map<String, dynamic> j) => Offer(
        id: (j['id'] as num).toInt(),
        title: (j['title'] ?? '').toString(),
        isBundle: j['kind'] == 'bundle',
        qty: (j['qty'] as num?)?.toInt() ?? 0,
        price: (j['price'] as num?)?.toDouble() ?? 0,
        freeDelivery: j['free_delivery'] != false,
        endsAt: DateTime.tryParse('${j['ends_at'] ?? ''}')?.toLocal(),
        productIds: ((j['product_ids'] as List?) ?? const []).map((e) => (e as num).toInt()).toList(),
      );

  /// نص القاعدة للزبون
  String get rule => isBundle
      ? 'أي ${pieces(qty)} من منتجات العرض بـ ${_money.format(price)} د.ع${freeDelivery ? ' + توصيل مجاني' : ''}'
      : 'اجمعوا ${pieces(qty)} من منتجات العرض والتوصيل مجاني';

  /// نص قصير لكارت المنتج
  String get short => isBundle
      ? 'أي ${pieces(qty)} بـ ${_money.format(price)}${freeDelivery ? ' + توصيل مجاني' : ''}'
      : '${pieces(qty)} من العرض = توصيل مجاني';

  /// "باقي يومين" إلخ، أو null إذا العرض بلا نهاية أو نهايته بعيدة
  String? get endsLabel {
    final end = endsAt;
    if (end == null) return null;
    final now = DateTime.now();
    if (!end.isAfter(now)) return null;
    // بالأيام التقويمية: ينتهي اليوم / باجر / باقي يومين...
    final d = DateTime(end.year, end.month, end.day).difference(DateTime(now.year, now.month, now.day)).inDays;
    if (d >= 7) return null;
    return switch (d) {
      0 => 'العرض ينتهي اليوم',
      1 => 'العرض ينتهي باجر',
      2 => 'باقي يومين على العرض',
      _ => 'باقي $d أيام على العرض',
    };
  }
}

class OffersService {
  OffersService._();

  static List<Offer> _offers = const [];
  static DateTime? _loadedAt;
  static Future<List<Offer>>? _loading;

  static List<Offer> get offers => _offers;

  /// توصيل مجاني للطلب كله إذا مجموع القطع وصل هذا العدد (من صفحة الأدمن)، أو null إذا مطفي.
  static final ValueNotifier<int?> freeDeliveryPieces = ValueNotifier<int?>(null);

  /// العروض الشغّالة وإعداد التوصيل المجاني (تتحدث كل 3 دقايق). إذا صار خطأ نبقى على آخر نسخة.
  static Future<List<Offer>> load({bool force = false}) {
    final fresh = _loadedAt != null && DateTime.now().difference(_loadedAt!) < const Duration(minutes: 3);
    if (fresh && !force) return Future.value(_offers);
    return _loading ??= () async {
      try {
        final settings = _loadSettings();
        final res = await supabase.rpc('active_offers');
        _offers = ((res as List?) ?? const [])
            .map((e) => Offer.fromJson(Map<String, dynamic>.from(e as Map)))
            .where((o) => o.qty > 1 && o.productIds.isNotEmpty)
            .toList();
        await settings;
        _loadedAt = DateTime.now();
      } catch (_) {
        // نبقى على النسخة القديمة
      } finally {
        _loading = null;
      }
      return _offers;
    }();
  }

  static Future<void> _loadSettings() async {
    try {
      final row = await supabase
          .from('store_settings')
          .select('free_delivery_pieces_on, free_delivery_min_pieces')
          .eq('id', 1)
          .maybeSingle();
      final on = row?['free_delivery_pieces_on'] == true;
      final min = (row?['free_delivery_min_pieces'] as num?)?.toInt();
      freeDeliveryPieces.value = on && min != null && min > 1 ? min : null;
    } catch (_) {
      // نبقى على آخر قيمة
    }
  }

  @visibleForTesting
  static void debugSetOffers(List<Offer> offers) {
    _offers = offers;
    _loadedAt = DateTime.now();
  }

  static Offer? offerFor(int productId) {
    for (final o in _offers) {
      if (o.productIds.contains(productId)) return o;
    }
    return null;
  }

  /// يطبّق العرض على بيانات المنتج حتى حسابات السعر بالتطبيق تطابق السيرفر:
  /// الباقة تصير "مجموعة عرض" بدرجة وحدة (وتلغي عروض المنتج الخاصة)، والتوصيل المجاني يتحسب بالسلة.
  static Map<String, dynamic> apply(Map<String, dynamic> product) {
    final id = (product['id'] as num?)?.toInt();
    final o = id == null ? null : offerFor(id);
    if (o == null) return product;
    final p = Map<String, dynamic>.of(product);
    p['_offer_id'] = o.id;
    p['_offer_short'] = o.short;
    if (o.isBundle) {
      p['offer_group'] = '__offer_${o.id}';
      p['bulk_tiers'] = [
        {'qty': o.qty, 'price': o.price, 'free_delivery': o.freeDelivery},
      ];
      p['unit_tiers'] = const [];
    } else {
      p['_fd_offer'] = {'id': o.id, 'qty': o.qty};
    }
    return p;
  }

  static Map<int, Map<String, dynamic>> applyAll(Map<int, Map<String, dynamic>> products) =>
      {for (final e in products.entries) e.key: apply(e.value)};
}
