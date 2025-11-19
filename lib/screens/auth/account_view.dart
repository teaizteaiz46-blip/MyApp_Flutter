import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../main.dart'; // لاستخدام supabase
import '../orders/my_orders_screen.dart';

class AccountView extends StatefulWidget {
  final User user;
  const AccountView({super.key, required this.user});

  @override
  State<AccountView> createState() => _AccountViewState();
}

class _AccountViewState extends State<AccountView> {

  // دالة تسجيل الخروج
  Future<void> _signOut() async {
    try {
      await supabase.auth.signOut();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('خطأ أثناء تسجيل الخروج'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // --- دالة حذف الحساب (الجديدة) ---
  Future<void> _deleteAccount() async {
    // إظهار تحذير تأكيد أولاً
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الحساب نهائياً'),
        content: const Text('هل أنت متأكد؟ سيتم حذف جميع بياناتك وطلباتك ولا يمكن التراجع عن هذا الإجراء.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('نعم، احذف حسابي'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // استدعاء الدالة التي أنشأناها في Supabase
      await supabase.rpc('delete_own_account');
      // 2. (التعديل المهم) تسجيل الخروج محلياً لإجبار التطبيق على العودة لشاشة الدخول
      await supabase.auth.signOut();

      // بعد الحذف، سيقوم Supabase بتسجيل الخروج تلقائياً
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف الحساب بنجاح.'), backgroundColor: Colors.green),
        );
        // الآن الـ StreamBuilder في main.dart سيكتشف تسجيل الخروج ويعيد المستخدم للبداية
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
      // ننتقل للشاشة الرئيسية أو تسجيل الدخول (StreamBuilder سيتكفل بالباقي)

    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء الحذف: $error'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;

    return Scaffold(
      appBar: AppBar(title: const Text('ملفي الشخصي')),
      body: ListView(
        padding: const EdgeInsets.all(20.0),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.email_outlined),
              title: const Text('البريد الإلكتروني'),
              subtitle: Text(user.email ?? 'لا يوجد بريد إلكتروني'),
            ),
          ),
          const SizedBox(height: 20),

          ElevatedButton(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const MyOrdersScreen()));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
            ),
            child: const Text('طلباتي السابقة'),
          ),

          const SizedBox(height: 30),

          ElevatedButton(
            onPressed: _signOut,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[700],
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
            ),
            child: const Text('تسجيل الخروج'),
          ),

          const SizedBox(height: 20),

          // --- زر حذف الحساب الجديد ---
          TextButton.icon(
            onPressed: _deleteAccount,
            icon: const Icon(Icons.delete_forever, color: Colors.red),
            label: const Text('حذف الحساب نهائياً', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}