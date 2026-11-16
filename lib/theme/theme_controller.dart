import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// مظهر التطبيق (ليلي / فاتح / حسب الموبايل). الاختيار ينحفظ بالجهاز بس.
/// إذا الزبون بعده ما اختار شي، التطبيق ليلي.
class ThemeController {
  ThemeController._();

  static const String _key = 'app_theme_mode_v1';

  /// الوضع الحالي (MaterialApp يسمعه ويتبدل فوراً بدون إعادة تشغيل)
  static final ValueNotifier<ThemeMode> mode = ValueNotifier(ThemeMode.dark);

  static bool _saved = false;

  /// الزبون اختار المظهر قبل (شاشة الاختيار أو حسابي ← المظهر)
  static bool get hasChoice => _saved;

  /// يقرا الاختيار المحفوظ قبل ما تنبني الواجهة (حتى ما يطلع وميض أبيض)
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = parse(prefs.getString(_key));
      if (saved != null) {
        mode.value = saved;
        _saved = true;
      }
    } catch (e) {
      debugPrint('Theme init failed: $e');
    }
  }

  /// يبدّل ويحفظ
  static Future<void> choose(ThemeMode value) async {
    mode.value = value;
    _saved = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, value.name);
    } catch (e) {
      debugPrint('Theme save failed: $e');
    }
  }

  /// يبدّل بدون حفظ (معاينة بشاشة الاختيار)
  static void preview(ThemeMode value) => mode.value = value;

  /// يرجع للمحفوظ (أو الليلي إذا ماكو اختيار)
  static Future<void> revert() async {
    mode.value = ThemeMode.dark;
    _saved = false;
    await init();
  }

  static ThemeMode? parse(String? value) {
    for (final m in ThemeMode.values) {
      if (m.name == value) return m;
    }
    return null;
  }

  /// اسم الوضع بالواجهة
  static String label(ThemeMode value) => switch (value) {
        ThemeMode.dark => 'ليلي',
        ThemeMode.light => 'فاتح',
        ThemeMode.system => 'حسب إعداد الموبايل',
      };

  @visibleForTesting
  static void debugReset() {
    mode.value = ThemeMode.dark;
    _saved = false;
  }
}
