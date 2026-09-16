import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/shop_api.dart';
import '../../main.dart';

/// سلة الزائر تبقى بالجهاز بعد تسجيل الدخول تلقائياً،
/// وأي سلة قديمة بالحساب تنسحب من main.dart عند تسجيل الدخول.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 2, vsync: this);

  bool _isLoading = false;

  final _signInFormKey = GlobalKey<FormState>();
  final _signUpFormKey = GlobalKey<FormState>();

  final _emailLoginController = TextEditingController();
  final _passwordLoginController = TextEditingController();
  final _emailSignUpController = TextEditingController();
  final _passwordSignUpController = TextEditingController();

  @override
  void dispose() {
    _tabController.dispose();
    _emailLoginController.dispose();
    _passwordLoginController.dispose();
    _emailSignUpController.dispose();
    _passwordSignUpController.dispose();
    super.dispose();
  }

  void _showMessage(String text, {Color color = Colors.red}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), backgroundColor: color));
  }

  Future<void> _signIn() async {
    if (!_signInFormKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    try {
      await supabase.auth.signInWithPassword(
        email: _emailLoginController.text.trim(),
        password: _passwordLoginController.text.trim(),
      );
      // ProfileScreen يبدّل للحساب تلقائياً
    } on AuthException catch (error) {
      _showMessage(ShopApi.authMessage(error));
    } catch (error) {
      _showMessage(ShopApi.friendlyError(error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signUp() async {
    if (!_signUpFormKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    try {
      final res = await supabase.auth.signUp(
        email: _emailSignUpController.text.trim(),
        password: _passwordSignUpController.text.trim(),
      );
      if (res.session == null) {
        // المشروع يطلب تفعيل البريد
        _emailLoginController.text = _emailSignUpController.text.trim();
        _tabController.animateTo(0);
        _showMessage('تم إنشاء الحساب، افتح رسالة التفعيل ببريدك ثم سجّل الدخول', color: Colors.green);
      } else {
        _showMessage('تم إنشاء الحساب بنجاح', color: Colors.green);
      }
    } on AuthException catch (error) {
      _showMessage(ShopApi.authMessage(error));
    } catch (error) {
      _showMessage(ShopApi.friendlyError(error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _validateEmail(String? value) {
    final v = value?.trim() ?? '';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)) {
      return 'الرجاء إدخال بريد إلكتروني صحيح';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.trim().length < 6) {
      return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الملف الشخصي'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'تسجيل الدخول'), Tab(text: 'إنشاء حساب')],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [_buildSignInForm(), _buildSignUpForm()],
            ),
    );
  }

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
              autofillHints: const [AutofillHints.email],
              validator: _validateEmail,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _passwordLoginController,
              decoration: const InputDecoration(labelText: 'كلمة المرور'),
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              validator: _validatePassword,
              onFieldSubmitted: (_) => _signIn(),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _signIn,
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
              child: const Text('تسجيل الدخول'),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/privacy'),
              child: const Text(
                'سياسة الخصوصية لتطبيق مودو',
                style: TextStyle(color: Colors.grey, decoration: TextDecoration.underline, fontSize: 13),
              ),
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
              autofillHints: const [AutofillHints.email],
              validator: _validateEmail,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _passwordSignUpController,
              decoration: const InputDecoration(labelText: 'كلمة المرور'),
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              validator: _validatePassword,
              onFieldSubmitted: (_) => _signUp(),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _signUp,
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
              child: const Text('إنشاء حساب جديد'),
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('بإنشاء حساب، فإنك توافق على ', style: TextStyle(color: Colors.grey, fontSize: 12)),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/privacy'),
                  child: const Text(
                    'سياسة الخصوصية',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
