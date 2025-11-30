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

  // تهيئة Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler); // ✅ يمكن تفعيلها عند الحاجة

  // تهيئة Supabase
  await Supabase.initialize(
    url: 'https://pajxormplmloivyankji.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBhanhvcm1wbG1sb2l2eWFua2ppIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA0ODQ3OTksImV4cCI6MjA3NjA2MDc5OX0.eEPB_Gt5HywU9oGNXLpSNc4IA7CTTL7CX-EMKDE3yec',
  );

  // تعريف كائن المراسلة (تم نقل التعريف هنا ليكون صالحًا لكامل الدالة)
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  // طلب إذن الإشعارات
  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );

  // يمكنك استخدام المتغير settings الآن
  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    //print('User granted permission');
  } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
    //print('User granted provisional permission');
  } else {
    //print('User declined or has not accepted permission');
  }

  // ✅ 4. الحصول على التوكن
  if (settings.authorizationStatus == AuthorizationStatus.authorized ||
      settings.authorizationStatus == AuthorizationStatus.provisional) {
    String? fcmToken = await messaging.getToken();
    if (fcmToken != null) {
      //print("Firebase Messaging Token: $fcmToken"); // تم تفعيل الطباعة
      // TODO: حفظ هذا التوكن في Supabase
    } else {
      //print("Failed to get FCM token."); // تم تفعيل الطباعة
    }
  }

  // ✅ إعداد معالجة الإشعارات الواردة
  // 1. التعامل مع الإشعارات والتطبيق في المقدمة (Foreground)
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    //print('Got a message whilst in the foreground!');
    //print('Message data: ${message.data}');
    if (message.notification != null) {
      //print('Message also contained a notification: ${message.notification}');
    }
  });

  // 2. التعامل مع فتح التطبيق من إشعار (عندما يكون التطبيق في الخلفية أو مغلقًا)
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    //print('A new onMessageOpenedApp event was published!');
    //print('Message data: ${message.data}');
    // لا يمكن استخدام Navigator.pushNamed(context, '/orders'); هنا
    // لأن دالة main لا تملك context.
    // يجب معالجة التوجيه (Navigation) داخل الـ State/Widget الخاص بك.
  });

  // 3. للتعامل مع الإشعارات التي تفتح التطبيق من الحالة المغلقة تمامًا
  FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
    if (message != null) {
      //print('App opened from terminated state by notification!');
      //print('Message data: ${message.data}');
    }
  });

  runApp(const MyApp());
}

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
