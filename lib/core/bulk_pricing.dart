import 'package:intl/intl.dart';

import '../services/cart_service.dart';

/// عروض الكمية: نسخة للعرض فقط من `private.bulk_price` بالسيرفر.
/// السيرفر (place_order) هو المرجع النهائي للسعر، وأي تعديل بالمنطق لازم يصير هناك أولاً.

/// أقصى عدد قطع ناقصة حتى نعرض تلميح "زيد قطعة وتاخذ العرض" بالسلة.
const int kBulkHintMaxMissing = 2;

final NumberFormat _money = NumberFormat('#,###');

class BulkTier {
  const BulkTier({required this.qty, required this.price, this.freeDelivery = false});

  final int qty;
  final double price;
  final bool freeDelivery;

  static final RegExp _intRe = RegExp(r'^[0-9]+$');
  static final RegExp _priceRe = RegExp(r'^[0-9]+(\.[0-9]+)?$');

  /// نفس شروط السيرفر: qty عدد صحيح أكبر من 1، والسعر رقم موجب.
  static BulkTier? tryParse(dynamic raw) {
    if (raw is! Map) return null;
    final qtyText = '${raw['qty'] ?? ''}';
    final priceText = '${raw['price'] ?? ''}';
    if (!_intRe.hasMatch(qtyText) || !_priceRe.hasMatch(priceText)) return null;
    final qty = int.parse(qtyText);
    if (qty <= 1) return null;
    final fd = raw['free_delivery'];
    return BulkTier(
      qty: qty,
      price: double.parse(priceText),
      freeDelivery: fd == true || (fd is String && const {'true', 't', 'yes', 'y', 'on', '1'}.contains(fd.trim().toLowerCase())),
    );
  }

  /// يحلل عمود bulk_tiers (jsonb). يرجع الدرجات مرتبة تصاعدياً حسب الكمية.
  static List<BulkTier> parseList(dynamic raw) {
    if (raw is! List) return const [];
    final tiers = raw.map(tryParse).whereType<BulkTier>().toList()
      ..sort((a, b) => a.qty.compareTo(b.qty));
    return List.unmodifiable(tiers);
  }

  static List<BulkTier> ofProduct(Map<String, dynamic>? product) => parseList(product?['bulk_tiers']);

  /// مثال: "3 قطع بـ 15,000 د.ع + توصيل مجاني"
  String label({bool withFreeDelivery = true}) =>
      '${piecesLabel(qty)} بـ ${_money.format(price)} د.ع'
      '${freeDelivery && withFreeDelivery ? ' + توصيل مجاني' : ''}';
}

/// "قطعة وحدة" / "قطعتين" / "3 قطع" / "12 قطعة"
String piecesLabel(int n) => switch (n) {
      1 => 'قطعة وحدة',
      2 => 'قطعتين',
      <= 10 => '$n قطع',
      _ => '$n قطعة',
    };

// ============================================================================
// أسعار القطعة حسب العدد (unit_tiers): إذا مجموع القطع وصل min، كل القطع بسعر الدرجة.
// نسخة للعرض من private.unit_for_qty بالسيرفر. المنتج الي بيه باقات (bulk_tiers) يبقى على الباقات.

/// لون سطر "مكس ألوان": الموظفة تختار الألوان، والسيرفر يقبله لكل منتج بيه ألوان.
const String kMixColor = 'مكس ألوان';

class UnitTier {
  const UnitTier({required this.min, this.pct, this.price, this.mix = false, this.freeDelivery = false});

  final int min;
  final double? pct;
  final double? price;

  /// درجة "مكس ألوان" (تنطبق على قطع المكس بس)
  final bool mix;

  /// إذا العدد وصل هاي الدرجة، التوصيل مجاني
  final bool freeDelivery;

  static final RegExp _intRe = RegExp(r'^[0-9]+$');
  static final RegExp _numRe = RegExp(r'^[0-9]+(\.[0-9]+)?$');

