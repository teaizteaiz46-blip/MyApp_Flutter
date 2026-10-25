import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/offline_cache.dart';
import '../main.dart';
import '../screens/splash/splash_ad_screen.dart';
import 'deep_link_service.dart';

/// إعلان الافتتاح (جدول splash_ads): صورة كاملة تطلع لما ينفتح التطبيق.
///
/// - الإعلان والصورة يتحضرون مسبقاً (آخر مرة انفتح التطبيق)، فيطلع فوراً بدون انتظار.
/// - ما يطلع إذا ماكو إعلان محفوظ، أو الصورة بعدها ما نزلت، أو ما مرت ساعات كافية من آخر مرة،
///   أو الزبونة جاية من رابط/إشعار.
/// - كل مرة نجيب الإعلان الحالي من السيرفر ونحفظه للمرة الجاية.
class SplashAdService {
  SplashAdService._();

  static const String _adKey = 'splash_ad_v1';
  static const String _shownKey = 'splash_shown_at_v1';

  static Route<void>? _route;

  /// true والإعلان ظاهر (نافذة كوبون الترحيب تنتظره يخلص)
  static final ValueNotifier<bool> showing = ValueNotifier(false);

  static Future<void> run(GlobalKey<NavigatorState> navigatorKey) async {
    if (kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = _decode(prefs.getString(_adKey));
      // نحدث للمرة الجاية بالخلفية
      unawaited(_refresh(prefs));
      if (cached == null || !_isLive(cached)) return;

      final hours = (cached['min_hours_between'] as num?)?.toInt() ?? 6;
      final lastShown = DateTime.tryParse(prefs.getString(_shownKey) ?? '');
      if (lastShown != null && DateTime.now().difference(lastShown).inMinutes < hours * 60) return;

      // الصورة لازم تكون نازلة بالجهاز، وإلا ما نأخر فتح التطبيق
      final file = await kImageCache.getFileFromCache('${cached['image_url']}');
      if (file == null) return;

      // ننطي الرابط/الإشعار فرصة يوصل أول
      await WidgetsBinding.instance.endOfFrame;
      await Future<void>.delayed(const Duration(milliseconds: 350));
      final navigator = navigatorKey.currentState;
      if (navigator == null || DeepLinkService.openedFromLink) return;

      await prefs.setString(_shownKey, DateTime.now().toIso8601String());
      final route = PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (_, _, _) => SplashAdScreen(ad: cached, imageFile: file.file, onClose: _close, onOpen: _openLink),
        transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
      );
      _route = route;
      showing.value = true;
      DeepLinkService.onExternalOpen = _close;
      unawaited(navigator.push(route).whenComplete(() {
        if (identical(_route, route)) _route = null;
        showing.value = false;
        if (DeepLinkService.onExternalOpen == _close) DeepLinkService.onExternalOpen = null;
      }));
    } catch (e) {
      debugPrint('Splash ad failed: $e');
    }
  }

  /// يشيل الإعلان من مكانه بالضبط، حتى لو انفتح فوقه منتج من رابط
  static void _close() {
    final route = _route;
    _route = null;
    if (route == null) return;
    final nav = route.navigator;
    if (nav != null && route.isActive) nav.removeRoute(route);
  }

  static void _openLink(Widget target) {
    final route = _route;
    final nav = route?.navigator;
    _close();
    nav?.push(MaterialPageRoute(builder: (_) => target));
  }

  static Future<void> _refresh(SharedPreferences prefs) async {
    try {
      final rows = await supabase
          .from('splash_ads')
          .select('id, image_url, link_type, link_value, button_text, duration_sec, min_hours_between, starts_at, ends_at')
          .order('sort_order', ascending: true)
          .order('created_at', ascending: false)
          .limit(1);
      if (rows.isEmpty) {
        await prefs.remove(_adKey);
        return;
      }
      final ad = rows.first;
      // ننزّل الصورة هسه حتى تكون جاهزة المرة الجاية
      await kImageCache.downloadFile('${ad['image_url']}');
      await prefs.setString(_adKey, jsonEncode(ad));
    } catch (e) {
      debugPrint('Splash ad refresh failed: $e');
    }
  }

  static Map<String, dynamic>? _decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return (jsonDecode(raw) as Map).cast<String, dynamic>();
    } catch (_) {
      return null;
    }
  }

  /// الإعلان المحفوظ ممكن يكون انتهى وقته من آخر مرة
  static bool _isLive(Map<String, dynamic> ad) {
    final now = DateTime.now();
    final starts = DateTime.tryParse('${ad['starts_at'] ?? ''}');
    final ends = DateTime.tryParse('${ad['ends_at'] ?? ''}');
    if (starts != null && starts.isAfter(now)) return false;
    if (ends != null && !ends.isAfter(now)) return false;
    return '${ad['image_url'] ?? ''}'.isNotEmpty;
  }
}
