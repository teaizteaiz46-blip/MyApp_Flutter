import 'package:facebook_app_events/facebook_app_events.dart';

class FacebookAnalyticsService {
  static final FacebookAppEvents _facebookAppEvents = FacebookAppEvents();

  /// 🛒 1. تتبع عملية شراء ناجحة
  static Future<void> logPurchase({
    required double amount,
    required String currency,
    Map<String, dynamic>? parameters,
  }) async {
    await _facebookAppEvents.logPurchase(
      amount: amount,
      currency: currency, // مثال: 'IQD' أو 'USD'
      parameters: parameters,
    );
  }

  /// 🛍️ 2. تتبع إضافة منتج للسلة
  static Future<void> logAddToCart({
    required String id,
    required String type,
    required double price,
    required String currency,
  }) async {
    await _facebookAppEvents.logAddToCart(
      id: id,
      type: type,
      price: price,
      currency: currency,
    );
  }

  /// 👆 3. تتبع ضغطات الأزرار أو مشاهدة الشاشات
  static Future<void> logCustomEvent({
    required String eventName,
    Map<String, dynamic>? parameters,
  }) async {
    await _facebookAppEvents.logEvent(
      name: eventName,
      parameters: parameters,
    );
  }
}