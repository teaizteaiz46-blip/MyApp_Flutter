import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../main.dart'; // لاستخدام supabase
import '../orders/my_orders_screen.dart';

class AccountView extends StatelessWidget {
  final User user;
  const AccountView({super.key, required this.user});

  // دالة تسجيل الخروج
  Future<void> _signOut(BuildContext context) async {
    try {
      await supabase.auth.signOut();
      // لا نحتاج لـ Navigator.pop()، الشاشة ستتحدث تلقائيًا
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('خطأ أثناء تسجيل الخروج'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ملفي الشخصي'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20.0),
        children: [
          // عرض بريد المستخدم
          Card(
            child: ListTile(
              leading: const Icon(Icons.email_outlined),
              title: const Text('البريد الإلكتروني'),
              subtitle: Text(user.email ?? 'لا يوجد بريد إلكتروني'),
            ),
          ),
          const SizedBox(height: 30),


          // ... (Card عرض البريد الإلكتروني) ...
          const SizedBox(height: 20),

// --- الزر الجديد ---
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MyOrdersScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
            ),
            child: const Text('طلباتي السابقة'),
          ),
// --- نهاية الزر الجديد ---

          const SizedBox(height: 30),
// ... (زر تسجيل الخروج) ...

          // --- زر تسجيل الخروج ---
          ElevatedButton(
            onPressed: () => _signOut(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[400],
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
            ),
            child: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );
  }
}