  static UnitTier? tryParse(dynamic raw) {
    if (raw is! Map) return null;
    final minText = '${raw['min'] ?? ''}';
    if (!_intRe.hasMatch(minText)) return null;
    final min = int.parse(minText);
    if (min <= 1) return null;
    final priceText = '${raw['price'] ?? ''}';
    final pctText = '${raw['pct'] ?? ''}';
    final price = _numRe.hasMatch(priceText) ? double.parse(priceText) : null;
    final pct = _numRe.hasMatch(pctText) ? double.parse(pctText) : null;
    if (price == null && pct == null) return null;
    final mx = raw['mix'];
    final fd = raw['free_delivery'];
    return UnitTier(
      min: min,
      pct: pct,
      price: price,
      mix: mx == true || mx == 'true',
      freeDelivery: fd == true || fd == 'true',
    );
  }

  static List<UnitTier> parseList(dynamic raw) {
    if (raw is! List) return const [];
    final out = raw.map(tryParse).whereType<UnitTier>().toList()..sort((a, b) => a.min.compareTo(b.min));
    return List.unmodifiable(out);
  }

  static List<UnitTier> ofProduct(Map<String, dynamic>? product) => parseList(product?['unit_tiers']);

  /// سعر القطعة بهاي الدرجة (الخصم يتقرّب لأقرب 250 مثل السيرفر)
  double unitPrice(double base) {
    if (price != null) return price!;
    return ((base * (100 - pct!) / 100) / 250).round() * 250.0;
  }
}

/// المنتج يتحسب بأسعار القطعة حسب العدد (مو باقات)
bool usesUnitTiers(Map<String, dynamic>? product) =>
    BulkTier.ofProduct(product).isEmpty && UnitTier.ofProduct(product).any((t) => !t.mix);

/// سعر القطعة لعدد [qty]: أعلى درجة وصلها العدد، أو السعر العادي.
double unitForQty(double base, List<UnitTier> tiers, int qty, {bool mix = false}) {
  UnitTier? best;
  double? bestPrice;
  for (final t in tiers) {
    if (t.mix != mix || t.min > qty) continue;
    final u = t.unitPrice(base);
    if (u <= 0 || u >= base) continue;
    if (best == null || t.min > best.min || (t.min == best.min && u < bestPrice!)) {
      best = t;
      bestPrice = u;
    }
  }
  return bestPrice ?? base;
}

/// التوصيل مجاني إذا العدد (أو عدد المكس) وصل درجة عليها free_delivery
bool unitFreeDelivery(List<UnitTier> tiers, int qty, int mixQty) =>
    tiers.any((t) => t.freeDelivery && t.min <= (t.mix ? mixQty : qty));

/// درجات العرض بالترتيب: (من، إلى أو null، سعر القطعة). أول خانة السعر العادي.
List<(int, int?, double)> unitTierCells(double base, List<UnitTier> tiers) {
  final steps = <int, double>{};
  for (final t in tiers.where((t) => !t.mix)) {
    final u = t.unitPrice(base);
    if (u <= 0 || u >= base) continue;
    steps[t.min] = steps.containsKey(t.min) ? (u < steps[t.min]! ? u : steps[t.min]!) : u;
  }
  final mins = steps.keys.toList()..sort();
  final cells = <(int, int?, double)>[(1, mins.isEmpty ? null : mins.first - 1, base)];
  for (var i = 0; i < mins.length; i++) {
    cells.add((mins[i], i + 1 < mins.length ? mins[i + 1] - 1 : null, steps[mins[i]]!));
  }
  return cells;
}

/// درجة المكس: (أقل عدد، سعر القطعة) أو null
(int, double)? mixTierOf(double base, List<UnitTier> tiers) {
  (int, double)? best;
  for (final t in tiers.where((t) => t.mix)) {
    final u = t.unitPrice(base);
    if (u <= 0 || u >= base) continue;
    if (best == null || t.min < best.$1) best = (t.min, u);
  }
  return best;
}

class BulkQuote {
  const BulkQuote({
    required this.qty,
    required this.total,
    required this.regularTotal,
    required this.freeDelivery,
    required this.packs,
  });

  final int qty;

  /// السعر الكلي بعد العرض.
  final double total;

  /// السعر بدون عرض (سعر القطعة × الكمية).
  final double regularTotal;

  final bool freeDelivery;

  /// عدد الباقات المطبّقة من كل درجة.
  final Map<BulkTier, int> packs;

  double get saving => regularTotal > total ? regularTotal - total : 0;
  bool get applied => packs.isNotEmpty || total < regularTotal;
}

