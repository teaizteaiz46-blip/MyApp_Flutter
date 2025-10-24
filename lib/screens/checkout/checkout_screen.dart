import 'dart:convert'; // لاستخدام json
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // لجلب السلة
import '../../main.dart'; // لاستخدام supabase

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // متغير لتتبع حالة التحميل
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  // --- تعديل دالة "إرسال الطلب" بالكامل ---
  Future<void> _submitOrder() async {
    // 1. التحقق من أن الحقول مملوءة
    if (!_formKey.currentState!.validate()) {
      return; // إذا كانت الحقول فارغة، لا تكمل
    }

    // إظهار علامة التحميل
    setState(() => _isLoading = true);

    try {
      // 2. جلب السلة من الذاكرة
      final prefs = await SharedPreferences.getInstance();
      final String? cartString = prefs.getString('cartMap');

      if (cartString == null || cartString.isEmpty) {
        // لا يوجد شيء في السلة
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('سلة المشتريات فارغة!'), backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
        return;
      }

      final Map<String, dynamic> cartMap = json.decode(cartString);

      // 3. جلب بيانات العميل من الحقول
      final String name = _nameController.text;
      final String phone = _phoneController.text;
      final String address = _addressController.text;

      // 4. إرسال الطلب إلى Supabase
      // 4. إرسال الطلب إلى Supabase

// جلب المستخدم الحالي
      final currentUser = supabase.auth.currentUser;

// إنشاء خريطة البيانات
      final Map<String, dynamic> orderData = {
        'customer_name': name,
        'customer_phone': phone,
        'customer_address': address,
        'cart_items': cartMap,
        'status': 'قيد المراجعة'
      };

// إذا كان المستخدم مسجلاً، أضف الـ ID الخاص به
      if (currentUser != null) {
        orderData['user_id'] = currentUser.id;
      }

// إرسال البيانات
      await supabase.from('orders').insert(orderData);

      // 5. مسح السلة المحلية بعد نجاح الطلب
      await prefs.remove('cartMap');

      // 6. إظهار رسالة نجاح
      Navigator.of(context).popUntil((route) => route.isFirst); // العودة للشاشة الرئيسية
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال طلبك بنجاح!'),
          backgroundColor: Colors.green,
        ),
      );

    } catch (error) {
      // 7. التعامل مع أي خطأ قد يحدث
      setState(() => _isLoading = false);
      print('--- SUBMIT ORDER ERROR: $error ---');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('حدث خطأ أثناء إرسال الطلب. الرجاء المحاولة مرة أخرى.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إتمام الطلب'),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        child: ElevatedButton(
          // التحقق من حالة التحميل
          onPressed: _isLoading ? null : _submitOrder, // تعطيل الزر أثناء التحميل
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
          // إظهار علامة تحميل أو النص
          child: _isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text(
            'تأكيد وإرسال الطلب',
            style: TextStyle(fontSize: 18, color: Colors.white),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ... (باقي كود الحقول يبقى كما هو) ...
              const Text(
                'معلومات التوصيل',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'الاسم الكامل',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'الرجاء إدخال الاسم';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'رقم الهاتف',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'الرجاء إدخال رقم الهاتف';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'العنوان بالتفصيل',
                  hintText: 'مثال: المدينة، الحي، الشارع، رقم المنزل',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'الرجاء إدخال العنوان';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}