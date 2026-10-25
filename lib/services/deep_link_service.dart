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

  /// صار true أول ما ينفتح منتج من رابط أو إشعار.
  static bool openedFromLink = false;

  /// يتنادى كل ما ينفتح منتج من برا (إعلان الافتتاح يستخدمه حتى يتسكّر).
  static VoidCallback? onExternalOpen;

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

  /// مصدر فتح المنتج من الرابط: utm_source إذا موجود، وإلا 'meta' إذا الرابط من إعلان ميتا
  /// (ميتا تضيف al_applink_data أو fbclid)، وإلا 'deeplink'.
  static String sourceFrom(Uri uri) {
    final q = uri.queryParameters;
    final utm = q['utm_source'];
    if (utm != null && utm.isNotEmpty) return utm;
    if (q.containsKey('al_applink_data') || q.containsKey('fbclid')) return 'meta';
    return 'deeplink';
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

  static void _open(GlobalKey<NavigatorState> navigatorKey, Uri uri) {
    final id = productIdFrom(uri);
    if (id == null) return;
    openProduct(navigatorKey, id, source: sourceFrom(uri), campaign: uri.queryParameters['utm_campaign']);
  }

  /// يفتح صفحة منتج من برا الشاشات (رابط، إشعار...). إذا الواجهة بعدها ما انبنت ينتظر أول إطار.
  static void openProduct(
    GlobalKey<NavigatorState> navigatorKey,
    int id, {
    String source = 'app',
    String? campaign,
    int attempt = 0,
  }) {
    // إعلان الافتتاح ما يطلع (أو يتسكّر) لما الزبونة جاية من رابط أو إشعار
    openedFromLink = true;
    onExternalOpen?.call();
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      if (attempt < 20) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => openProduct(navigatorKey, id, source: source, campaign: campaign, attempt: attempt + 1),
        );
      }
      return;
    }
    navigator.push(MaterialPageRoute(
      builder: (_) => DetailsScreen(productId: id, source: source, campaign: campaign),
    ));
  }
}
