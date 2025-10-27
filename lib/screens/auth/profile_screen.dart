import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../main.dart'; // لاستخدام supabase
import 'auth_screen.dart'; // شاشة تسجيل الدخول التي لدينا
import 'account_view.dart'; // شاشة جديدة سننشئها

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // هذا الويدجت يستمع تلقائيًا لتغيرات حالة تسجيل الدخول
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        print('--- ProfileScreen Builder ---'); // <-- أضف هذا
        // التحقق من وجود جلسة (session) مستخدم حالية
        final session = supabase.auth.currentSession;
        print('Current session: $session'); // <-- أضف هذا
        if (session == null) {
          print('Showing AuthScreen (User is null)'); // <-- أضف هذا
          // --- 1. إذا كان المستخدم "زائرًا" ---
          // اعرض له شاشة تسجيل الدخول وإنشاء الحساب
          return const AuthScreen();
        } else {
          // --- 2. إذا كان المستخدم "مسجلًا" ---
          // اعرض له شاشة حسابه وزر تسجيل الخروج
          print('Showing AccountView (User found)'); // <-- أضف هذا
          return AccountView(user: session.user);
        }
      },
    );
  }
}