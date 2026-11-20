import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart' show supabase;

/// إعدادات المتجر من صفحة الأدمن (جدول store_settings، صف واحد id=1):
/// الرئيسية الافتراضية، التحديث الإجباري، والتوصيل المجاني حسب عدد القطع.
/// آخر نسخة تنحفظ بالجهاز حتى تشتغل بدون نت، وتتحدث من السيرفر بالخلفية.
class AppConfig {
  AppConfig._();

  static const String _prefsKey = 'store_settings_v1';
  static const Duration _ttl = Duration(minutes: 3);

  static Map<String, dynamic> _row = const {};
  static DateTime? _fetchedAt;
  static Future<void>? _loading;

  /// يزيد كل ما توصل قيم جديدة من السيرفر (الشاشات تسمعه)
  static final ValueNotifier<int> changes = ValueNotifier<int>(0);

  /// آخر نسخة محفوظة بالجهاز (سريعة، قبل تشغيل الواجهة)
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      if (saved != null) _row = Map<String, dynamic>.from(jsonDecode(saved) as Map);
    } catch (_) {
      // نبقى على القيم الافتراضية
    }
  }

  /// من السيرفر (كل 3 دقايق بالكثير). select('*') حتى ما يتعطل إذا عمود ما موجود بعد.
  static Future<void> refresh({bool force = false}) {
    final fresh = _fetchedAt != null && DateTime.now().difference(_fetchedAt!) < _ttl;
    if (fresh && !force) return Future.value();
    return _loading ??= () async {
      try {
        final row = await supabase.from('store_settings').select().eq('id', 1).maybeSingle();
        if (row != null) {
          _fetchedAt = DateTime.now();
          final encoded = jsonEncode(row);
          if (encoded != jsonEncode(_row)) {
            _row = Map<String, dynamic>.from(row);
            changes.value++;
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_prefsKey, encoded);
          }
        }
      } catch (_) {
        // ماكو نت: نبقى على آخر نسخة
      } finally {
        _loading = null;
      }
    }();
  }

  static int? _int(String key) => (_row[key] as num?)?.toInt();

  /// القسم الافتراضي بالرئيسية (0 = الكل)
  static int get homeCategory => _int('home_default_category') ?? 0;

  /// الترتيب الافتراضي: bestSelling, newest, cheapest, bulkOffers, mix
  static String get homeSort => (_row['home_default_sort'] ?? 'bestSelling').toString();

  /// إجبار الزبائن على آخر نسخة من المتجر
  static bool get forceUpdate => _row['force_update_on'] == true;

  /// أقل رقم بناء مسموح (احتياط من الأدمن)
  static int? get minBuildAndroid => _int('min_build_android');
  static int? get minBuildIos => _int('min_build_ios');

  /// توصيل مجاني للطلب كله من هذا العدد من القطع، أو null إذا مطفي
  static int? get freeDeliveryPieces {
    final min = _int('free_delivery_min_pieces');
    return _row['free_delivery_pieces_on'] == true && min != null && min > 1 ? min : null;
  }

  /// صف المنتجات بالعرض بدل البانر بالرئيسية (null = مطفي، فيطلع البانر مثل قبل)
  static HomeRowConfig? get homeRow => HomeRowConfig.fromSettings(_row);

  @visibleForTesting
  static void debugSet(Map<String, dynamic> row) {
    _row = Map<String, dynamic>.of(row);
    _fetchedAt = DateTime.now();
    changes.value++;
  }
}

/// إعدادات صف المنتجات بالرئيسية (store_settings.home_row_*، من صفحة الأدمن).
/// المنتجات: إما أحدث المتوفر من قسم، أو منتجات يختارها المدير بالترتيب.
@immutable
class HomeRowConfig {
  const HomeRowConfig({
    required this.title,
    required this.subtitle,
    required this.categoryId,
    required this.productIds,
    required this.limit,
    required this.allCategoryId,
  });

  final String title;
  final String subtitle;

  /// قسم (أحدث منتجاته المتوفرة). null = منتجات مختارة
  final int? categoryId;

  /// منتجات مختارة بالترتيب (لما [categoryId] = null)
  final List<int> productIds;

  /// أكثر عدد بالصف
  final int limit;

  /// "عرض الكل" يفتح هذا القسم. null = نفس منتجات الصف (أو قسمه)
  final int? allCategoryId;

  bool get isPicked => categoryId == null;

  /// يتغير إذا تغيّرت المنتجات، حتى الصف يعيد التحميل وكاشه ينفصل
  String get cacheKey => isPicked ? 'p_${productIds.join('-')}_$limit' : 'c_${categoryId}_$limit';

  static HomeRowConfig? fromSettings(Map<String, dynamic> s) {
    if (s['home_row_on'] != true) return null;
    int? asInt(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}');
    final picked = s['home_row_source'] == 'products';
    final cat = asInt(s['home_row_category_id']);
    final ids = <int>[
      for (final v in (s['home_row_product_ids'] is List ? s['home_row_product_ids'] as List : const []))
        if (asInt(v) case final int id when id > 0) id,
    ];
    if (picked ? ids.isEmpty : (cat == null || cat <= 0)) return null;
    final all = asInt(s['home_row_all_category_id']);
    return HomeRowConfig(
      title: (s['home_row_title'] ?? '').toString().trim(),
      subtitle: (s['home_row_subtitle'] ?? '').toString().trim(),
      categoryId: picked ? null : cat,
      productIds: picked ? ids.toSet().toList() : const [],
      limit: (asInt(s['home_row_limit']) ?? 10).clamp(3, 20),
      allCategoryId: all != null && all > 0 ? all : null,
    );
  }
}
