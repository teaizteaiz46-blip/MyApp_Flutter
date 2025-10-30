import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../main.dart';
import '../../screens/home/home_screen.dart';


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

  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  // --- دالة "إرسال الطلب" محدثة بالكامل ---
// --- دالة "إرسال الطلب" محدثة بالكامل ---
  Future<void> _submitOrder() async {
    // 1. التحقق من أن الحقول مملوءة
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // التحقق من "mounted" قبل استخدام setState
    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      // متغير لتخزين خريطة السلة
      Map<String, dynamic>? cartMap;

      // 1. التحقق من حالة المستخدم وجلب السلة الصحيحة
      final currentUser = supabase.auth.currentUser;
      final prefs = await SharedPreferences.getInstance(); // <-- فجوة 1

      if (currentUser != null) {
        // --- المستخدم مسجل: جلب السلة من Supabase ---
        final userId = currentUser.id;
        final cartData = await supabase // <-- فجوة 2
            .from('cart')
            .select('product_id, quantity')
            .eq('user_id', userId);

        if (cartData.isEmpty) {
          cartMap = null;
        } else {
          cartMap = {
            for (var item in cartData)
              item['product_id'].toString(): item['quantity']
          };
        }
      } else {
        // --- المستخدم زائر: جلب السلة من الذاكرة المحلية ---
        final String? cartString = prefs.getString('cartMap');
        if (cartString != null && cartString.isNotEmpty) {
          cartMap = json.decode(cartString);
        } else {
          cartMap = null;
        }
      }

      // 2. التحقق مما إذا كانت السلة فارغة بالفعل
      if (cartMap == null || cartMap.isEmpty) {

        // --- الحل 1: إضافة فحص "mounted" هنا ---
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('سلة المشتريات فارغة!'), backgroundColor: Colors.red),
          );
          setState(() => _isLoading = false);
        }
        return;
      }

      // 3. جلب بيانات العميل (تبقى كما هي)
      final String name = _nameController.text;
      final String phone = _phoneController.text;
      final String address = _addressController.text;

      // 4. إرسال الطلب إلى Supabase (تبقى كما هي مع إضافة user_id)
      final Map<String, dynamic> orderData = {
        'customer_name': name,
        'customer_phone': phone,
        'customer_address': address,
        'cart_items': cartMap,
        'status': 'قيد المراجعة'
      };
      if (currentUser != null) {
        orderData['user_id'] = currentUser.id;
      }
      await supabase.from('orders').insert(orderData); // <-- فجوة 3

      // 5. مسح السلة الصحيحة بعد نجاح الطلب
      if (currentUser != null) {
        await supabase.from('cart').delete().eq('user_id', currentUser.id); // <-- فجوة 4
      } else {
        await prefs.remove('cartMap'); // <-- فجوة 5
      }

      // 6. إظهار رسالة نجاح والانتقال (الكود هنا صحيح لأنك أضفت "if (mounted)")
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
              (Route<dynamic> route) => false,
        );

        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم إرسال طلبك بنجاح!'),
              backgroundColor: Colors.green,
            ),
          );
        });
      }
    } catch (error) {
      // 7. التعامل مع الأخطاء

      // --- الحل 2: إضافة فحص "mounted" هنا ---
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('حدث خطأ أثناء إرسال الطلب. الرجاء المحاولة مرة أخرى.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    // تأكد من إيقاف التحميل حتى لو لم يكن mounted
    finally {
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      } else if (!mounted && _isLoading) {
        _isLoading = false;
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    //
    // ... واجهة المستخدم (Scaffold, Form, TextFields, Button) تبقى كما هي تمامًا ...
    //
    return Scaffold(
      appBar: AppBar(
        title: const Text('إتمام الطلب'),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        child: ElevatedButton(
          onPressed: _isLoading ? null : _submitOrder,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
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
              const Text(
                'معلومات التوصيل',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'الاسم الكامل', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)),
                validator: (value) => (value == null || value.isEmpty) ? 'الرجاء إدخال الاسم' : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'رقم الهاتف', border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone)),
                keyboardType: TextInputType.phone,
                validator: (value) => (value == null || value.isEmpty) ? 'الرجاء إدخال رقم الهاتف' : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'العنوان بالتفصيل', hintText: 'مثال: المدينة، الحي، الشارع، رقم المنزل', border: OutlineInputBorder(), prefixIcon: Icon(Icons.location_on)),
                maxLines: 3,
                validator: (value) => (value == null || value.isEmpty) ? 'الرجاء إدخال العنوان' : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}