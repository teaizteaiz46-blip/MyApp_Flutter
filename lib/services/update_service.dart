import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_config.dart';

/// التحديث الإجباري (يتشغل من صفحة الأدمن، store_settings.force_update_on):
/// - أندرويد: Google Play In-app updates. إذا اكو نسخة أحدث بالمتجر يطلع تحديث كامل الشاشة.
/// - آيفون: نقارن نسختنا بنسخة الـ App Store (iTunes lookup). مراجع Apple نسخته دائماً أحدث، فما ينحبس.
/// - احتياط: أقل رقم بناء لكل نظام (min_build_android / min_build_ios).
/// إذا ماكو نت أو المتجر ما رد، ما نحبس أحد.
class UpdateService {
  UpdateService._();

  static const String playUrl = 'https://play.google.com/store/apps/details?id=iq.ameerazax.velin';
  static const String _iosBundleId = 'com.ameeralali.myapprun';
  static const String _appStoreFallback = 'https://apps.apple.com/app/id6754703322';

  /// true = الزبون لازم يحدّث (MyApp تغطي التطبيق بشاشة التحديث)
  static final ValueNotifier<bool> required = ValueNotifier<bool>(false);

  static String _storeUrl = _appStoreFallback;
  static DateTime? _checkedAt;
  static bool _checking = false;
  // ignore: unused_field
  static AppLifecycleListener? _lifecycle;

  static bool get _android => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static bool get _ios => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// أول فحص بعد فتح التطبيق، وبعدين كل ما يرجع للتطبيق (كل 30 دقيقة بالكثير)
  static void init() {
    if (!_android && !_ios) return;
    unawaited(check());
    _lifecycle = AppLifecycleListener(onResume: () {
      final stale = _checkedAt == null || DateTime.now().difference(_checkedAt!) > const Duration(minutes: 30);
      if (stale || required.value) unawaited(check());
    });
  }

  static Future<void> check() async {
    if (_checking) return;
    _checking = true;
    try {
      await AppConfig.refresh();
      final info = await PackageInfo.fromPlatform();
      final build = int.tryParse(info.buildNumber) ?? 0;
      final minBuild = _android ? AppConfig.minBuildAndroid : AppConfig.minBuildIos;
      var mustUpdate = minBuild != null && build > 0 && build < minBuild;

      if (!mustUpdate && AppConfig.forceUpdate) {
        if (_android) {
          mustUpdate = await _playHasUpdate();
        } else if (_ios) {
          mustUpdate = await _appStoreIsNewer(info.version);
        }
      }
      _checkedAt = DateTime.now();
      required.value = mustUpdate;
      // أندرويد: نفتح تحديث Google مباشرة (إذا الزبون رجع منه تبقى شاشتنا)
      if (mustUpdate && _android) unawaited(_startPlayUpdate());
    } catch (e) {
      debugPrint('UpdateService.check: $e');
    } finally {
      _checking = false;
    }
  }

  static Future<bool> _playHasUpdate() async {
    try {
      final info = await InAppUpdate.checkForUpdate();
      return info.updateAvailability == UpdateAvailability.updateAvailable ||
          info.updateAvailability == UpdateAvailability.developerTriggeredUpdateInProgress;
    } catch (_) {
      return false; // مو منزّل من Google Play (أو نسخة تجربة)
    }
  }

  static Future<void> _startPlayUpdate() async {
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.immediateUpdateAllowed) await InAppUpdate.performImmediateUpdate();
    } catch (_) {}
  }

  /// نسخة الـ App Store أحدث من نسختنا؟ (متجر العراق أول، وإذا ما لگاه الافتراضي)
  static Future<bool> _appStoreIsNewer(String current) async {
    for (final country in const ['iq', '']) {
      try {
        final uri = Uri.https('itunes.apple.com', '/lookup', {
          'bundleId': _iosBundleId,
          if (country.isNotEmpty) 'country': country,
          't': '${DateTime.now().millisecondsSinceEpoch ~/ 60000}',
        });
        final res = await http.get(uri).timeout(const Duration(seconds: 8));
        if (res.statusCode != 200) continue;
        final results = (jsonDecode(res.body) as Map)['results'] as List? ?? const [];
        if (results.isEmpty) continue;
        final app = Map<String, dynamic>.from(results.first as Map);
        final url = (app['trackViewUrl'] ?? '').toString();
        if (url.isNotEmpty) _storeUrl = url;
        return isNewerVersion((app['version'] ?? '').toString(), current);
      } catch (_) {
        continue;
      }
    }
    return false;
  }

  /// زر "حدّث الآن"
  static Future<void> openStore() async {
    if (_android) {
      try {
        final info = await InAppUpdate.checkForUpdate();
        if (info.immediateUpdateAllowed) {
          await InAppUpdate.performImmediateUpdate();
          return;
        }
      } catch (_) {}
    }
    final url = Uri.parse(_android ? playUrl : _storeUrl);
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }
}

/// "2.0.10" أحدث من "2.0.9"؟ (أرقام مفصولة بنقاط، والناقص يعتبر 0)
@visibleForTesting
bool isNewerVersion(String store, String current) {
  List<int> parts(String v) => v.trim().split('.').map((p) => int.tryParse(p.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0).toList();
  final a = parts(store), b = parts(current);
  if (store.trim().isEmpty) return false;
  for (var i = 0; i < (a.length > b.length ? a.length : b.length); i++) {
    final x = i < a.length ? a[i] : 0, y = i < b.length ? b[i] : 0;
    if (x != y) return x > y;
  }
  return false;
}
