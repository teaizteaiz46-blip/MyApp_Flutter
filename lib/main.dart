import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart'; // 👈 استيراد حزمة فحص الاتصال
import 'package:facebook_app_events/facebook_app_events.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
import 'services/cart_service.dart';
import 'services/deep_link_service.dart';
import 'services/tiktok_service.dart';
import '../../core/shop_api.dart';
import 'theme/app_theme.dart';

final supabase = Supabase.instance.client;

/// للتنقل من خارج الشاشات (مثلاً رابط منتج من إعلان).
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // روابط نظيفة بالويب (بدون #)
  usePathUrlStrategy();

  if (!kIsWeb) {
    try {
      final facebookAppEvents = FacebookAppEvents();
      await facebookAppEvents.setAutoLogAppEventsEnabled(true);
      await facebookAppEvents.setAdvertiserTracking(enabled: false);
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
    // عند تسجيل الدخول (أو فتح التطبيق وهو مسجّل) نسحب أي سلة قديمة من الحساب للجهاز
    supabase.auth.onAuthStateChange.listen((data) {
      final signedIn = data.event == AuthChangeEvent.signedIn ||
          data.event == AuthChangeEvent.initialSession;
      if (signedIn && data.session != null) {
        CartService.instance.pullAccountCart();
      }
    });
  }

  // تشغيل الواجهة فوراً لمنع تعليق الشاشة البيضاء
  runApp(const MyApp());

  // روابط المنتجات من إعلانات فيسبوك/انستغرام
  DeepLinkService.init(rootNavigatorKey);

  // الإشعارات ما توقف فتح التطبيق
  unawaited(TikTokAnalyticsService.init());
  unawaited(_setupNotifications());
}

Future<void> _setupNotifications() async {
  try {
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission(alert: true, badge: true, sound: true);

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      await messaging.subscribeToTopic('all');
      if (kDebugMode) {
        final token = await messaging.getToken();
        debugPrint('FCM Token: $token');
      }
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // التعامل مع الإشعار والتطبيق مفتوح
    });
  } catch (e) {
    debugPrint('Notification setup failed: $e');
  }
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
    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      title: 'MODO',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar', 'IQ'),
      supportedLocales: const [Locale('ar', 'IQ')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        primarySwatch: Colors.orange,
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        fontFamily: 'Muli',
        appBarTheme: const AppBarTheme(
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.black),
          titleTextStyle: TextStyle(color: Colors.black, fontSize: 18),
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
    );
  }
}
