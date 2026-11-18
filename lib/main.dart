import 'dart:async';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:connectivity_plus/connectivity_plus.dart'; // 👈 استيراد حزمة فحص الاتصال
import 'package:facebook_app_events/facebook_app_events.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'firebase_options.dart';
import 'no_internet_screen.dart'; // 👈 استيراد شاشة عدم وجود اتصال
import 'screens/cart/cart_screen.dart';
import 'screens/clips/clips_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/orders/my_orders_screen.dart';
import 'screens/policy/privacy_policy_screen.dart';
import 'screens/update/force_update_screen.dart';
import 'services/app_config.dart';
import 'services/cart_service.dart';
import 'services/guest_orders_service.dart';
import 'services/offers_service.dart';
import 'services/update_service.dart';
import 'services/deep_link_service.dart';
import 'services/order_confirm_service.dart';
import 'services/points_service.dart';
import 'services/push_service.dart';
import 'services/wishlist_service.dart';
import 'services/splash_ad_service.dart';
import 'services/tiktok_service.dart';
import '../../core/shop_api.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

final supabase = Supabase.instance.client;

/// للتنقل من خارج الشاشات (مثلاً رابط منتج من إعلان).
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// لعرض رسائل من خارج الشاشات (مثلاً إشعار وصل والتطبيق مفتوح).
final GlobalKey<ScaffoldMessengerState> rootMessengerKey = GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // روابط نظيفة بالويب (بدون #)
  usePathUrlStrategy();

  if (!kIsWeb) {
    try {
      final facebookAppEvents = FacebookAppEvents();
      await facebookAppEvents.setAutoLogAppEventsEnabled(true);
    } catch (e) {
      debugPrint('Facebook init failed: $e');
    }
  }

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }

  var supabaseReady = false;
  try {
    await Supabase.initialize(
      url: 'https://pajxormplmloivyankji.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBhanhvcm1wbG1sb2l2eWFua2ppIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA0ODQ3OTksImV4cCI6MjA3NjA2MDc5OX0.eEPB_Gt5HywU9oGNXLpSNc4IA7CTTL7CX-EMKDE3yec',
    );
    supabaseReady = true;
  } catch (e) {
    debugPrint('Supabase initialization failed: $e');
  }

  if (supabaseReady) {
    unawaited(CartService.instance.load());
    // "طلباتي" بدون حساب: عدد الطلبات + المفاتيح الناقصة
    unawaited(GuestOrdersService.init());
    // عند تسجيل الدخول (أو فتح التطبيق وهو مسجّل) نسحب أي سلة قديمة من الحساب للجهاز
    supabase.auth.onAuthStateChange.listen((data) {
      final signedIn = data.event == AuthChangeEvent.signedIn ||
          data.event == AuthChangeEvent.initialSession;
      if (signedIn && data.session != null) {
        CartService.instance.pullAccountCart();
        // طلبات هذا الموبايل (من قبل الحساب) تنتقل للحساب
        unawaited(GuestOrdersService.claimToAccount().then((n) {
          if (n <= 0) return;
          rootMessengerKey.currentState?.showSnackBar(SnackBar(
            content: Text('✅ انتقلت طلباتكم ($n) لحسابكم'),
            duration: const Duration(seconds: 4),
          ));
        }));
      }
      // أجهزة المشرفين تستلم "إرسال تجربة" من صفحة الإدارة
      if (signedIn || data.event == AuthChangeEvent.signedOut) {
        unawaited(PushService.syncAdminTopic(signedIn: data.session != null));
        // نقاطي والمفضلة تتبع الحساب
        if (data.session != null) {
          unawaited(PointsService.instance.refresh());
          unawaited(WishlistService.instance.refresh());
        } else {
          PointsService.instance.clear();
          WishlistService.instance.clear();
        }
      }
    });
  }

  // إعدادات المتجر (الرئيسية الافتراضية، التوصيل المجاني، التحديث الإجباري): آخر نسخة بالجهاز فوراً
  await AppConfig.init();
  OffersService.syncSettings();

  // المظهر المحفوظ (ليلي إذا الزبون بعده ما اختار) قبل أول إطار، حتى ما يطلع وميض
  await ThemeController.init();

  // تشغيل الواجهة فوراً لمنع تعليق الشاشة البيضاء
  runApp(const MyApp());

  // التحديث الإجباري (إذا مشغّل من صفحة الأدمن)
  if (supabaseReady) UpdateService.init();

  // روابط المنتجات من إعلانات فيسبوك/انستغرام
  DeepLinkService.init(rootNavigatorKey);

  // إعلان الافتتاح (إذا اكو إعلان فعّال وصورته جاهزة بالجهاز)
  unawaited(SplashAdService.run(rootNavigatorKey));

  // التتبع ثم الإشعارات (ما توقف فتح التطبيق)
  unawaited(_setupTracking());
}

