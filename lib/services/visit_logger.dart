import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';

/// يسجّل فتح المنتج داخل التطبيق بجدول page_visits (نفس جدول صفحة المنتج بالويب)
/// حتى تطلع بشجرة الإعلانات (tree.html).
/// بدون أي معلومة شخصية: رقم المنتج + رقم عشوائي للجهاز بس.
/// ما يأخر فتح الصفحة، وإذا فشل يفشل بصمت. الجدول يسمح بـ insert فقط.
class VisitLogger {
  VisitLogger._();

  static const String _kVisitorId = 'modo_visitor_id';
  static Future<String?>? _visitorFuture;

  /// رقم عشوائي يتخزن بالجهاز حتى نعرف الزائر المكرر.
  static Future<String?> _visitorId() => _visitorFuture ??= () async {
        try {
          final prefs = await SharedPreferences.getInstance();
          var id = prefs.getString(_kVisitorId);
          if (id == null || id.isEmpty) {
            final rnd = Random.secure();
            id = List.generate(16, (_) => rnd.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
            await prefs.setString(_kVisitorId, id);
          }
          return id;
        } catch (_) {
          return null;
        }
      }();

  static String? _clip(String? v, int max) =>
      (v == null || v.isEmpty) ? null : (v.length > max ? v.substring(0, max) : v);

  /// [source]: 'app' (تصفح عادي)، 'meta' (من إعلان فيسبوك/انستغرام)، أو 'deeplink' (رابط منتج ثاني).
  static void productOpened(int productId, {String source = 'app', String? campaign}) {
    if (kIsWeb) return;
    unawaited(() async {
      try {
        await supabase.from('page_visits').insert({
          'event': 'app_view',
          'product_id': productId,
          'utm_source': _clip(source, 100),
          'utm_campaign': _clip(campaign, 200),
          'visitor_id': _clip(await _visitorId(), 64),
        });
      } catch (e) {
        debugPrint('VisitLogger: $e');
      }
    }());
  }
}
