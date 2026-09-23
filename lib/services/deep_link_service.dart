import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../screens/details/details_screen.dart';

/// روابط تفتح منتج داخل التطبيق (إعلانات الكتالوج بفيسبوك وانستغرام، أو أي رابط منتج).
/// الصيغ المقبولة:
///   modoiraq://product/861
///   https://…/p.html?id=861   (صفحة المنتج على الويب)
class DeepLinkService {
  DeepLinkService._();

  static const String scheme = 'modoiraq';

  static StreamSubscription<Uri>? _sub;

  /// يرجع رقم المنتج من الرابط، أو null إذا الرابط مو رابط منتج.
  static int? productIdFrom(Uri uri) {
    if (uri.scheme == scheme && uri.host == 'product') {
      final segments = uri.pathSegments.where((s) => s.isNotEmpty);
      return segments.isEmpty ? null : int.tryParse(segments.first);
    }
    if ((uri.scheme == 'https' || uri.scheme == 'http') && uri.path.endsWith('/p.html')) {
      return int.tryParse(uri.queryParameters['id'] ?? '');
    }
    return null;
  }

  /// يستمع للروابط (الرابط الي فتح التطبيق + أي رابط يوصل والتطبيق مفتوح) ويفتح المنتج.
  static void init(GlobalKey<NavigatorState> navigatorKey) {
    if (kIsWeb || _sub != null) return;
    try {
      _sub = AppLinks().uriLinkStream.listen(
        (uri) => _open(navigatorKey, uri),
        onError: (Object e) => debugPrint('DeepLink error: $e'),
      );
    } catch (e) {
      debugPrint('DeepLink init failed: $e');
    }
  }

  static void _open(GlobalKey<NavigatorState> navigatorKey, Uri uri, {int attempt = 0}) {
    final id = productIdFrom(uri);
    if (id == null) return;
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      // الواجهة بعدها ما انبنت (التطبيق انفتح من الرابط): نحاول بعد أول إطار
      if (attempt < 20) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _open(navigatorKey, uri, attempt: attempt + 1));
      }
      return;
    }
    navigator.push(MaterialPageRoute(builder: (_) => DetailsScreen(productId: id)));
  }
}
