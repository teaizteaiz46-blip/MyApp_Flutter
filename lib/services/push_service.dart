import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main.dart';
import '../screens/orders/my_orders_screen.dart';
import '../screens/points/points_screen.dart';
import '../theme/app_theme.dart';
import 'deep_link_service.dart';

/// إشعارات Firebase:
/// - كل الأجهزة الي وافقت تشترك بقناة `all` (إشعارات الزبائن).
/// - أجهزة المشرفين (المسجلين دخول وحسابهم مشرف) تشترك بـ `admins` حتى "إرسال تجربة" يوصلهم بس.
/// - كل حساب يشترك بقناته (u_ + رقم الحساب)، وكل طلب ينربط بجهازه حتى إشعارات الحالة توصل حتى للزائرة.
/// - الإشعار يطلع حتى والتطبيق مفتوح، والضغط عليه يفتح المنتج إذا بي منتج.
/// ترسلها صفحة الإدارة عن طريق دالة send-push، وإشعارات الطلبات دالة order-push.
class PushService {
  PushService._();

  static const String allTopic = 'all';
  static const String adminTopic = 'admins';

  static bool _started = false;
  static const String _userTopicKey = 'push_user_topic_v1';
  static const String _pendingOrderKey = 'push_pending_order_v1';
  static const String _askedKey = 'push_asked_after_order_v1';

  static GlobalKey<NavigatorState>? _navigatorKey;
  static AppLifecycleListener? _lifecycle;

  /// الجهاز جاهز للاشتراك: الإذن موجود، وبالآيفون رمز APNs وصل.
  /// بدونه الاشتراك بالآيفون يفشل بصمت ("APNS token has not been set yet").
  static bool _ready = false;
  static bool _preparing = false;

  /// آخر خطأ بالإشعارات (يطلع بفحص المشرف)
  static String? _lastError;

  static bool _allowed(NotificationSettings s) =>
      s.authorizationStatus == AuthorizationStatus.authorized ||
      s.authorizationStatus == AuthorizationStatus.provisional;

