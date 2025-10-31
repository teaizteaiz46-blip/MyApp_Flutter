import 'package:flutter/material.dart';
import 'screens/home/home_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // ١. استيراد الحزمة
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // <-- أضف هذا
// ٣. تعريف متغير عالمي للوصول السهل إلى Supabase
final supabase = Supabase.instance.client;

Future<void> main() async { // ٢. تحويل الدالة إلى async
  WidgetsFlutterBinding.ensureInitialized(); // ٤. التأكد من تهيئة Flutter
// --- ٢. إضافة تهيئة Firebase هنا ---
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // --- نهاية الإضافة ---
  // ٥. تهيئة Supabase
  await Supabase.initialize(
    url: 'https://pajxormplmloivyankji.supabase.co', // ٦. الصق الـ URL هنا
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBhanhvcm1wbG1sb2l2eWFua2ppIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA0ODQ3OTksImV4cCI6MjA3NjA2MDc5OX0.eEPB_Gt5HywU9oGNXLpSNc4IA7CTTL7CX-EMKDE3yec', // ٧. الصق مفتاح الـ anon public هنا
  );
///////////////////////////////
  // --- طلب إذن الإشعارات ---
///  FirebaseMessaging messaging = FirebaseMessaging.instance;
///  NotificationSettings settings = await messaging.requestPermission(
///    alert: true,
///    announcement: false,
///    badge: true,
///    carPlay: false,
///    criticalAlert: false,
///    provisional: false,
///    sound: true,
///  );

///  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
///  } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
///  } else {
///  }
  // --- نهاية طلب الإذن ---
/////////////////////////
  // --- ✅ 4. ضع كود الحصول على التوكن هنا ✅ ---
  //    (داخل جملة if للتحقق من الإذن)
///  if (settings.authorizationStatus == AuthorizationStatus.authorized ||
///      settings.authorizationStatus == AuthorizationStatus.provisional) {

///    String? fcmToken = await messaging.getToken();
///    if (fcmToken != null) {
///      //print("Firebase Messaging Token: $fcmToken");
 ///     // TODO: حفظ هذا التوكن في Supabase لاحقًا
///    } else {
///      //print("Failed to get FCM token.");
///    }

///  }
  // --- نهاية كود الحصول على التوكن ---
//////////////////
  // --- ✅ إعداد معالجة الإشعارات الواردة ✅ ---

  // 1. التعامل مع الإشعارات والتطبيق في المقدمة (Foreground)
///  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    //print('Got a message whilst in the foreground!');
    //print('Message data: ${message.data}');

///    if (message.notification != null) {
      //print('Message also contained a notification: ${message.notification}');
      // يمكنك هنا عرض تنبيه داخل التطبيق (in-app notification) باستخدام
      // حزمة مثل flutter_local_notifications إذا أردت،
      // لأن الإشعارات لا تظهر تلقائيًا في شريط الحالة عندما يكون التطبيق مفتوحًا.
///    }
///  });

  // 2. التعامل مع فتح التطبيق من إشعار (عندما يكون التطبيق في الخلفية أو مغلقًا)
///  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    //print('A new onMessageOpenedApp event was published!');
    //print('Message data: ${message.data}');
    // يمكنك هنا توجيه المستخدم إلى شاشة معينة بناءً على بيانات الإشعار
    // مثال: إذا كان الإشعار عن طلب جديد، افتح شاشة الطلبات
    // Navigator.pushNamed(context, '/orders'); // (تحتاج لإعداد Routes)
///  });

  // 3. (اختياري) للتعامل مع الإشعارات التي تفتح التطبيق من الحالة المغلقة تمامًا
  // هذا يحتاج لوضعه خارج دالة main أحيانًا أو استخدام تهيئة خاصة
///   FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
///     if (message != null) {
  //     print('App opened from terminated state by notification!');
  //     print('Message data: ${message.data}');
  //     // توجيه المستخدم...
///     }
///   });

  // --- نهاية إعداد معالجة الإشعارات --

  /////////////////
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
      //home: const SplashScreen(), // <-- غير هذا السطر
      home: const HomeScreen(),
    );
  }
}
