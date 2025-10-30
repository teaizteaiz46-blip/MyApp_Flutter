import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../main.dart'; // لاستخدام supabase

// 1. تحويله إلى StatefulWidget
class DetailsScreen extends StatefulWidget {
  final int productId;

  const DetailsScreen({super.key, required this.productId});

  @override
  State<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> {

  // 2. نقل دوال إضافة السلة إلى الـ State
  Future<void> _addToCart() async {
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) {
      await _addLocalCart();
    } else {
      await _addDbCart(currentUser.id);
    }
  }

  Future<void> _addLocalCart() async {
    final prefs = await SharedPreferences.getInstance(); // <-- فجوة زمنية
    final String? cartString = prefs.getString('cartMap');
    final Map<String, dynamic> cartMap = cartString != null
        ? json.decode(cartString) as Map<String, dynamic>
        : {};
    final String productIdStr = widget.productId.toString(); // استخدام widget.productId

    if (cartMap.containsKey(productIdStr)) {
      cartMap[productIdStr] = (cartMap[productIdStr] as int) + 1;
    } else {
      cartMap[productIdStr] = 1;
    }

    await prefs.setString('cartMap', json.encode(cartMap)); // <-- فجوة زمنية

    // 3. إصلاح "use_build_context_synchronously"
    // التحقق من أن الشاشة لا تزال موجودة قبل استخدام context
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تمت الإضافة للسلة! لديك ${cartMap[productIdStr]} من هذا المنتج.'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _addDbCart(String userId) async {
    try {
      final existingItem = await supabase
          .from('cart')
          .select('quantity')
          .eq('user_id', userId)
          .eq('product_id', widget.productId) // استخدام widget.productId
          .maybeSingle();
      int newQuantity = 1;
      if (existingItem != null) {
        newQuantity = (existingItem['quantity'] as int) + 1;
      }

      await supabase.from('cart').upsert({ // <-- فجوة زمنية
        'user_id': userId,
        'product_id': widget.productId, // استخدام widget.productId
        'quantity': newQuantity,
      }, onConflict: 'user_id, product_id');

      // 3. إصلاح "use_build_context_synchronously"
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديث الكمية في سلة حسابك!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (error) {
      // 4. إزالة "avoid_print"
      // print('--- DB CART ADD ERROR: $error ---'); // <-- تم الحذف

      // 3. إصلاح "use_build_context_synchronously"
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('خطأ في إضافة المنتج لسلة الحساب'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  // --- نهاية دوال إضافة السلة ---


  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: supabase
          .from('products')
          .select()
          .eq('id', widget.productId) // استخدام widget.productId
          .single(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          // 4. إزالة "avoid_print"
          // print('--- DETAILS FETCH ERROR: ${snapshot.error} ---'); // <-- تم الحذف
          return Scaffold(
            appBar: AppBar(title: const Text('خطأ')),
            body: const Center(child: Text('خطأ في تحميل تفاصيل المنتج.')),
          );
        }

        final product = snapshot.data!;
        final List<dynamic> imageList = product['image_url'] ?? [];
        final String imageUrl = imageList.isNotEmpty ? imageList.first as String : '';
        final String name = product['name'] ?? 'اسم المنتج غير متوفر';
        final double price = (product['price'] ?? 0.0).toDouble();
        final String description = product['description'] ?? 'لا يتوفر وصف لهذا المنتج.';

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.favorite_border, color: Colors.black),
                onPressed: () {
                  // TODO: إضافة منطق إضافة/إزالة من المفضلة
                },
              ),
            ],
          ),
          bottomNavigationBar: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: BoxDecoration(
              // 5. إصلاح "deprecated_member_use"
              // استبدال .withOpacity(0.95) بـ .withAlpha(242)
              color: Colors.white.withAlpha(242),
              boxShadow: [
                BoxShadow(
                  // 5. إصلاح "deprecated_member_use"
                  // استبدال .withOpacity(0.2) بـ .withAlpha(51)
                  color: Colors.grey.withAlpha(51),
                  spreadRadius: 1,
                  blurRadius: 5,
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: _addToCart, // <-- استدعاء الدالة بدون context
              icon: const Icon(Icons.add_shopping_cart_outlined, color: Colors.white),
              label: const Text(
                'أضف إلى السلة',
                style: TextStyle(fontSize: 20, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 1.1,
                  child: Container(
                    color: Colors.grey[200],
                    child: imageUrl.isEmpty
                        ? const Icon(Icons.hide_image_outlined, color: Colors.grey, size: 100)
                        : Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const Center(child: CircularProgressIndicator());
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.broken_image, color: Colors.grey, size: 100);
                      },
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${price.toStringAsFixed(0)} د.ع',
                        style: const TextStyle( // <-- تم تعديل اللون هنا
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange, // <-- تم تعديل اللون هنا
                        ),
                      ),
                      const SizedBox(height: 15),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey[700],
                          height: 1.5,
                        ),
                      ),
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