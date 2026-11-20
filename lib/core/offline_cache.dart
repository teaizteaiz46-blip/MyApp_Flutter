import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
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
///
/// [size]: صور مخزن Supabase تنزل بنسخة أصغر (المصغرة للقوائم، الكبيرة لصفحة المنتج)،
/// وإذا النسخة الصغيرة فشلت لأي سبب تنزل الأصلية وحدها.
///
/// [decodeWidth] (بالبكسل الحقيقي): ترسم الصورة بحجم عرضها بدل حجمها الكامل (لحد 1400 بكسل).
/// يقلل ذاكرة كرت الشاشة هواية بالشبكات والقوائم، ومهم للأجهزة الضعيفة.
ImageProvider cachedImage(String url, {int? decodeWidth, ImageSize size = ImageSize.original}) {
  final sized = sizedImageUrl(url, size);
  final ImageProvider provider = sized == url
      ? CachedNetworkImageProvider(url, cacheManager: kImageCache)
      : SizedNetworkImage(sized, url);
  if (decodeWidth == null || decodeWidth <= 0) return provider;
  return ResizeImage(provider, width: decodeWidth, allowUpscaling: false);
}

/// حجم صورة المنتج حسب مكانها.
enum ImageSize {
  /// القوائم والكروت والسلة (480×640، تقريباً أخف بـ90% من الأصلية)
  thumb,

  /// صفحة المنتج والبانرات والستوري (1080×1440)
  large,

  /// التكبير بكامل الشاشة
  original,
}

const String _objectPrefix = 'https://pajxormplmloivyankji.supabase.co/storage/v1/object/public/';
const String _renderPrefix = 'https://pajxormplmloivyankji.supabase.co/storage/v1/render/image/public/';

/// رابط النسخة الأصغر من صورة بمخزن Supabase (تنعمل بالسيرفر وتنحفظ بالـ CDN).
/// "contain" يصغّر الصورة كاملة بدون قص وما يكبّر الصغيرة. صور من مكان ثاني تبقى مثل ما هي.
String sizedImageUrl(String url, ImageSize size) {
  if (size == ImageSize.original || !url.startsWith(_objectPrefix) || url.contains('?')) return url;
  final path = url.substring(_objectPrefix.length);
  final lower = path.toLowerCase();
  if (lower.endsWith('.gif') || lower.endsWith('.svg')) return url;
  final query = switch (size) {
    ImageSize.thumb => 'width=480&height=640&resize=contain&quality=70',
    _ => 'width=1080&height=1440&resize=contain&quality=75',
  };
  return '$_renderPrefix$path?$query';
}

/// إذا تصغير الصور فشل (مثلاً خلصت حصة الشهر)، نروح للأصلية مباشرة لفترة بدل ما نجرّب كل صورة مرتين.
class SizedImageStatus {
  SizedImageStatus._();

  static const Duration retryAfter = Duration(minutes: 10);
  static DateTime? _downUntil;

  static bool get available => _downUntil == null || DateTime.now().isAfter(_downUntil!);

  static void markFailed() => _downUntil = DateTime.now().add(retryAfter);

  @visibleForTesting
  static void reset() => _downUntil = null;
}

/// صورة بنسخة أصغر، وإذا ما نزلت (أو ما انفتحت) تنزل [original].
@immutable
class SizedNetworkImage extends ImageProvider<SizedNetworkImage> {
  const SizedNetworkImage(this.url, this.original, {this.cacheManager});

  final String url;
  final String original;

  /// للاختبار بس؛ الافتراضي كاش الصور بالجهاز
  final BaseCacheManager? cacheManager;

  BaseCacheManager get _cache => cacheManager ?? kImageCache;

  @override
  Future<SizedNetworkImage> obtainKey(ImageConfiguration configuration) => SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(SizedNetworkImage key, ImageDecoderCallback decode) =>
      MultiFrameImageStreamCompleter(codec: _load(decode), scale: 1.0, debugLabel: url);

  Future<ui.Codec> _load(ImageDecoderCallback decode) async {
    Future<ui.Codec> open(File file) async => decode(await ui.ImmutableBuffer.fromUint8List(await file.readAsBytes()));

    // النسخة الصغيرة محفوظة من قبل؟ تفتح حتى لو التصغير واكف هسه
    final cached = await _cache.getFileFromCache(url);
    if (cached != null) {
      try {
        return await open(cached.file);
      } catch (_) {
        // ملف خربان: نكمل
      }
    }
    if (SizedImageStatus.available) {
      try {
        return await open(await _cache.getSingleFile(url));
      } catch (e) {
        SizedImageStatus.markFailed();
        debugPrint('Sized image failed, using the original: $e');
      }
    }
    return open(await _cache.getSingleFile(original));
  }

  @override
  bool operator ==(Object other) => other is SizedNetworkImage && other.url == url && other.original == original;

  @override
  int get hashCode => Object.hash(url, original);

  @override
  String toString() => 'SizedNetworkImage($url)';
}

/// عرض الرسم المناسب لمساحة [logical] بكسل منطقي: نستخدم الضلع الأكبر حتى BoxFit.cover
/// يبقى حاد للصور المربعة والطولية.
int? decodeWidthFor(BuildContext context, double width, double height) {
  final side = width > height ? width : height;
  if (!side.isFinite || side <= 0) return null;
  return (side * MediaQuery.devicePixelRatioOf(context)).ceil();
}

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
