import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:myapprun/core/offline_cache.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakePathProvider extends PathProviderPlatform with MockPlatformInterfaceMixin {
  _FakePathProvider(this.path);

  final String path;

  @override
  Future<String?> getApplicationSupportPath() async => path;
}

void main() {
  late Directory tmp;

  setUpAll(() {
    tmp = Directory.systemTemp.createTempSync('offline_cache_test');
    PathProviderPlatform.instance = _FakePathProvider(tmp.path);
  });

  tearDownAll(() => tmp.deleteSync(recursive: true));

  test('أول مرة: ينتظر السيرفر ويحفظ', () async {
    final rows = await OfflineCache.fetch('a', () async => [{'id': 1}]);
    expect(rows, [{'id': 1}]);
  });

  test('المرة الثانية: يرجع المحفوظ فوراً والجديد يوصل عبر onFresh', () async {
    await OfflineCache.fetch('b', () async => [{'id': 1, 'price': 5000}]);

    final server = Completer<List<Map<String, dynamic>>>();
    final fresh = Completer<List<Map<String, dynamic>>>();
    final rows = await OfflineCache.fetch('b', () => server.future, onFresh: fresh.complete);
    expect(rows, [{'id': 1, 'price': 5000}]);

    server.complete([{'id': 1, 'price': 4500}]);
    expect(await fresh.future, [{'id': 1, 'price': 4500}]);

    // الفتحة الثالثة تبدي بالنسخة المحدثة
    final third = await OfflineCache.fetch('b', () => Completer<List<Map<String, dynamic>>>().future);
    expect(third, [{'id': 1, 'price': 4500}]);
  });

  test('ما يستدعي onFresh إذا ما تغيّر شي', () async {
    await OfflineCache.fetch('c', () async => [{'id': 1}]);
    var called = false;
    await OfflineCache.fetch('c', () async => [{'id': 1}], onFresh: (_) => called = true);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(called, isFalse);
  });

  test('بدون إنترنت: يرجع المحفوظ وما يطلع خطأ', () async {
    await OfflineCache.fetch('d', () async => [{'id': 7}]);
    final rows = await OfflineCache.fetch('d', () async => throw const SocketException('offline'));
    expect(rows, [{'id': 7}]);
    await Future<void>.delayed(const Duration(milliseconds: 50));
  });

  test('بدون إنترنت وبدون نسخة محفوظة: يطلع الخطأ عادي', () async {
    expect(
      OfflineCache.fetch('e', () async => throw const SocketException('offline')),
      throwsA(isA<SocketException>()),
    );
  });
}
