import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../main.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _isLoading = false;

  final _signInFormKey = GlobalKey<FormState>();
  final _signUpFormKey = GlobalKey<FormState>();

  final _emailLoginController = TextEditingController();
  final _passwordLoginController = TextEditingController();

  final _emailSignUpController = TextEditingController();
  final _passwordSignUpController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    // ... (كود dispose يبقى كما هو) ...
    _tabController.dispose();
    _emailLoginController.dispose();
    _passwordLoginController.dispose();
    _emailSignUpController.dispose();
    _passwordSignUpController.dispose();
    super.dispose();
  }

  // --- دالة دمج السلة (محدثة مع onConflict) ---
  Future<void> _mergeCarts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? cartString = prefs.getString('cartMap');

      if (cartString == null) return;

      final Map<String, dynamic> localCart = json.decode(cartString);
      if (localCart.isEmpty) return;

      final String userId = supabase.auth.currentUser!.id;

      // --- هذا هو الجزء الأهم ---
      // 1. جلب السلة الحالية من قاعدة البيانات
      final dbCartData = await supabase
          .from('cart')
          .select('product_id, quantity')
          .eq('user_id', userId);

      // تحويلها إلى خريطة لسهولة الوصول
      final Map<String, int> dbCart = {
        for (var item in dbCartData)
          item['product_id'].toString(): item['quantity'] as int
      };

      // 2. دمج السلتين
      final List<Map<String, dynamic>> itemsToUpsert = [];
      for (var localEntry in localCart.entries) {
        final String productId = localEntry.key;
        final int localQuantity = localEntry.value as int;

        // التحقق من الكمية الموجودة في قاعدة البيانات
        final int dbQuantity = dbCart[productId] ?? 0;

        itemsToUpsert.add({
          'user_id': userId,
          'product_id': int.parse(productId),
          'quantity': localQuantity + dbQuantity, // <-- دمج الكميات
        });
      }
      // --- نهاية الجزء المهم ---

      // 3. إرسال القائمة المدمجة (مع onConflict)
      await supabase
          .from('cart')
          .upsert(itemsToUpsert, onConflict: 'user_id, product_id');

      await prefs.remove('cartMap');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم دمج سلة المشتريات الخاصة بك!'),
            backgroundColor: Colors.blue,
          ),
        );
      }

    } catch (error) {
      print('--- CART MERGE ERROR: $error ---');
    }
  }
  // --- نهاية دالة الدمج ---


  Future<void> _signIn() async {
    // ... (كود التحقق يبقى كما هو) ...
    if (!_signInFormKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      await supabase.auth.signInWithPassword(
        email: _emailLoginController.text.trim(),
        password: _passwordLoginController.text.trim(),
      );

      //if (mounted) await _mergeCarts();
      //if (mounted) Navigator.of(context).pop();

    } on AuthException catch (error) {
      // ... (كود معالجة الأخطاء يبقى كما هو) ...
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: ${error.message}'), backgroundColor: Colors.red));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('حدث خطأ غير متوقع'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signUp() async {
    // ... (كود التحقق يبقى كما هو) ...
    if (!_signUpFormKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      await supabase.auth.signUp(
        email: _emailSignUpController.text.trim(),
        password: _passwordSignUpController.text.trim(),
      );

      if (mounted) await _mergeCarts(); // دمج السلة عند إنشاء حساب

      if (mounted) {
        // ... (كود رسالة النجاح يبقى كما هو) ...
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إنشاء الحساب بنجاح!'), backgroundColor: Colors.green));
        _tabController.animateTo(0);
      }

    } on AuthException catch (error) {
      // ... (كود معالجة الأخطاء يبقى كما هو) ...
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: ${error.message}'), backgroundColor: Colors.red));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('حدث خطأ غير متوقع'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    // ... (كود واجهة المستخدم يبقى كما هو) ...
    return Scaffold(
      appBar: AppBar(
        title: const Text('الملف الشخصي'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'تسجيل الدخول'),
            Tab(text: 'إنشاء حساب'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
        controller: _tabController,
        children: [
          _buildSignInForm(),
          _buildSignUpForm(),
        ],
      ),
    );
  }

  // ... (دوال بناء الواجهة _buildSignInForm و _buildSignUpForm تبقى كما هي) ...
  Widget _buildSignInForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Form(
        key: _signInFormKey,
        child: Column(
          children: [
            TextFormField(
              controller: _emailLoginController,
              decoration: const InputDecoration(labelText: 'البريد الإلكتروني'),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty || !value.contains('@')) {
                  return 'الرجاء إدخال بريد إلكتروني صحيح';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _passwordLoginController,
              decoration: const InputDecoration(labelText: 'كلمة المرور'),
              obscureText: true,
              validator: (value) {
                if (value == null || value.isEmpty || value.length < 6) {
                  return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
                }
                return null;
              },
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _signIn,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('تسجيل الدخول'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignUpForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Form(
        key: _signUpFormKey,
        child: Column(
          children: [
            TextFormField(
              controller: _emailSignUpController,
              decoration: const InputDecoration(labelText: 'البريد الإلكتروني'),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty || !value.contains('@')) {
                  return 'الرجاء إدخال بريد إلكتروني صحيح';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _passwordSignUpController,
              decoration: const InputDecoration(labelText: 'كلمة المرور'),
              obscureText: true,
              validator: (value) {
                if (value == null || value.isEmpty || value.length < 6) {
                  return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
                }
                return null;
              },
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _signUp,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('إنشاء حساب جديد'),
            ),
          ],
        ),
      ),
    );
  }
}