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
  //final _addressController = TextEditingController();
  // --- أضف هذه المتغيرات الجديدة ---
  double _productsTotal = 0.0; // مجموع أسعار المنتجات
  double _deliveryCost = 0.0;  // سعر التوصيل
  // ----------------------------
  final _formKey = GlobalKey<FormState>();

  // --- أضف هذا ---
  final _addressDetailsController = TextEditingController(); // حقل جديد للتفاصيل
  String? _selectedGovernorate; // لتخزين المحافظة المختارة
  final List<String> _governorates = ['بغداد','كربلاء','الأنبار','الحلة - بابل','البصرة','دهوك','ديالى','أربيل','كركوك','العمارة - ميسان','السماوة - المثنى','النجف','نينوى','ديوانية - القادسية','صلاح الدين','السليمانية','الناصرية - ذي قار','الكوت - واسط']; // القائمة المنسدلة
  // --- نهاية الإضافة ---

  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    //_addressController.dispose();
    _addressDetailsController.dispose(); // <-- أضف هذا
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
      // --- تعديل هذا السطر ---
      final String address = "$_selectedGovernorate، ${_addressDetailsController.text}";
      // --- نهاية التعديل ---

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

  ///////////////////////
  @override
  void initState() {
    super.initState();
    _calculateTotal(); // <-- استدعاء الدالة عند بدء الشاشة
  }

  // --- دالة جديدة لحساب المجموع ---
  Future<void> _calculateTotal() async {
    double productsTotal = 0.0;
    Map<String, dynamic> cartMap = {};

    // 1. جلب محتويات السلة (نفس المنطق الذي تستخدمه في _submitOrder)
    final currentUser = supabase.auth.currentUser;
    if (currentUser != null) {
      final cartData = await supabase.from('cart').select('product_id, quantity').eq('user_id', currentUser.id);
      for (var item in cartData) {
        cartMap[item['product_id'].toString()] = item['quantity'];
      }
    } else {
      final prefs = await SharedPreferences.getInstance();
      final String? cartString = prefs.getString('cartMap');
      if (cartString != null) cartMap = json.decode(cartString);
    }

    // 2. حساب سعر المنتجات
    if (cartMap.isNotEmpty) {
      final List<int> productIds = cartMap.keys.map((e) => int.parse(e)).toList();
      final String filter = productIds.map((id) => 'id.eq.$id').join(',');
      final productsData = await supabase.from('products').select('id, price').or(filter);

      for (var product in productsData) {
        final int qty = cartMap[product['id'].toString()] ?? 0;
        final double price = (product['price'] ?? 0).toDouble();
        productsTotal += (price * qty);
      }
    }

    // 3. جلب سعر التوصيل (مبدئياً 5000 أو من جدول delivery إذا أردت)
    double deliveryCost = 3000; // قيمة افتراضية
    // إذا أردت جلبها من قاعدة البيانات لاحقاً:
    // final deliveryData = await supabase.from('delivery').select().eq('governorate', 'كربلاء المقدسة').maybeSingle();
    // if (deliveryData != null) deliveryCost = (deliveryData['delivery_cost'] ?? 0).toDouble();

    // 4. تحديث الواجهة
    if (mounted) {
      setState(() {
        _productsTotal = productsTotal;
        _deliveryCost = deliveryCost;
      });
    }
  }

  ///////////////
  @override
  Widget build(BuildContext context) {
    // --- بداية التعديل ---
    // تغليف كل شيء بـ GestureDetector
    return GestureDetector(
      onTap: () {
        // هذا السطر يخبر Flutter بإخفاء لوحة المفاتيح
        FocusScope.of(context).unfocus();
      },
      // --- نهاية التعديل ---
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إتمام الطلب'),
          backgroundColor: Colors.white,
          elevation: 1,
        ),
        ////////////////////////
        bottomNavigationBar: Container(
          padding: const EdgeInsets.all(20),
          // أضفنا shadow وزخرفة بسيطة
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.grey.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, -5))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min, // مهم جداً: يجعل العمود يأخذ أقل مساحة ممكنة
            children: [
              // --- تفاصيل الأسعار ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('مجموع المنتجات:', style: TextStyle(color: Colors.grey)),
                  Text('${_productsTotal.toStringAsFixed(0)} د.ع', style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 5),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('كلفة التوصيل:', style: TextStyle(color: Colors.grey)),
                  Text('${_deliveryCost.toStringAsFixed(0)} د.ع', style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('الإجمالي الكلي:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('${(_productsTotal + _deliveryCost).toStringAsFixed(0)} د.ع',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange)),
                ],
              ),
              const SizedBox(height: 15),

              // --- زر التأكيد (نفس الزر القديم) ---
              ElevatedButton(
                onPressed: _isLoading ? null : _submitOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  minimumSize: const Size(double.infinity, 50), // عرض كامل
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
            ],
          ),
        ),
        /////////////////////////////
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              // ... (بقية كود Form يبقى كما هو) ...
              // --- هذا هو الكود الذي يجب إضافته ---
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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

                // --- استبدل حقل العنوان القديم بهذا ---

                // --- 1. القائمة المنسدلة للمحافظة ---
                SizedBox(
                  width: 200, // 👈 حدد العرض هنا
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedGovernorate,                  hint: const Text('اختر المحافظة'),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_city),
                  ),
                  // 👇👇 هذا السطر هو الحل 👇👇
                  menuMaxHeight: 300,
                  isDense: true,      // ضغط المساحات الفارغة
                  itemHeight: 50,     // (اختياري) تحديد ارتفاع السطر الواحد بدقة
                  // 👆👆 سيجعل القائمة بطول 300 بكسل فقط والباقي سكرول 👆👆
                  items: _governorates.map((String governorate) {
                    return DropdownMenuItem<String>(
                      value: governorate,
                      child: Text(governorate),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    setState(() {
                      _selectedGovernorate = newValue;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'الرجاء اختيار المحافظة';
                    }
                    return null;
                  },
                ),
                ),
                const SizedBox(height: 20),

                // --- 2. حقل تفاصيل العنوان ---
                TextFormField(
                  controller: _addressDetailsController,
                  decoration: const InputDecoration(
                    labelText: 'تفاصيل العنوان (الحي، الشارع، أقرب نقطة دالة)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_on),
                  ),
                  maxLines: 2,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'الرجاء إدخال تفاصيل العنوان';
                    }
                    return null;
                  },
                ),
                // --- نهاية الاستبدال ---
              ],
              // --- نهاية الكود المضاف ---
            ),
          ),
        ),
      ),
    );
  }
}