  static Future<void> init({
    required GlobalKey<NavigatorState> navigatorKey,
    required GlobalKey<ScaffoldMessengerState> messengerKey,
  }) async {
    if (kIsWeb || _started) return;
    _started = true;
    _navigatorKey = navigatorKey;
    try {
      final messaging = FirebaseMessaging.instance;

      // الإذن أول شي: أي انتظار قبله (مثل getInitialMessage) ممكن يعلّق فما تطلع النافذة
      await messaging.requestPermission(alert: true, badge: true, sound: true);

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
            action: productId != null
                ? SnackBarAction(
                    label: 'عرض',
                    onPressed: () => DeepLinkService.openProduct(navigatorKey, productId, source: 'push'),
                  )
                : _isOrders(message)
                    ? SnackBarAction(label: 'طلباتي', onPressed: () => _openOrders(navigatorKey))
                    : null,
          ));
      });

      // الضغط على الإشعار والتطبيق بالخلفية، أو التطبيق انفتح من الإشعار
      FirebaseMessaging.onMessageOpenedApp.listen((m) => _openFrom(m, navigatorKey));
      // بالآيفون وFlutter الجديد هذي ممكن ما ترجع أبد، فما ننتظرها
      unawaited(messaging
          .getInitialMessage()
          .timeout(const Duration(seconds: 5))
          .then((initial) {
        if (initial != null) _openFrom(initial, navigatorKey);
      }).catchError((Object _) {}));

      // الرمز تغيّر: نعيد الاشتراكات حتى ما تضيع
      messaging.onTokenRefresh.listen((_) {
        if (_ready) unawaited(_onReady(force: true));
      });

      // رجعت من الإعدادات (يمكن فعّلت الإشعارات) أو الجهاز بعده ما جاهز: نحاول مرة ثانية
      _lifecycle ??= AppLifecycleListener(onResume: () {
        if (!_ready) unawaited(_prepare());
      });

      await _prepare();
    } catch (e) {
      debugPrint('Push init failed: $e');
    }
  }

  /// ينتظر الجاهزية بنفس الجلسة (مو "الفتحة الجاية"): أغلب الزبائن يفتحون التطبيق مرة وحدة،
  /// فبالآيفون نضل نتأكد من رمز APNs طول ما التطبيق مفتوح (لحد ~8 دقايق).
  static Future<void> _prepare() async {
    if (kIsWeb || _ready || _preparing) return;
    _preparing = true;
    try {
      final messaging = FirebaseMessaging.instance;
      if (!_allowed(await messaging.getNotificationSettings())) {
        debugPrint('Push not allowed, topics skipped');
        return;
      }
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await _registerWithApple();
        var apns = false;
        for (var i = 0; i < 120 && !apns; i++) {
          try {
            apns = await messaging.getAPNSToken() != null;
          } catch (_) {}
          if (!apns) await Future<void>.delayed(Duration(seconds: i < 30 ? 1 : 5));
        }
        if (!apns) {
          _lastError = 'رمز APNs ما وصل';
          debugPrint('APNs token not ready, will retry on resume');
          return;
        }
      }
      _ready = true;
    } catch (e) {
      _lastError = 'prepare: $e';
      debugPrint('Push prepare failed: $e');
    } finally {
      _preparing = false;
    }
    if (_ready) await _onReady();
  }

  static const MethodChannel _native = MethodChannel('modo/push');
  static String _appleRegistration = 'ما انطلب';

  /// بالآيفون: نطلب رمز APNs من Apple بأنفسنا (ios/Runner/AppDelegate.swift).
  /// firebase_messaging يطلبه لحاله عند بدء التطبيق، بس بنسخ Flutter الجديدة إشعار البدء
  /// ما يوصله، فالرمز ما كان يجي أبد. وFirebase يلزم الرمز لما يوصل (swizzling).
  static Future<void> _registerWithApple() async {
    try {
      await _native.invokeMethod<bool>('registerForRemoteNotifications');
      _appleRegistration = '✅';
    } catch (e) {
      _appleRegistration = '❌ $e';
    }
  }

  /// أول ما يجهز الجهاز: قناة الكل، قنوات الحساب، وربط آخر طلب بالجهاز
  static Future<void> _onReady({bool force = false}) async {
    final messaging = FirebaseMessaging.instance;
    try {
      await messaging.subscribeToTopic(allTopic);
      if (kDebugMode) debugPrint('FCM Token: ${await messaging.getToken()}');
    } catch (e) {
      _lastError = 'subscribe all: $e';
      debugPrint('Subscribe "all" failed: $e');
    }
    await _syncAccountTopics(signedIn: supabase.auth.currentUser != null, force: force);
    await _flushPendingOrder();
  }

  /// يشترك جهاز المشرف بقناة التجربة، ويلغيها لأي حساب ثاني أو بعد تسجيل الخروج.
  /// وكل حساب يشترك بقناته الخاصة (u_ + رقم الحساب) حتى توصله إشعارات طلباته.
  /// إذا الجهاز بعده ما جاهز، تنعاد لما يجهز (_onReady).
  static Future<void> syncAdminTopic({required bool signedIn}) async {
    if (kIsWeb || !_ready) return;
    await _syncAccountTopics(signedIn: signedIn);
  }

  static Future<void> _syncAccountTopics({required bool signedIn, bool force = false}) async {
    final uid = signedIn ? supabase.auth.currentUser?.id : null;
    await _syncUserTopic(uid, force: force);
    try {
      var isAdmin = false;
      if (uid != null) {
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

  /// قناة الحساب: u_ + رقم الحساب بدون شخوط (رقم طويل ما ينخمن)
  static Future<void> _syncUserTopic(String? uid, {bool force = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final previous = prefs.getString(_userTopicKey);
      final next = uid == null ? null : 'u_${uid.replaceAll('-', '')}';
      if (previous == next && !force) return;
      final messaging = FirebaseMessaging.instance;
      if (previous != null && previous != next) await messaging.unsubscribeFromTopic(previous);
      if (next != null) await messaging.subscribeToTopic(next);
      if (next == null) {
        await prefs.remove(_userTopicKey);
      } else {
        await prefs.setString(_userTopicKey, next);
      }
    } catch (e) {
      debugPrint('User topic sync failed: $e');
    }
  }

  /// بعد نجاح الطلب: نربط الطلب بهذا الجهاز (حتى توصل إشعارات حالته حتى بدون حساب)،
  /// وإذا الإشعارات مطفية نذكّرها تفعّلها.
  static Future<void> afterOrder({required int orderId, required String phone}) async {
    if (kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _pendingOrderKey,
        jsonEncode({'id': orderId, 'phone': phone, 'at': DateTime.now().toIso8601String()}),
      );
      if (_ready) {
        await _flushPendingOrder();
      } else {
        unawaited(_prepare());
      }
      await _askToEnableIfOff();
    } catch (e) {
      debugPrint('afterOrder push failed: $e');
    }
  }

  /// يدز رمز الجهاز ويه آخر طلب (السيرفر يقبل خلال 24 ساعة من الطلب وبنفس رقم الهاتف)
  static Future<void> _flushPendingOrder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_pendingOrderKey);
      if (raw == null) return;
      final m = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final at = DateTime.tryParse('${m['at']}');
      if (at == null || DateTime.now().difference(at) > const Duration(hours: 24)) {
        await prefs.remove(_pendingOrderKey);
        return;
      }
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await supabase.rpc('attach_order_device', params: {
        'p_order_id': m['id'],
        'p_phone': m['phone'],
        'p_token': token,
        'p_platform': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
      });
      await prefs.remove(_pendingOrderKey);
    } catch (e) {
      _lastError = 'attach: $e';
      debugPrint('Attach order device failed: $e');
    }
  }

  /// للمشرف: حالة الإشعارات بهذا الجهاز، حتى نعرف وين توگف بدون سجلات الجهاز
  static Future<String> diagnose() async {
    if (kIsWeb) return 'الويب ما بيه إشعارات';
    final messaging = FirebaseMessaging.instance;
    final lines = <String>[];
    try {
      lines.add('الإذن: ${(await messaging.getNotificationSettings()).authorizationStatus.name}');
    } catch (e) {
      lines.add('الإذن: خطأ $e');
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      lines.add('طلب التسجيل من Apple: $_appleRegistration');
      try {
        final apns = await messaging.getAPNSToken();
        lines.add('رمز APNs: ${apns == null ? '❌ ما وصل' : '✅'}');
      } catch (e) {
        lines.add('رمز APNs: ❌ $e');
      }
    }
    try {
      final token = await messaging.getToken();
      lines.add('رمز FCM: ${token == null ? '❌' : '✅ …${token.substring(token.length - 6)}'}');
    } catch (e) {
      lines.add('رمز FCM: ❌ $e');
    }
    final prefs = await SharedPreferences.getInstance();
    lines.add('جاهز: ${_ready ? '✅' : '❌'}');
    lines.add('قناة الحساب: ${prefs.getString(_userTopicKey) ?? '—'}');
    lines.add('طلب ينتظر الربط: ${prefs.getString(_pendingOrderKey) == null ? 'لا' : 'نعم'}');
    lines.add('آخر خطأ: ${_lastError ?? 'ماكو'}');
    return lines.join('\n');
  }

  /// الإشعارات مطفية؟ نطلع كارت صغير بعد الطلب (مرة كل 3 أيام بالكثير)
  static Future<void> _askToEnableIfOff() async {
    final messaging = FirebaseMessaging.instance;
    if (_allowed(await messaging.getNotificationSettings())) return;
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt(_askedKey) ?? 0;
    if (DateTime.now().millisecondsSinceEpoch - last < const Duration(days: 3).inMilliseconds) return;

    // نخلي رسالة "تم إرسال طلبك" تبين أول
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    final context = _navigatorKey?.currentContext;
    if (context == null || !context.mounted) return;
    await prefs.setInt(_askedKey, DateTime.now().millisecondsSinceEpoch);

    final enable = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🔔', style: TextStyle(fontSize: 44)),
              const SizedBox(height: 8),
              const Text(
                'تريدين نبلغج وين وصل طلبج؟',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text(
                'فعّلي الإشعارات ويوصلج إشعار لما نثبت طلبج ولما يطلع للتوصيل 🚚',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.5),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('فعّلي الإشعارات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('مو هسه', style: TextStyle(color: Colors.black54)),
              ),
            ],
          ),
        ),
      ),
    );
    if (enable != true) return;

    // أندرويد 13+ يطلع نافذة الإذن مرة ثانية، والآيفون لازم من الإعدادات
    final settings = await messaging.requestPermission(alert: true, badge: true, sound: true);
    if (_allowed(settings)) {
      unawaited(_prepare());
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      await launchUrl(Uri.parse('app-settings:'));
    } else {
      final ctx = _navigatorKey?.currentContext;
      if (ctx != null && ctx.mounted) {
        ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(const SnackBar(
          duration: Duration(seconds: 6),
          content: Text('فعّليها من إعدادات الجهاز ← التطبيقات ← MODO ← الإشعارات'),
        ));
      }
    }
  }

  static bool _isOrders(RemoteMessage m) => m.data['type'] == 'orders';

  static void _openOrders(GlobalKey<NavigatorState> navigatorKey, [int attempt = 0]) {
    final nav = navigatorKey.currentState;
    if (nav == null) {
      if (attempt < 20) WidgetsBinding.instance.addPostFrameCallback((_) => _openOrders(navigatorKey, attempt + 1));
      return;
    }
    DeepLinkService.openedFromLink = true; // إعلان الافتتاح ما يطلع فوقها
    DeepLinkService.onExternalOpen?.call();
    nav.push(MaterialPageRoute(builder: (_) => const MyOrdersScreen()));
  }

  static int? _productId(RemoteMessage m) =>
      m.data['type'] == 'product' ? int.tryParse('${m.data['product_id'] ?? ''}') : null;

  static void _openFrom(RemoteMessage m, GlobalKey<NavigatorState> navigatorKey) {
    final id = _productId(m);
    if (id != null) {
      DeepLinkService.openProduct(navigatorKey, id, source: 'push');
    } else if (_isOrders(m)) {
      _openOrders(navigatorKey);
    } else if (m.data['type'] == 'points') {
      DeepLinkService.openedFromLink = true;
      DeepLinkService.onExternalOpen?.call();
      navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => const PointsScreen()));
    }
  }
}
