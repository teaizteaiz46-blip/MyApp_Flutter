import 'package:flutter/foundation.dart';

import '../main.dart';

/// المفضلة (مرتبطة بالحساب): إذا نزل سعر قطعة أو رجعت متوفرة، يوصل إشعار.
class WishlistService {
  WishlistService._();
  static final WishlistService instance = WishlistService._();

  final ValueNotifier<Set<int>> ids = ValueNotifier(const {});

  bool get signedIn => supabase.auth.currentUser != null;

  bool contains(int productId) => ids.value.contains(productId);

  Future<void> refresh() async {
    if (!signedIn) {
      ids.value = const {};
      return;
    }
    try {
      final rows = await supabase.from('wishlist').select('product_id');
      ids.value = {for (final r in rows) (r['product_id'] as num).toInt()};
    } catch (e) {
      debugPrint('Wishlist refresh failed: $e');
    }
  }

  /// يضيف أو يشيل، ويرجع الحالة الجديدة (true = بالمفضلة)
  Future<bool> toggle(int productId) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) throw StateError('login');
    final had = contains(productId);
    // نحدث الشاشة فوراً، ونرجّعها إذا فشل
    ids.value = had ? ({...ids.value}..remove(productId)) : ({...ids.value}..add(productId));
    try {
      if (had) {
        await supabase.from('wishlist').delete().eq('product_id', productId);
      } else {
        await supabase.from('wishlist').insert({'user_id': uid, 'product_id': productId});
      }
      return !had;
    } catch (e) {
      ids.value = had ? ({...ids.value}..add(productId)) : ({...ids.value}..remove(productId));
      rethrow;
    }
  }

  void clear() => ids.value = const {};
}
