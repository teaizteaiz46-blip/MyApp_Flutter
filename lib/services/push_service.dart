import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../main.dart';
import 'deep_link_service.dart';

/// إشعارات Firebase:
/// - كل الأجهزة الي وافقت تشترك بقناة `all` (إشعارات الزبائن).
/// - أجهزة المشرفين (المسجلين دخول وحسابهم مشرف) تشترك بـ `admins` حتى "إرسال تجربة" يوصلهم بس.
/// - الإشعار يطلع حتى والتطبيق مفتوح، والضغط عليه يفتح المنتج إذا بي منتج.
/// ترسلها صفحة الإدارة عن طريق دالة send-push.
class PushService {
  PushService._();

  static const String allTopic = 'all';
  static const String adminTopic = 'admins';

  static bool _started = false;

  static Future<void> init({
    required GlobalKey<NavigatorState> navigatorKey,
    required GlobalKey<ScaffoldMessengerState> messengerKey,
  }) async {
    if (kIsWeb || _started) return;
    _started = true;
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(alert: true, badge: true, sound: true);
      final allowed = settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      if (allowed) {
        await messaging.subscribeToTopic(allTopic);
        if (kDebugMode) debugPrint('FCM Token: ${await messaging.getToken()}');
      }

      // آيفون: النظام يعرض الإشعار حتى والتطبيق مفتوح
      await messaging.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);

      // أندرويد والتطبيق مفتوح: النظام ما يعرضه، فنطلعه شريط داخل التطبيق
      FirebaseMessaging.onMessage.listen((message) {
        if (defaultTargetPlatform != TargetPlatform.android) return;
        final n = message.notification;
        if (n == null) return;
        final productId = _productId(message);
        messengerKey.currentState
          ?..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            duration: const Duration(seconds: 6),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if ((n.title ?? '').isNotEmpty) Text(n.title!, style: const TextStyle(fontWeight: FontWeight.bold)),
                if ((n.body ?? '').isNotEmpty) Text(n.body!),
              ],
            ),
            action: productId == null
                ? null
                : SnackBarAction(
                    label: 'عرض',
                    onPressed: () => DeepLinkService.openProduct(navigatorKey, productId, source: 'push'),
                  ),
          ));
      });

      // الضغط على الإشعار والتطبيق بالخلفية، أو التطبيق انفتح من الإشعار
      FirebaseMessaging.onMessageOpenedApp.listen((m) => _openFrom(m, navigatorKey));
      final initial = await messaging.getInitialMessage();
      if (initial != null) _openFrom(initial, navigatorKey);
    } catch (e) {
      debugPrint('Push init failed: $e');
    }
  }

  /// يشترك جهاز المشرف بقناة التجربة، ويلغيها لأي حساب ثاني أو بعد تسجيل الخروج.
  static Future<void> syncAdminTopic({required bool signedIn}) async {
    if (kIsWeb) return;
    try {
      var isAdmin = false;
      if (signedIn) {
        isAdmin = await supabase.rpc('is_modo_admin') == true;
      }
      final messaging = FirebaseMessaging.instance;
      if (isAdmin) {
        await messaging.subscribeToTopic(adminTopic);
      } else {
        await messaging.unsubscribeFromTopic(adminTopic);
      }
    } catch (e) {
      debugPrint('Admin topic sync failed: $e');
    }
  }

  static int? _productId(RemoteMessage m) =>
      m.data['type'] == 'product' ? int.tryParse('${m.data['product_id'] ?? ''}') : null;

  static void _openFrom(RemoteMessage m, GlobalKey<NavigatorState> navigatorKey) {
    final id = _productId(m);
    if (id != null) DeepLinkService.openProduct(navigatorKey, id, source: 'push');
  }
}