/// آيفون: نطلب إذن التتبع (ATT) مرة وحدة بعد ما تظهر الواجهة.
/// ميتا (SDK 17+) تقرا جواب الزبون من النظام مباشرة، وتيك توك يشوف الجواب جاهز فما يسأل مرة ثانية.
/// أندرويد: ماكو إذن، تيك توك يشتغل مباشرة.
Future<void> _setupTracking() async {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
    try {
      // نافذة الإذن ما تطلع إلا والتطبيق ظاهر: ننتظر أول إطار وشوية وقت
      await WidgetsBinding.instance.endOfFrame;
      await Future<void>.delayed(const Duration(milliseconds: 800));
      if (await AppTrackingTransparency.trackingAuthorizationStatus == TrackingStatus.notDetermined) {
        await AppTrackingTransparency.requestTrackingAuthorization();
      }
    } catch (e) {
      debugPrint('Tracking permission failed: $e');
    }
  }
  // إذن الإشعارات بعد نافذة التتبع: نافذتين بنفس الوقت وحدة منهن ما تطلع
  unawaited(PushService.init(navigatorKey: rootNavigatorKey, messengerKey: rootMessengerKey));
  // طلب بعده ينتظر تأكيد الزبون؟ نطلع نافذته
  OrderConfirmService.init(navigatorKey: rootNavigatorKey, messengerKey: rootMessengerKey);
  await TikTokAnalyticsService.init();
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isConnected = true;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  @override
  void initState() {
    super.initState();
    _checkInitialConnection();

    // الاستماع للتغيرات في حالة الشبكة في الوقت الحقيقي
    _connectivitySub = Connectivity().onConnectivityChanged.listen(_updateConnectionStatus);
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  Future<void> _checkInitialConnection() async {
    final results = await Connectivity().checkConnectivity();
    _updateConnectionStatus(results);
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    if (!mounted) return;
    setState(() {
      _isConnected = !results.contains(ConnectivityResult.none);
    });
  }

  @override
  Widget build(BuildContext context) {
    // المظهر (ليلي/فاتح/حسب الموبايل) يتبدل فوراً بدون إعادة تشغيل
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.mode,
      builder: (context, themeMode, _) => MaterialApp(
        navigatorKey: rootNavigatorKey,
        scaffoldMessengerKey: rootMessengerKey,
        title: 'MODO',
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar', 'IQ'),
        supportedLocales: const [Locale('ar', 'IQ')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        // التحديث الإجباري يغطي كل الشاشات (والتطبيق يبقى تحته بدون ما ينعاد)،
        // وأيقونات شريط الحالة حسب الوضع (الشاشات الي بيها شريط علوي تحدد لونها بنفسها)
        builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
          value: context.modo.overlay,
          child: ValueListenableBuilder<bool>(
            valueListenable: UpdateService.required,
            builder: (context, mustUpdate, _) => Stack(
              children: [
                if (child != null) child,
                if (mustUpdate) const Positioned.fill(child: ForceUpdateScreen()),
              ],
            ),
          ),
        ),
        // 🔹 عرض شاشة عدم الاتصال تلقائياً إذا انقطع الإنترنت
        home: _isConnected
            ? const HomeScreen()
            : NoInternetScreen(onRetry: _checkInitialConnection),
        routes: {
          '/privacy': (context) => const PrivacyPolicyScreen(),
          '/orders': (context) => const MyOrdersScreen(),
          '/clips': (context) => const ClipsScreen(),
          '/cart': (context) => const CartScreen(),
        },
        // حماية الويب من شاشة فارغة إذا انكتب مسار غير معروف
        onUnknownRoute: (settings) => MaterialPageRoute(builder: (context) => const HomeScreen()),
      ),
    );
  }
}
