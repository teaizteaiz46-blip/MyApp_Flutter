import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// سطر بالسلة: نفس المنتج بلونين = سطرين منفصلين.
@immutable
class CartLine {
  const CartLine({required this.productId, required this.quantity, this.color});

  final int productId;
  final int quantity;
  final String? color;

  String get key => '$productId|${color ?? ''}';

  CartLine copyWith({int? quantity}) =>
      CartLine(productId: productId, quantity: quantity ?? this.quantity, color: color);

  Map<String, dynamic> toJson() =>
      {'product_id': productId, 'quantity': quantity, 'selected_color': color};

  static CartLine? tryParse(dynamic raw) {
    if (raw is! Map) return null;
    final id = int.tryParse('${raw['product_id']}');
    final qty = int.tryParse('${raw['quantity']}') ?? 1;
    final color = (raw['selected_color'] ?? raw['color'])?.toString().trim();
    if (id == null || qty < 1) return null;
    return CartLine(
      productId: id,
      quantity: qty,
      color: (color == null || color.isEmpty) ? null : color,
    );
  }
}

/// سلة وحدة محفوظة بالجهاز للزائر والمسجّل.
/// أي سلة قديمة محفوظة بالحساب (من النسخ السابقة) تنسحب للجهاز عند تسجيل الدخول.
class CartService {
  CartService._();

  static final CartService instance = CartService._();

  /// نفس المفتاح المستخدم بالنسخ القديمة حتى تبقى سلال الزوار الحالية.
  static const String _storageKey = 'cartMap';
  static const int maxQuantityPerLine = 20;

  final ValueNotifier<List<CartLine>> lines = ValueNotifier<List<CartLine>>(const []);

  Future<void>? _loadFuture;
  Future<void> _queue = Future<void>.value();
  bool _pulling = false;

  int get itemCount => lines.value.fold(0, (sum, line) => sum + line.quantity);

  Future<void> load() => _loadFuture ??= _load();

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    lines.value = List.unmodifiable(_decode(prefs.getString(_storageKey)));
  }

  Future<void> add(int productId, {String? color, int quantity = 1}) {
    final clean = color?.trim();
    return _update((current) => [
          ...current,
          CartLine(
            productId: productId,
            quantity: quantity,
            color: (clean == null || clean.isEmpty) ? null : clean,
          ),
        ]);
  }

  Future<void> setQuantity(CartLine line, int quantity) => _update((current) => [
        for (final l in current)
          if (l.key == line.key) l.copyWith(quantity: quantity) else l,
      ]);

  Future<void> remove(CartLine line) =>
      _update((current) => current.where((l) => l.key != line.key).toList());

  Future<void> clear() => _update((_) => const []);

  /// يسحب سلة الحساب القديمة (جدول cart) للجهاز، وبعدها يمسحها من الحساب.
  Future<void> pullAccountCart() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null || _pulling) return;
    _pulling = true;
    try {
      final rows = await client
          .from('cart')
          .select('id, product_id, quantity, selected_color')
          .eq('user_id', userId);
      if (rows.isEmpty) return;

      final pulled = <CartLine>[];
      for (final row in rows) {
        final line = CartLine.tryParse(row);
        if (line != null) pulled.add(line);
      }
      if (pulled.isNotEmpty) {
        await _update((current) => [...current, ...pulled]);
      }
      final ids = rows.map((r) => r['id']).toList();
      await client.from('cart').delete().inFilter('id', ids);
    } catch (e) {
      debugPrint('pullAccountCart: $e');
    } finally {
      _pulling = false;
    }
  }

  // ---------------------------------------------------------------------------

  Future<void> _update(List<CartLine> Function(List<CartLine> current) change) {
    final op = _queue.then((_) async {
      await load();
      final next = _merge(change(List<CartLine>.of(lines.value)));
      lines.value = List.unmodifiable(next);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _storageKey,
        jsonEncode(next.map((l) => l.toJson()).toList()),
      );
    });
    _queue = op.catchError((Object e) {
      debugPrint('Cart save error: $e');
    });
    return op;
  }

  static List<CartLine> _merge(Iterable<CartLine> input) {
    final byKey = <String, CartLine>{};
    for (final line in input) {
      final total = (byKey[line.key]?.quantity ?? 0) + line.quantity;
      byKey[line.key] = line.copyWith(
        quantity: total > maxQuantityPerLine ? maxQuantityPerLine : total,
      );
    }
    return byKey.values.where((l) => l.quantity > 0).toList();
  }

  static List<CartLine> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      final out = <CartLine>[];
      if (decoded is List) {
        for (final item in decoded) {
          final line = CartLine.tryParse(item);
          if (line != null) out.add(line);
        }
      } else if (decoded is Map) {
        // صيغة قديمة جداً: {"productId": quantity}
        decoded.forEach((key, value) {
          final line = CartLine.tryParse({'product_id': key, 'quantity': value});
          if (line != null) out.add(line);
        });
      }
      return _merge(out);
    } catch (e) {
      debugPrint('Cart decode error: $e');
      return const [];
    }
  }
}
