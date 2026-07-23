import 'package:flutter/material.dart';
import 'screens/home/home_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'facebook_service.dart';
import 'package:flutter/foundation.dart';
import 'package:facebook_app_events/facebook_app_events.dart';
import 'package:myapprun/screens/policy/privacy_policy_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart'; // 👈 استيراد الاستراتيجية لتقبل الروابط
import 'package:myapprun/screens/checkout/checkout_screen.dart';
import 'package:myapprun/screens/clips/clips_screen.dart';
import 'package:myapprun/screens/clips/video_clip_player.dart';
import 'package:myapprun/screens/orders/my_orders_screen.dart';
import 'package:myapprun/screens/cart/cart_screen.dart';


final supabase = Supabase.instance.client;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 📍 1. هذا هو الأمر السحري لحذف الـ # وتفعيل الروابط النظيفة بمتصفح الويب
  usePathUrlStrategy();

  if (!kIsWeb) {
    final facebookAppEvents = FacebookAppEvents();
    await facebookAppEvents.setAutoLogAppEventsEnabled(true);
    await facebookAppEvents.setAdvertiserTracking(enabled: true);
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("✅ Firebase initialized successfully");
  } catch (e) {
    print("❌ Firebase initialization failed: $e");
  }

  try {
    await Supabase.initialize(
      url: 'https://pajxormplmloivyankji.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBhanhvcm1wbG1sb2l2eWFua2ppIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA0ODQ3OTksImV4cCI6MjA3NjA2MDc5OX0.eEPB_Gt5HywU9oGNXLpSNc4IA7CTTL7CX-EMKDE3yec',
    );
    print("✅ Supabase initialized successfully");
  } catch (e) {
    print("❌ Supabase initialization failed: $e");
  }

  try {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {

      await messaging.subscribeToTopic('all');
      print("Subscribed to 'all' topic");

      messaging.getToken().then((token) {
        print("FCM Token: $token");
      }).catchError((e) {
        print("Error getting token: $e");
      });
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        // التعامل مع الإشعار
      }
    });

  } catch (e) {
    print("❌ Notification setup failed: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MODO',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar', 'IQ'),
      supportedLocales: const [
        Locale('ar', 'IQ'),
      ],
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
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/privacy': (context) => const PrivacyPolicyScreen(),
        '/orders': (context) => const MyOrdersScreen(),
        '/clips' : (context) => const ClipsScreen(),
        '/cart' : (context) => const CartScreen(),

      },

      // 📍 2. الكود البرمجي لحماية الويب من إعطاء شاشة فارغة إذا تم كتابة أي مسار آخر بالرابط
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => const HomeScreen(),
        );
      },
    );
  }
}