import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../main.dart';
import '../checkout/checkout_screen.dart'; // <-- أضف هذا


class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  late Future<List<Map<String, dynamic>>> _cartProductsFuture;
  double _totalPrice = 0.0;
  bool _isLoggedIn = false; // لتتبع حالة المستخدم

  @override
  void initState() {
    super.initState();
    // التحقق من حالة المستخدم أولاً
    _isLoggedIn = supabase.auth.currentUser != null;

    // تحميل السلة المناسبة
    if (_isLoggedIn) {
      _cartProductsFuture = _loadDbCart();
    } else {
      _cartProductsFuture = _loadLocalCart();
    }
  }

  // --- دالة تحميل السلة من قاعدة البيانات (للمسجلين) ---
  Future<List<Map<String, dynamic>>> _loadDbCart() async {
    final userId = supabase.auth.currentUser!.id;

    // جلب بيانات السلة مع تفاصيل المنتج (JOIN)
    final cartData = await supabase
        .from('cart')
        .select('*, products(*)') // <-- جلب بيانات المنتج المرتبط
        .eq('user_id', userId);

    double tempTotal = 0.0;
    List<Map<String, dynamic>> productsWithQuantity = [];

    for (var item in cartData) {
      final product = item['products']; // المنتج الآن موجود بداخل السلة
      if (product == null) continue; // تخطي إذا كان المنتج محذوفًا

      final int quantity = item['quantity'] as int;
      final double price = (product['price'] ?? 0.0).toDouble();

      product['quantity'] = quantity;
      // ربط معرف السلة (cart_id) لعملية الحذف
      product['cart_id'] = item['id'];

      tempTotal += (price * quantity);
      productsWithQuantity.add(product);
    }

    setState(() => _totalPrice = tempTotal);
    return productsWithQuantity;
  }

  // --- دالة تحميل السلة المحلية (للزوار) ---
  Future<List<Map<String, dynamic>>> _loadLocalCart() async {
    final prefs = await SharedPreferences.getInstance();
    final String? cartString = prefs.getString('cartMap');
    final Map<String, dynamic> cartMap = cartString != null
        ? json.decode(cartString) as Map<String, dynamic>
        : {};

    if (cartMap.isEmpty) {
      setState(() => _totalPrice = 0.0);
      return [];
    }

    final List<int> intProductIds = cartMap.keys.map((id) => int.parse(id)).toList();

    final String filter = intProductIds.map((id) => 'id.eq.$id').join(',');
    final List<Map<String, dynamic>> productsData = await supabase
        .from('products')
        .select()
        .or(filter);

    double tempTotal = 0.0;
    List<Map<String, dynamic>> productsWithQuantity = [];

    for (var product in productsData) {
      final String productIdStr = product['id'].toString();
      final int quantity = cartMap[productIdStr] as int;
      final double price = (product['price'] ?? 0.0).toDouble();

      product['quantity'] = quantity;
      tempTotal += (price * quantity);
      productsWithQuantity.add(product);
    }

    setState(() => _totalPrice = tempTotal);
    return productsWithQuantity;
  }

  // --- دالة حذف "ذكية" ---
  Future<void> _removeFromCart(int id, bool isLocal) async {
    try { // <-- إضافة try/catch احتياطًا
      if (isLocal) {
        // --- حذف من الذاكرة المحلية (زائر) ---
        final prefs = await SharedPreferences.getInstance();
        final String? cartString = prefs.getString('cartMap');

        // إضافة تحقق أن cartString ليس null قبل استخدامه
        if (cartString != null) {
          final Map<String, dynamic> cartMap = json.decode(cartString);
          cartMap.remove(id.toString());
          await prefs.setString('cartMap', json.encode(cartMap));
        }

      } else {
        // --- حذف من قاعدة البيانات (مسجل) ---
        // هنا "id" هو معرف السلة (cart_id)
        await supabase.from('cart').delete().eq('id', id);
      }

      // --- الحل: ---
      // التحقق من "mounted" قبل استخدام context و setState
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حذف المنتج من السلة.'),
            backgroundColor: Colors.red,
          ),
        );

        // تحديث الواجهة لإعادة تحميل السلة المناسبة
        setState(() {
          if (_isLoggedIn) {
            _cartProductsFuture = _loadDbCart();
          } else {
            _cartProductsFuture = _loadLocalCart();
          }
        });
      }
    } catch (error) {
      // التعامل مع أي خطأ قد يحدث أثناء الحذف
      //print('--- REMOVE FROM CART ERROR: $error ---');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('خطأ أثناء حذف المنتج.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('سلتي'),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              // 'Total: \$${_totalPrice.toStringAsFixed(2)}', // السطر القديم
              'الإجمالي: ${_totalPrice.toStringAsFixed(0)} د.ع', // <-- التغيير هنا
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            ElevatedButton(
              onPressed: () {
                // --- هذا هو الكود المفقود ---
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CheckoutScreen()),
                );
                // --- نهاية الكود المفقود ---
              },
              style: ElevatedButton.styleFrom(
                // ... (بقية الكود) ...
              ),
              child: const Text(
                'إتمام الطلب',
                // ... (بقية الكود) ...
              ),
            ),



          ],
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _cartProductsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('خطأ في تحميل السلة.'));
          }

          final products = snapshot.data;
          if (products == null || products.isEmpty) {
            return const Center(
              child: Text(
                'سلتك فارغة.',
                style: TextStyle(fontSize: 20, color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];

              final List<dynamic> imageList = product['image_url'] ?? [];
              final String imageUrl = imageList.isNotEmpty ? imageList.first as String : '';
              final String name = product['name'] ?? 'No Name';
              final double price = (product['price'] ?? 0.0).toDouble();
              final int quantity = product['quantity'] ?? 0;

              // تحديد المعرف الصحيح للحذف
              final int idForDelete = _isLoggedIn ? product['cart_id'] : product['id'];

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  leading: imageUrl.isEmpty
                      ? Container(width: 50, color: Colors.grey[200])
                      : Image.network(imageUrl, width: 50, fit: BoxFit.cover),
                  title: Text(name),
                  subtitle: Text(
                      '${price.toStringAsFixed(0)} د.ع x $quantity = ${(price * quantity).toStringAsFixed(0)} د.ع '
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      _removeFromCart(idForDelete, !_isLoggedIn);
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}