import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';

typedef Rows = List<Map<String, dynamic>>;

/// كاش الصور على الجهاز: الصورة تنزل مرة وحدة وبعدها تفتح من الذاكرة حتى بدون إنترنت.
/// صور المنتجات تترفع بمسار جديد كل مرة، فأي صورة تتبدل تنزل من جديد تلقائياً.
final CacheManager kImageCache = CacheManager(Config(
  'modo_images',
  stalePeriod: const Duration(days: 60),
  maxNrOfCacheObjects: 1500,
));

/// صورة من الإنترنت تنحفظ بالجهاز. استخدمها بدل `Image.network`: `Image(image: cachedImage(url))`.
ImageProvider cachedImage(String url) => CachedNetworkImageProvider(url, cacheManager: kImageCache);

/// كاش البيانات (stale-while-revalidate):
/// يرجّع آخر نسخة محفوظة فوراً، وبنفس الوقت يجيب الجديد من السيرفر ويحفظه،
/// وإذا تغيّر شي يبلّغ الشاشة عبر [onFresh] حتى تتحدث.
///
/// للعرض فقط: السلة وإتمام الطلب يجيبون الأسعار من السيرفر مباشرة.
class OfflineCache {
  OfflineCache._();

  /// غيّرها إذا تغيّر شكل البيانات المحفوظة (مثلاً أعمدة جديدة) حتى ينمسح الكاش القديم.
  static const String _version = 'v1';

  static Future<Directory>? _dirFuture;

  static Future<Directory> _dir() => _dirFuture ??= () async {
        final base = await getApplicationSupportDirectory();
        final dir = Directory('${base.path}/offline_cache/$_version');
        await dir.create(recursive: true);
        return dir;
      }();

  static Future<File> _file(String key) async {
    final safe = key.replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '_');
    return File('${(await _dir()).path}/$safe.json');
  }

  static Future<String?> _readRaw(String key) async {
    try {
      final file = await _file(key);
      if (!await file.exists()) return null;
      return await file.readAsString();
    } catch (e) {
      debugPrint('OfflineCache read $key: $e');
      return null;
    }
  }

  static Future<void> _writeRaw(String key, String raw) async {
    try {
      final file = await _file(key);
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(raw, flush: true);
      await tmp.rename(file.path);
    } catch (e) {
      debugPrint('OfflineCache write $key: $e');
    }
  }

  static Rows? _decode(String? raw) {
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw);
      if (data is! List) return null;
      return [for (final row in data) if (row is Map) Map<String, dynamic>.from(row)];
    } catch (_) {
      return null;
    }
  }

  /// إذا اكو نسخة محفوظة: ترجع فوراً، والتحديث يصير بالخلفية ويوصل عبر [onFresh] (بس إذا تغيّر شي).
  /// إذا ماكو: تنتظر السيرفر، وإذا فشل يطلع الخطأ عادي.
  static Future<Rows> fetch(
    String key,
    Future<Rows> Function() load, {
    void Function(Rows fresh)? onFresh,
  }) async {
    final cachedRaw = await _readRaw(key);
    final cached = _decode(cachedRaw);

    Future<Rows> refresh() async {
      final fresh = await load();
      final raw = jsonEncode(fresh);
      if (raw != cachedRaw) {
        await _writeRaw(key, raw);
        if (cached != null) onFresh?.call(fresh);
      }
      return fresh;
    }

    if (cached == null) return refresh();

    refresh().catchError((Object e) {
      debugPrint('OfflineCache refresh $key: $e');
      return cached;
    });
    return cached;
  }
}
