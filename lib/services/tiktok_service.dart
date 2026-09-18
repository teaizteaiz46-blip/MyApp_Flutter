import 'package:flutter/foundation.dart';
import 'package:tiktok_events_sdk/tiktok_events_sdk.dart';

/// كل أحداث تيك توك تمر من هنا.
/// على الويب ما ينبعث شي، وأي خطأ ما يوگف التطبيق.
class TikTokAnalyticsService {
  TikTokAnalyticsService._();

  // أرقام مصادر البيانات من Events Manager
  static const String androidAppId = 'iq.ameerazax.velin';
  static const String tikTokAndroidId = '7686549886060396552';
  static const String iosAppId = '6754703322';
  static const String tikTokIosId = '7686586940623257608';

  static const String kCurrency = 'IQD';

  static bool _ready = false;

  static Future<void> init() async {
    if (kIsWeb) return;
    try {
      await TikTokEventsSdk.initSdk(
        androidAppId: androidAppId,
        tikTokAndroidId: tikTokAndroidId,
        iosAppId: iosAppId,
        tiktokIosId: tikTokIosId,
        // بالتطوير تروح للـ Test event، وبالنسخة المنشورة تروح للأحداث الحقيقية
        isDebugMode: kDebugMode,
        androidOptions: TikTokAndroidOptions(
          disableAdvertiserIDCollection: false,
        ),
        iosOptions: TikTokIosOptions(
          disableTracking: false,
          disableAutomaticTracking: false,
          disableSKAdNetworkSupport: false,
        ),
      );
      _ready = true;
    } catch (e) {
      debugPrint('TikTok init failed: $e');
    }
  }

  static Future<void> _log(String name, {String? eventId, EventProperties? properties}) async {
    if (kIsWeb || !_ready) return;
    try {
      await TikTokEventsSdk.logEvent(
        event: TikTokEvent(eventName: name, eventId: eventId, properties: properties),
      );
    } catch (e) {
      debugPrint('TikTok event "$name" failed: $e');
    }
  }

  /// 👀 مشاهدة منتج
  static Future<void> logViewContent({required String id, required double price}) => _log(
        'ViewContent',
        properties: EventProperties(
          contentId: id,
          contentType: 'product',
          value: price,
          customProperties: const {'currency': kCurrency},
        ),
      );

  /// 🛍️ إضافة للسلة
  static Future<void> logAddToCart({required String id, required double price, int quantity = 1}) => _log(
        'AddToCart',
        properties: EventProperties(
          contentId: id,
          contentType: 'product',
          quantity: quantity,
          value: price,
          customProperties: const {'currency': kCurrency},
        ),
      );

  /// 🧾 بدء إتمام الطلب
  static Future<void> logInitiateCheckout({required double totalPrice, required int numItems}) => _log(
        'InitiateCheckout',
        properties: EventProperties(
          contentType: 'product',
          quantity: numItems,
          value: totalPrice,
          customProperties: const {'currency': kCurrency},
        ),
      );

  /// 🛒 شراء ناجح
  static Future<void> logPurchase({
    required double amount,
    required List<int> productIds,
    required int numItems,
    int? orderId,
  }) =>
      _log(
        'CompletePayment',
        eventId: orderId == null ? null : 'order_$orderId',
        properties: EventProperties(
          contentType: 'product',
          contentId: productIds.isEmpty ? null : productIds.first.toString(),
          quantity: numItems,
          value: amount,
          customProperties: {
            'currency': kCurrency,
            'content_ids': productIds.join(','),
            if (orderId != null) 'order_id': '$orderId',
          },
        ),
      );

  /// تسجيل خروج الزبون
  static Future<void> logout() async {
    if (kIsWeb || !_ready) return;
    try {
      await TikTokEventsSdk.logout();
    } catch (e) {
      debugPrint('TikTok logout failed: $e');
    }
  }
}
