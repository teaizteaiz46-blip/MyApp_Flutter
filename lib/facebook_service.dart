import 'dart:convert';

import 'package:facebook_app_events/facebook_app_events.dart';
import 'package:flutter/foundation.dart';

/// كل أحداث فيسبوك تمر من هنا.
/// على الويب ما ينبعث شي (المكتبة ما تدعم الويب)، وأي خطأ ما يوگف التطبيق.
class FacebookAnalyticsService {
  FacebookAnalyticsService._();

  static final FacebookAppEvents _fb = FacebookAppEvents();
  static const String kCurrency = 'IQD';

  static Future<void> _safe(String name, Future<void> Function() call) async {
    if (kIsWeb) return;
    try {
      await call();
    } catch (e) {
      debugPrint('Facebook event "$name" failed: $e');
    }
  }

  /// 👀 مشاهدة منتج
  static Future<void> logViewContent({required String id, required double price}) =>
      _safe('view_content', () => _fb.logViewContent(
            id: id,
            type: 'product',
            currency: kCurrency,
            price: price,
          ));

  /// 🛍️ إضافة للسلة
  static Future<void> logAddToCart({
    required String id,
    required double price,
    String type = 'product',
    String currency = kCurrency,
  }) =>
      _safe('add_to_cart', () => _fb.logAddToCart(
            id: id,
            type: type,
            price: price,
            currency: currency,
          ));

  /// 🧾 بدء إتمام الطلب
  static Future<void> logInitiatedCheckout({
    required double totalPrice,
    required int numItems,
  }) =>
      _safe('initiated_checkout', () => _fb.logInitiatedCheckout(
            totalPrice: totalPrice,
            currency: kCurrency,
            contentType: 'product',
            numItems: numItems,
          ));

  /// 🛒 شراء ناجح (هذا الحدث الي يعتمد عليه فيسبوك لتحسين الإعلانات)
  static Future<void> logPurchase({
    required double amount,
    required List<int> productIds,
    required int numItems,
    int? orderId,
    String currency = kCurrency,
  }) =>
      _safe('purchase', () => _fb.logPurchase(
            amount: amount,
            currency: currency,
            parameters: {
              'fb_content_type': 'product',
              'fb_content_id': jsonEncode(productIds.map((id) => '$id').toList()),
              'fb_num_items': numItems,
              if (orderId != null) 'fb_order_id': '$orderId',
            },
          ));

  /// 👆 أحداث مخصصة
  static Future<void> logCustomEvent({
    required String eventName,
    Map<String, dynamic>? parameters,
  }) =>
      _safe(eventName, () => _fb.logEvent(name: eventName, parameters: parameters));
}