/// سعر كمية معينة من منتج واحد (كل الألوان مجموعة).
/// باقات من الأكبر للأصغر، والباقي بسعر القطعة العادي — نفس private.bulk_price.
BulkQuote quoteBulk({required double unitPrice, required List<BulkTier> tiers, required int qty}) {
  var rem = qty < 0 ? 0 : qty;
  var total = 0.0;
  var free = false;
  final packs = <BulkTier, int>{};

  for (final tier in tiers.reversed) {
    if (rem >= tier.qty) {
      final n = rem ~/ tier.qty;
      total += n * tier.price;
      rem %= tier.qty;
      packs[tier] = n;
      if (tier.freeDelivery) free = true;
    }
  }
  total += rem * unitPrice;

  final safeQty = qty < 0 ? 0 : qty;
  return BulkQuote(
    qty: safeQty,
    total: total,
    regularTotal: unitPrice * safeQty,
    freeDelivery: free,
    packs: packs,
  );
}

BulkQuote quoteProduct(Map<String, dynamic> product, int qty, {int mixQty = 0}) {
  final unit = (product['price'] as num?)?.toDouble() ?? 0;
  if (usesUnitTiers(product)) {
    final tiers = UnitTier.ofProduct(product);
    final safe = qty < 0 ? 0 : qty;
    final m = mixQty.clamp(0, safe);
    final u = unitForQty(unit, tiers, safe);
    final mu = unitForQty(unit, tiers, m, mix: true);
    final total = (safe - m) * u + m * (mu < u ? mu : u);
    return BulkQuote(
      qty: safe,
      total: total,
      regularTotal: unit * safe,
      freeDelivery: unitFreeDelivery(tiers, safe, m),
      packs: const {},
    );
  }
  return quoteBulk(unitPrice: unit, tiers: BulkTier.ofProduct(product), qty: qty);
}

/// مفتاح التجميع لعروض الكمية: منتجات بنفس offer_group تتجمع قطعها سوى، وغيرها كل منتج لحاله.
/// نفس private.cart_price بالسيرفر.
String offerGroupKey(int productId, Map<String, dynamic>? product) {
  final group = (product?['offer_group'] ?? '').toString().trim();
  return group.isEmpty ? 'p:$productId' : 'g:$group';
}

class CartQuote {
  const CartQuote({
    required this.byProduct,
    required this.qtyByProduct,
    this.groupKeyByProduct = const {},
    this.qtyByGroup = const {},
  });

  final Map<int, BulkQuote> byProduct;
  final Map<int, int> qtyByProduct;
  final Map<int, String> groupKeyByProduct;
  final Map<String, int> qtyByGroup;

  /// مجموع قطع مجموعة العرض الي بيها المنتج (أو قطع المنتج نفسه إذا بدون مجموعة).
  int groupQtyFor(int productId) =>
      qtyByGroup[groupKeyByProduct[productId]] ?? qtyByProduct[productId] ?? 0;

  double get subtotal => byProduct.values.fold(0.0, (s, q) => s + q.total);
  double get regularSubtotal => byProduct.values.fold(0.0, (s, q) => s + q.regularTotal);
  double get saving => byProduct.values.fold(0.0, (s, q) => s + q.saving);

  /// إذا أي منتج وصل درجة عليها توصيل مجاني، التوصيل صفر على الطلب كله.
  bool get freeDelivery => byProduct.values.any((q) => q.freeDelivery);

  /// حصة سطر واحد (لون واحد) من سعر المنتج بعد العرض.
  double lineTotal(CartLine line) {
    final quote = byProduct[line.productId];
    final qty = qtyByProduct[line.productId] ?? 0;
    if (quote == null || qty == 0) return 0;
    return quote.total * line.quantity / qty;
  }

  double lineRegularTotal(CartLine line) {
    final quote = byProduct[line.productId];
    final qty = qtyByProduct[line.productId] ?? 0;
    if (quote == null || qty == 0) return 0;
    return quote.regularTotal * line.quantity / qty;
  }
}

