import 'package:flutter/material.dart';
import 'screens/home/home_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // ١. استيراد الحزمة
import 'screens/splash/splash_screen.dart'; // <-- أضف هذا


// ٣. تعريف متغير عالمي للوصول السهل إلى Supabase
final supabase = Supabase.instance.client;

Future<void> main() async { // ٢. تحويل الدالة إلى async
  WidgetsFlutterBinding.ensureInitialized(); // ٤. التأكد من تهيئة Flutter

  // ٥. تهيئة Supabase
  await Supabase.initialize(
    url: 'https://pajxormplmloivyankji.supabase.co', // ٦. الصق الـ URL هنا
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBhanhvcm1wbG1sb2l2eWFua2ppIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA0ODQ3OTksImV4cCI6MjA3NjA2MDc5OX0.eEPB_Gt5HywU9oGNXLpSNc4IA7CTTL7CX-EMKDE3yec', // ٧. الصق مفتاح الـ anon public هنا
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Store App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.orange,
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        fontFamily: 'Muli',
        appBarTheme: const AppBarTheme(
          color: Colors.white,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.black),
          titleTextStyle: TextStyle(color: Colors.black, fontSize: 18),
        ),
      ),
      home: const SplashScreen(), // <-- غير هذا السطر
      //home: const HomeScreen(),
    );
  }
}