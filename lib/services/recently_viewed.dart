import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// "شفتيها مؤخراً": آخر المنتجات الي انفتحت، محفوظة على الجهاز بس (ما تنرسل لأي مكان).
class RecentlyViewed {
  RecentlyViewed._();
  static final RecentlyViewed instance = RecentlyViewed._();

  static const String _key = 'recently_viewed_v1';
  static const int _max = 15;

  /// الأحدث أولاً
  final ValueNotifier<List<int>> ids = ValueNotifier(const []);
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      ids.value = (prefs.getStringList(_key) ?? const []).map(int.tryParse).whereType<int>().toList();
    } catch (e) {
      debugPrint('RecentlyViewed load failed: $e');
    }
  }

  Future<void> add(int productId) async {
    await load();
    final next = [productId, ...ids.value.where((id) => id != productId)].take(_max).toList();
    ids.value = next;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, next.map((e) => '$e').toList());
    } catch (e) {
      debugPrint('RecentlyViewed save failed: $e');
    }
  }
}
