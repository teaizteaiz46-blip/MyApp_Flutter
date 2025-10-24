import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../main.dart'; // لاستخدام supabase

class DetailsScreen extends StatelessWidget {
  final int productId;

  const DetailsScreen({super.key, required this.productId});

  // --- تمت ترقية دالة "إضافة للسلة" بالكامل ---
  Future<void> _addToCart(BuildContext context) async {
    final currentUser = supabase.auth.currentUser;

    if (currentUser == null) {
      await _addLocalCart(context);
    } else {
      await _addDbCart(context, currentUser.id);
    }
  }

  // دالة الإضافة للذاكرة المحلية (للزوار)
  Future<void> _addLocalCart(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final String? cartString = prefs.getString('cartMap');
    final Map<String, dynamic> cartMap = cartString != null
        ? json.decode(cartString) as Map<String, dynamic>
        : {};

    final String productIdStr = productId.toString();

    if (cartMap.containsKey(productIdStr)) {
      cartMap[productIdStr] = (cartMap[productIdStr] as int) + 1;
    } else {
      cartMap[productIdStr] = 1;
    }

    await prefs.setString('cartMap', json.encode(cartMap));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تمت الإضافة للسلة! لديك ${cartMap[productIdStr]} من هذا المنتج.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  // --- دالة "إضافة لقاعدة البيانات" محدثة (أصبحت أذكى) ---
  Future<void> _addDbCart(BuildContext context, String userId) async {
    try {
      // 1. التحقق من الكمية الحالية
      final existingItem = await supabase
          .from('cart')
          .select('quantity')
          .eq('user_id', userId)
          .eq('product_id', productId)
          .maybeSingle();

      int newQuantity = 1;
      if (existingItem != null) {
        newQuantity = (existingItem['quantity'] as int) + 1;
      }

      // 2. تحديث (أو إضافة) المنتج بالكمية الجديدة
      await supabase.from('cart').upsert({
        'user_id': userId,
        'product_id': productId,
        'quantity': newQuantity,
      }, onConflict: 'user_id, product_id'); // هذا يمنع التكرار

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم تحديث الكمية في سلة حسابك!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      print('--- DB CART ADD ERROR: $error ---');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('خطأ في إضافة المنتج لسلة الحساب'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  // --- نهاية التعديلات ---

  @override
  Widget build(BuildContext context) {
    // ... (باقي الكود يبقى كما هو) ...
    return FutureBuilder<Map<String, dynamic>>(
      future: supabase
          .from('products')
          .select()
          .eq('id', productId)
          .single(),
      builder: (context, snapshot) {
        // ... (كود التحميل والخطأ) ...
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Scaffold(appBar: AppBar(), body: const Center(child: Text('Error loading product details.')));
        }

        final product = snapshot.data!;
        // ... (كود استخراج البيانات) ...
        final List<dynamic> imageList = product['image_url'] ?? [];
        final String imageUrl =
        imageList.isNotEmpty ? imageList.first as String : '';
        final String name = product['name'] ?? 'No Name';
        final double price = (product['price'] ?? 0.0).toDouble();
        final String description =
            product['description'] ?? 'No description available.';

        return Scaffold(
          appBar: AppBar(title: Text(name)),
          // ... (كود bottomNavigationBar) ...
          bottomNavigationBar: Container(
            padding: const EdgeInsets.all(20),
            child: ElevatedButton(
              onPressed: () => _addToCart(context), // <--- استدعاء الدالة المحدثة
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: const Text(
                'Add to Cart',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
          ),
          // ... (كود body) ...
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ... (واجهة عرض المنتج) ...
                Container(
                  height: 300,
                  width: double.infinity,
                  color: Colors.grey[200],
                  child: imageUrl.isEmpty
                      ? const Icon(Icons.shopping_cart, color: Colors.grey, size: 100)
                      : Image.network(imageUrl, fit: BoxFit.cover),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Text(
                        '${price.toStringAsFixed(0)} د.ع', // <-- التغيير هنا
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Divider(height: 1),
                      const SizedBox(height: 20),
                      const Text('Description', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Text(description, style: const TextStyle(fontSize: 16, height: 1.5)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}