/// مجموع السلة كاملة: كمية كل منتج تتجمع عبر ألوانه، ومنتجات نفس "مجموعة العرض" تتجمع سوى،
/// ثم يتحسب العرض على المجموع. نسخة للعرض فقط من private.cart_price بالسيرفر:
/// - المجموعة تستخدم درجات أول منتج بيها (أصغر id).
/// - القطع الداخلة بالباقات من الأغلى للأرخص، وسعر الباقات يتوزع حسب السعر العادي
///   (التقريب لأقرب دينار، والفرق على آخر منتج).
/// المنتجات غير الموجودة بـ [products] ما تنحسب (السيرفر يرفض الطلب بكل الأحوال).
CartQuote quoteCart(List<CartLine> lines, Map<int, Map<String, dynamic>> products) {
  final qtyByProduct = <int, int>{};
  final mixByProduct = <int, int>{};
  for (final line in lines) {
    qtyByProduct[line.productId] = (qtyByProduct[line.productId] ?? 0) + line.quantity;
    if (line.color == kMixColor) {
      mixByProduct[line.productId] = (mixByProduct[line.productId] ?? 0) + line.quantity;
    }
  }

  double priceOf(int id) => (products[id]?['price'] as num?)?.toDouble() ?? 0;

  final groups = <String, List<int>>{};
  final groupKeyByProduct = <int, String>{};
  for (final id in qtyByProduct.keys) {
    if (products[id] == null) continue;
    final key = offerGroupKey(id, products[id]);
    groupKeyByProduct[id] = key;
    groups.putIfAbsent(key, () => []).add(id);
  }

  final byProduct = <int, BulkQuote>{};
  final qtyByGroup = <String, int>{};
  for (final entry in groups.entries) {
    final ids = entry.value
      ..sort((a, b) {
        final byPrice = priceOf(b).compareTo(priceOf(a));
        return byPrice != 0 ? byPrice : a.compareTo(b);
      });
    final tiersOwner = ids.reduce((a, b) => a < b ? a : b);
    final tiers = BulkTier.ofProduct(products[tiersOwner]);
    final totalQty = ids.fold(0, (s, id) => s + qtyByProduct[id]!);
    qtyByGroup[entry.key] = totalQty;

    // بدون باقات: كل القطع بسعر الدرجة حسب عدد المجموعة، وقطع المكس 12+ بسعر المكس
    if (tiers.isEmpty) {
      final groupMix = ids.fold(0, (s, id) => s + (mixByProduct[id] ?? 0).clamp(0, qtyByProduct[id]!));
      for (final id in ids) {
        final qty = qtyByProduct[id]!;
        final m = (mixByProduct[id] ?? 0).clamp(0, qty);
        final ut = UnitTier.ofProduct(products[id]);
        final u = unitForQty(priceOf(id), ut, totalQty);
        final mu = unitForQty(priceOf(id), ut, groupMix, mix: true);
        byProduct[id] = BulkQuote(
          qty: qty,
          total: (qty - m) * u + m * (mu < u ? mu : u),
          regularTotal: priceOf(id) * qty,
          freeDelivery: unitFreeDelivery(ut, totalQty, groupMix),
          packs: const {},
        );
      }
      continue;
    }

    // الباقات على مجموع القطع (بسعر قطعة صفر حتى total = سعر الباقات بس)
    final packsQuote = quoteBulk(unitPrice: 0, tiers: tiers, qty: totalQty);
    final packedUnits = packsQuote.packs.entries.fold(0, (s, e) => s + e.key.qty * e.value);

    // توزيع القطع الداخلة بالباقات: من الأغلى للأرخص
    var left = packedUnits;
    final packed = <int, int>{};
    var packedRegular = 0.0;
    var lastPacked = -1;
    for (final id in ids) {
      final take = qtyByProduct[id]! < left ? qtyByProduct[id]! : left;
      packed[id] = take;
      left -= take;
      packedRegular += take * priceOf(id);
      if (take > 0) lastPacked = id;
    }

    var shared = 0.0;
    for (final id in ids) {
      final qty = qtyByProduct[id]!;
      final p = packed[id]!;
      double share;
      if (p == 0) {
        share = 0;
      } else if (id == lastPacked) {
        share = packsQuote.total - shared;
      } else if (packedRegular > 0) {
        share = (packsQuote.total * p * priceOf(id) / packedRegular).roundToDouble();
      } else {
        share = (packsQuote.total * p / (packedUnits > 0 ? packedUnits : 1)).roundToDouble();
      }
      shared += share;
      byProduct[id] = BulkQuote(
        qty: qty,
        total: share + (qty - p) * priceOf(id),
        regularTotal: priceOf(id) * qty,
        freeDelivery: packsQuote.freeDelivery,
        packs: packsQuote.packs,
      );
    }
  }

  // عروض "توصيل مجاني": إذا مجموع قطع منتجات العرض وصل العدد، كلهم توصيلهم مجاني (نفس private.cart_price)
  final fdQty = <int, int>{};
  final fdNeed = <int, int>{};
  for (final id in qtyByProduct.keys) {
    final fd = products[id]?['_fd_offer'];
    if (fd is Map) {
      final oid = (fd['id'] as num).toInt();
      fdQty[oid] = (fdQty[oid] ?? 0) + qtyByProduct[id]!;
      fdNeed[oid] = (fd['qty'] as num).toInt();
    }
  }
  for (final id in qtyByProduct.keys) {
    final fd = products[id]?['_fd_offer'];
    final q = byProduct[id];
    if (fd is! Map || q == null || q.freeDelivery) continue;
    final oid = (fd['id'] as num).toInt();
    if ((fdQty[oid] ?? 0) >= (fdNeed[oid] ?? 1 << 30)) {
      byProduct[id] = BulkQuote(
        qty: q.qty,
        total: q.total,
        regularTotal: q.regularTotal,
        freeDelivery: true,
        packs: q.packs,
      );
    }
  }

  return CartQuote(
    byProduct: byProduct,
    qtyByProduct: qtyByProduct,
    groupKeyByProduct: groupKeyByProduct,
    qtyByGroup: qtyByGroup,
  );
}

