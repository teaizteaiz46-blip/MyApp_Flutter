import 'package:flutter/material.dart';
import 'screens/home/home_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // ✅ 1. استيراد حزمة الإشعارات
import 'firebase_options.dart';

// تعريف متغير عالمي للوصول السهل إلى Supabase
final supabase = Supabase.instance.client;

// وظيفة لمعالجة الإشعارات في الخلفية (يجب أن تكون على مستوى علوي/Top-level)
// Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
//   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
//   print("Handling a background message: ${message.messageId}");
// }


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- 1. محاولة تهيئة Firebase (مع حماية من الفشل) ---
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("✅ Firebase initialized successfully");
  } catch (e) {
    print("❌ Firebase initialization failed: $e");
    // لا نوقف التطبيق، نكمل حتى لو فشل Firebase
  }

  // --- 2. محاولة تهيئة Supabase (مع حماية من الفشل) ---
  try {
    await Supabase.initialize(
      url: 'https://pajxormplmloivyankji.supabase.co', // تأكد من الرابط
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBhanhvcm1wbG1sb2l2eWFua2ppIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA0ODQ3OTksImV4cCI6MjA3NjA2MDc5OX0.eEPB_Gt5HywU9oGNXLpSNc4IA7CTTL7CX-EMKDE3yec',
    );
    print("✅ Supabase initialized successfully");
  } catch (e) {
    print("❌ Supabase initialization failed: $e");
  }

  // --- 3. كود الإشعارات (أيضاً داخل try-catch) ---
  try {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      // محاولة جلب التوكن ولكن لا ننتظره ليعطل التطبيق
      messaging.getToken().then((token) {
        print("FCM Token: $token");
      }).catchError((e) {
        print("Error getting token: $e");
      });
    }

    // المستمعون للإشعارات
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        // التعامل مع الإشعار
      }
    });

  } catch (e) {
    print("❌ Notification setup failed: $e");
  }

  // --- 4. تشغيل التطبيق (يتم الوصول إليه دائماً الآن) ---
  runApp(const MyApp());
}
/////////////////////////////
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VELIN',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.orange,
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        fontFamily: 'Muli',
        appBarTheme: const AppBarTheme(
          //color: Colors.white,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.black),
          titleTextStyle: TextStyle(color: Colors.black, fontSize: 18),
        ),
      ),
      //home: const SplashScreen(),
      home: const HomeScreen(),
    );
  }
}
