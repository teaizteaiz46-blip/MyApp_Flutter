import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myapprun/core/offline_cache.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakePathProvider extends PathProviderPlatform with MockPlatformInterfaceMixin {
  _FakePathProvider(this.path);

  final String path;

  @override
  Future<String?> getApplicationSupportPath() async => path;

  @override
  Future<String?> getTemporaryPath() async => path;
}

const _obj = 'https://pajxormplmloivyankji.supabase.co/storage/v1/object/public/hijabat/public/a/b.jpg';
const _render = 'https://pajxormplmloivyankji.supabase.co/storage/v1/render/image/public/hijabat/public/a/b.jpg';

// صورة PNG بكسل واحد
final _png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==');

void main() {
  late Directory tmp;
  var n = 0;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    tmp = Directory.systemTemp.createTempSync('sized_image_test');
    PathProviderPlatform.instance = _FakePathProvider(tmp.path);
  });

  tearDownAll(() {
    try {
      tmp.deleteSync(recursive: true);
    } catch (_) {}
  });

  setUp(() {
    SizedImageStatus.reset();
    // نفس الصورة من اختبار سابق تبقى بذاكرة Flutter، فنمسحها حتى تنطلب من جديد
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
  });

  /// كاش جديد لكل اختبار، والإنترنت وهمي: [handler] يقرر الرد لكل رابط
  (CacheManager, List<String>) cache(Future<http.Response> Function(Uri url) handler) {
    final requests = <String>[];
    final key = 'sized_${n++}';
    final manager = CacheManager(Config(
      key,
      repo: JsonCacheInfoRepository(databaseName: key),
      fileService: HttpFileService(
        httpClient: MockClient((r) {
          requests.add(r.url.toString());
          return handler(r.url);
        }),
      ),
    ));
    return (manager, requests);
  }

  Future<ImageInfo> resolve(ImageProvider provider) {
    final done = Completer<ImageInfo>();
    provider.resolve(ImageConfiguration.empty).addListener(ImageStreamListener(
          (info, _) => done.isCompleted ? null : done.complete(info),
          onError: (e, s) => done.isCompleted ? null : done.completeError(e, s),
        ));
    return done.future.timeout(const Duration(seconds: 10));
  }

  http.Response ok() => http.Response.bytes(_png, 200, headers: {'content-type': 'image/png'});

  group('رابط النسخة الأصغر', () {
    test('صور Supabase', () {
      expect(sizedImageUrl(_obj, ImageSize.thumb), '$_render?width=480&height=640&resize=contain&quality=70');
      expect(sizedImageUrl(_obj, ImageSize.large), '$_render?width=1080&height=1440&resize=contain&quality=75');
      expect(sizedImageUrl(_obj, ImageSize.original), _obj);
    });

    test('غيرها تبقى مثل ما هي', () {
      expect(sizedImageUrl('https://example.com/x.jpg', ImageSize.thumb), 'https://example.com/x.jpg');
      expect(sizedImageUrl('$_obj?v=2', ImageSize.thumb), '$_obj?v=2');
      expect(sizedImageUrl(_obj.replaceAll('.jpg', '.GIF'), ImageSize.thumb), _obj.replaceAll('.jpg', '.GIF'));
      expect(sizedImageUrl('$_render?width=10', ImageSize.thumb), '$_render?width=10');
    });

    test('cachedImage يختار حسب الحجم', () {
      expect(cachedImage(_obj, size: ImageSize.thumb), isA<SizedNetworkImage>());
      expect(cachedImage(_obj), isNot(isA<SizedNetworkImage>()));
      expect(cachedImage('https://example.com/x.jpg', size: ImageSize.thumb), isNot(isA<SizedNetworkImage>()));
      expect(cachedImage(_obj, size: ImageSize.thumb, decodeWidth: 300), isA<ResizeImage>());
    });
  });

  testWidgets('المصغرة تشتغل: ما تنزل الأصلية', (tester) async {
    await tester.runAsync(() async {
      final (manager, requests) = cache((_) async => ok());
      final url = sizedImageUrl(_obj, ImageSize.thumb);
      final info = await resolve(SizedNetworkImage(url, _obj, cacheManager: manager));
      expect(info.image.width, 1);
      expect(requests, [url]);
      expect(SizedImageStatus.available, isTrue);
    });
  });

  testWidgets('المصغرة فشلت (خلصت الحصة): تنزل الأصلية، والصور الجاية تروح للأصلية مباشرة', (tester) async {
    await tester.runAsync(() async {
      final (manager, requests) = cache((u) async => u.path.contains('/render/') ? http.Response('quota', 402) : ok());
      final url = sizedImageUrl(_obj, ImageSize.thumb);
      final info = await resolve(SizedNetworkImage(url, _obj, cacheManager: manager));
      expect(info.image.width, 1);
      expect(requests, [url, _obj]);
      expect(SizedImageStatus.available, isFalse);

      // صورة ثانية: ما نجرّب التصغير لفترة
      const other = 'https://pajxormplmloivyankji.supabase.co/storage/v1/object/public/hijabat/public/c.jpg';
      await resolve(SizedNetworkImage(sizedImageUrl(other, ImageSize.thumb), other, cacheManager: manager));
      expect(requests.last, other);
      expect(requests.where((r) => r.contains('/render/')).length, 1);
    });
  });

  testWidgets('رد مو صورة (خربان): ينزل الأصلية', (tester) async {
    await tester.runAsync(() async {
      final (manager, requests) = cache(
        (u) async => u.path.contains('/render/') ? http.Response('<html>oops</html>', 200, headers: {'content-type': 'image/jpeg'}) : ok(),
      );
      final url = sizedImageUrl(_obj, ImageSize.large);
      final info = await resolve(SizedNetworkImage(url, _obj, cacheManager: manager));
      expect(info.image.width, 1);
      expect(requests.last, _obj);
    });
  });
}