class BulkHint {
  const BulkHint({required this.missing, required this.tier});

  /// كم قطعة ناقصة.
  final int missing;

  /// الدرجة الي راح تنفتح.
  final BulkTier tier;
}

/// أقل عدد قطع لازم تنضاف حتى تنفتح باقة جديدة (أرخص أو بيها توصيل مجاني).
/// [maxQty] حد المخزون، ويرجع null إذا ماكو درجة قريبة ممكنة.
BulkHint? nextBulkHint({
  required double unitPrice,
  required List<BulkTier> tiers,
  required int qty,
  int? maxQty,
}) {
  if (tiers.isEmpty) return null;
  final current = quoteBulk(unitPrice: unitPrice, tiers: tiers, qty: qty);
  final maxStep = tiers.last.qty;

  for (var n = 1; n <= maxStep; n++) {
    final target = qty + n;
    if (maxQty != null && target > maxQty) return null;
    final next = quoteBulk(unitPrice: unitPrice, tiers: tiers, qty: target);
    final cheaper = next.total < current.total + n * unitPrice;
    final unlocksFree = next.freeDelivery && !current.freeDelivery;
    if (!cheaper && !unlocksFree) continue;

    // الدرجة الأكبر الي زادت باقاتها
    BulkTier? unlocked;
    for (final tier in tiers.reversed) {
      if ((next.packs[tier] ?? 0) > (current.packs[tier] ?? 0)) {
        unlocked = tier;
        break;
      }
    }
    if (unlocked != null) return BulkHint(missing: n, tier: unlocked);
  }
  return null;
}

BulkHint? nextBulkHintForProduct(Map<String, dynamic> product, int qty) {
  if (usesUnitTiers(product)) {
    final base = (product['price'] as num?)?.toDouble() ?? 0;
    final tiers = UnitTier.ofProduct(product);
    final maxQty = (product['stock'] as num?)?.toInt();
    final current = unitForQty(base, tiers, qty);
    final mins = tiers.where((t) => !t.mix && t.min > qty).map((t) => t.min).toSet().toList()..sort();
    for (final m in mins) {
      if (maxQty != null && m > maxQty) return null;
      final u = unitForQty(base, tiers, m);
      if (u < current) return BulkHint(missing: m - qty, tier: BulkTier(qty: m, price: u * m));
    }
    return null;
  }
  return _nextPackHint(product, qty);
}

BulkHint? _nextPackHint(Map<String, dynamic> product, int qty) => nextBulkHint(
      unitPrice: (product['price'] as num?)?.toDouble() ?? 0,
      tiers: BulkTier.ofProduct(product),
      qty: qty,
      maxQty: (product['stock'] as num?)?.toInt(),
    );
