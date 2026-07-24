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
  final _addressDetailsController = TextEditingController();

  // --- حقل الكوبون والمتغيرات الخاصة به ---
  final _couponController = TextEditingController();
  double _discountAmount = 0.0;
  int? _appliedCouponId;
  bool _isCheckingCoupon = false;
  String? _couponErrorMessage;
  // ------------------------------------

  double _productsTotal = 0.0;
  double _deliveryCost = 0.0;
  final _formKey = GlobalKey<FormState>();

  String? _selectedGovernorate;
  final List<String> _governorates = [
    'بغداد', 'كربلاء', 'الأنبار', 'الحلة - بابل', 'البصرة', 'دهوك', 'ديالى',
    'أربيل', 'كركوك', 'العمارة - ميسان', 'السماوة - المثنى', 'النجف', 'نينوى',
    'ديوانية - القادسية', 'صلاح الدين', 'السليمانية', 'الناصرية - ذي قار', 'الكوت - واسط'
  ];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _calculateTotal();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressDetailsController.dispose();
    _couponController.dispose();
    super.dispose();
  }

  // --- دالة التحقق من الكوبون ---
  Future<void> _applyCoupon() async {
    final code = _couponController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    final phone = _phoneController.text.trim();

    FocusScope.of(context).unfocus();
    setState(() {
      _isCheckingCoupon = true;
      _couponErrorMessage = null;
    });

    try {
      final currentUser = supabase.auth.currentUser;

      // 1. البحث عن الكوبون
      final couponResponse = await supabase
          .from('coupons')
          .select()
          .eq('code', code)
          .eq('is_active', true)
          .maybeSingle();

      if (couponResponse == null) {
        setState(() {
          _couponErrorMessage = 'كود الخصم غير صحيح أو غير فعال.';
          _isCheckingCoupon = false;
        });
        return;
      }

      final int couponId = couponResponse['id'];
      final double discount = (couponResponse['discount_amount'] ?? 0).toDouble();

      // 2. التحقق من التكرار (سواء عن طريق الحساب أو رقم الهاتف)
      dynamic usageCheck;
      if (currentUser != null) {
        usageCheck = await supabase
            .from('coupon_usages')
            .select()
            .eq('coupon_id', couponId)
            .eq('user_id', currentUser.id)
            .maybeSingle();
      } else if (phone.isNotEmpty) {
        usageCheck = await supabase
            .from('coupon_usages')
            .select()
            .eq('coupon_id', couponId)
            .eq('customer_phone', phone)
            .maybeSingle();
      }

      if (usageCheck != null) {
        setState(() {
          _couponErrorMessage = 'لقد تم استخدام هذا الكوبون سابقاً!';
          _isCheckingCoupon = false;
        });
        return;
      }

      // 3. نجاح التفعيل
      setState(() {
        _discountAmount = discount;
        _appliedCouponId = couponId;
        _isCheckingCoupon = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تطبيق خصم ${_discountAmount.toStringAsFixed(0)} د.ع بنجاح!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _couponErrorMessage = 'حدث خطأ أثناء فحص الكوبون.';
        _isCheckingCoupon = false;
      });
    }
  }

  // --- دالة إرسال الطلب ---

  // --- دالة إرسال الطلب ---
  Future<void> _submitOrder() async {
    if (!_formKey.currentState!.validate()) return;

    if (mounted) setState(() => _isLoading = true);

    try {
      List<Map<String, dynamic>> cartItemsList = [];
      final currentUser = supabase.auth.currentUser;
      final prefs = await SharedPreferences.getInstance();

      if (currentUser != null) {
        final userId = currentUser.id;
        final cartData = await supabase
            .from('cart')
            .select('product_id, quantity, selected_color')
            .eq('user_id', userId);

        if (cartData.isNotEmpty) {
          cartItemsList = List<Map<String, dynamic>>.from(cartData);
        }
      } else {
        final String? cartString = prefs.getString('cartMap');
        if (cartString != null && cartString.isNotEmpty) {
          final List<dynamic> localCart = json.decode(cartString);
          cartItemsList = List<Map<String, dynamic>>.from(localCart);
        }
      }

      if (cartItemsList.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('سلة المشتريات فارغة!'), backgroundColor: Colors.red),
          );
          setState(() => _isLoading = false);
        }
        return;
      }

      final String name = _nameController.text.trim();
      final String phone = _phoneController.text.trim();

      // 🟢 1. جلب أسماء المنتجات باستخدام filter القياسي المعتمد في Supabase
      final List<int> productIds = cartItemsList
          .map((e) => int.parse(e['product_id'].toString()))
          .toList();

      final productsResponse = await supabase
          .from('products')
          .select('id, name')
          .filter('id', 'in', productIds);

      final Map<String, String> productNames = {
        for (var p in productsResponse) p['id'].toString(): p['name'].toString()
      };

      // 🟢 2. بناء نص تفاصيل الألوان بالأسماء + بناء cart_items للتريجر
      final StringBuffer colorsSummary = StringBuffer();
      final Map<String, dynamic> cartItemsMap = {};

      for (var item in cartItemsList) {
        final String productId = item['product_id'].toString();
        final int quantity = int.parse(item['quantity'].toString());
        final String color = item['selected_color']?.toString() ?? 'غير محدد';
        final String productName = productNames[productId] ?? 'منتج $productId';

        // للـ Trigger (يبقى بالـ ID كما يتوقعه التريجر)
        cartItemsMap[productId] = quantity;

        // تجميع الألوان بالعرض (باسم المنتج)
       // colorsSummary.write(' ($productName: لون $color) ');
        // 👈 توضيح العدد واللون مع اسم المنتج
        if (quantity > 1) {
          colorsSummary.write(' ($productName: $quantity قطع - لون $color) ');
        } else {
          colorsSummary.write(' ($productName: قطعة واحدة - لون $color) ');
        }

      }

      final String fullAddress = "$_selectedGovernorate، ${_addressDetailsController.text.trim()} | تفاصيل الألوان: $colorsSummary";
      final double finalTotal = (_productsTotal + _deliveryCost - _discountAmount).clamp(0, double.infinity);

      // 🟢 3. تجهيز بيانات الطلب
      final Map<String, dynamic> orderData = {
        'customer_name': name,
        'customer_phone': phone,
        'customer_address': fullAddress,        // 👈 العنوان + أسماء المنتجات والألوان
        'cart_items': cartItemsMap,             // 👈 متوافق 100% مع التريجر
        'status': 'قيد المراجعة',
        'price': _productsTotal,
        'discount_amount': _discountAmount,
        'total_amount': finalTotal,
        'user_id': currentUser?.id,
      };

      await supabase.from('orders').insert(orderData);

      // تسجيل استخدام الكوبون
      if (_appliedCouponId != null) {
        final Map<String, dynamic> usageData = {
          'coupon_id': _appliedCouponId,
          'customer_phone': phone,
          'user_id': currentUser?.id,
        };
        await supabase.from('coupon_usages').insert(usageData);
      }

      // تفريغ السلة بعد نجاح الطلب
      if (currentUser != null) {
        await supabase.from('cart').delete().eq('user_id', currentUser.id);
      } else {
        await prefs.remove('cartMap');
      }

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
      debugPrint('🛑 Supabase Order Error: $error');

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء إرسال الطلب: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
    }
  }


  // --- دالة حساب إجمالي المشتريات ---
  Future<void> _calculateTotal() async {
    double productsTotal = 0.0;
    final currentUser = supabase.auth.currentUser;

    try {
      if (currentUser != null) {
        // 1. حساب المجموع للمستخدم المسجل من Supabase
        final cartData = await supabase
            .from('cart')
            .select('quantity, products(price)')
            .eq('user_id', currentUser.id);

        for (var item in cartData) {
          final int qty = item['quantity'] as int? ?? 0;
          final product = item['products'];
          if (product != null) {
            final double price = (product['price'] ?? 0).toDouble();
            productsTotal += (price * qty);
          }
        }
      } else {
        // 2. حساب المجموع للزائر من الذاكرة المحلية
        final prefs = await SharedPreferences.getInstance();
        final String? cartString = prefs.getString('cartMap');

        if (cartString != null && cartString.isNotEmpty) {
          final List<dynamic> cartList = json.decode(cartString);

          if (cartList.isNotEmpty) {
            final List<int> productIds = cartList
                .map((e) => int.parse(e['product_id'].toString()))
                .toSet()
                .toList();

            final String filter = productIds.map((id) => 'id.eq.$id').join(',');
            final productsData = await supabase
                .from('products')
                .select('id, price')
                .or(filter);

            for (var item in cartList) {
              final int productId = int.parse(item['product_id'].toString());
              final int qty = (item['quantity'] as int? ?? 1);

              final product = productsData.firstWhere(
                    (p) => p['id'] == productId,
                orElse: () => {},
              );

              if (product.isNotEmpty) {
                final double price = (product['price'] ?? 0).toDouble();
                productsTotal += (price * qty);
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error calculating total: $e');
    }

    if (mounted) {
      setState(() {
        _productsTotal = productsTotal;
        _deliveryCost = 3000; // كلفة التوصيل الثابتة
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final double finalPrice = (_productsTotal + _deliveryCost - _discountAmount).clamp(0, double.infinity);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إتمام الطلب'),
          backgroundColor: Colors.white,
          elevation: 1,
        ),
        bottomNavigationBar: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
              if (_discountAmount > 0) ...[
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('خصم الكوبون:', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                    Text('-${_discountAmount.toStringAsFixed(0)} د.ع', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                  ],
                ),
              ],
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('الإجمالي الكلي:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(
                    '${finalPrice.toStringAsFixed(0)} د.ع',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange),
                  ),
                ],
              ),
              const SizedBox(height: 15),

              ElevatedButton(
                onPressed: _isLoading ? null : _submitOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  minimumSize: const Size(double.infinity, 50),
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
                  decoration: const InputDecoration(
                    labelText: 'الاسم الكامل',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty) ? 'الرجاء إدخال الاسم' : null,
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
                  validator: (value) => (value == null || value.trim().isEmpty) ? 'الرجاء إدخال رقم الهاتف' : null,
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedGovernorate,
                    hint: const Text('اختر المحافظة'),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.location_city),
                    ),
                    menuMaxHeight: 300,
                    isDense: true,
                    itemHeight: 50,
                    items: _governorates.map((String governorate) {
                      return DropdownMenuItem<String>(
                        value: governorate,
                        child: Text(governorate),
                      );
                    }).toList(),
                    onChanged: (newValue) => setState(() => _selectedGovernorate = newValue),
                    validator: (value) => (value == null || value.isEmpty) ? 'الرجاء اختيار المحافظة' : null,
                  ),
                ),
                const SizedBox(height: 20),

                TextFormField(
                  controller: _addressDetailsController,
                  decoration: const InputDecoration(
                    labelText: 'تفاصيل العنوان (الحي، الشارع، أقرب نقطة دالة)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_on),
                  ),
                  maxLines: 2,
                  validator: (value) => (value == null || value.trim().isEmpty) ? 'الرجاء إدخال تفاصيل العنوان' : null,
                ),
                const SizedBox(height: 30),

                // --- قسم كود الخصم (الكوبون) ---
                const Text(
                  'كود الخصم (الكوبون)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _couponController,
                        enabled: _discountAmount == 0,
                        decoration: InputDecoration(
                          hintText: 'أدخل الكود هنا',
                          border: const OutlineInputBorder(),
                          errorText: _couponErrorMessage,
                          prefixIcon: const Icon(Icons.local_offer),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: (_discountAmount > 0 || _isCheckingCoupon) ? null : _applyCoupon,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                      ),
                      child: _isCheckingCoupon
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                          : Text(_discountAmount > 0 ? 'تم الخصم' : 'تطبيق'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}