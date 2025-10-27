import 'dart:convert'; // لإضافة السلة المحلية
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // لإضافة السلة المحلية
import '../../../main.dart'; // لاستخدام supabase

// غير هذا السطر
// class NewProductCard extends StatelessWidget {
class NewProductCard extends StatefulWidget { // <-- أصبح StatefulWidget
  final Map<String, dynamic> product;
  final VoidCallback onTap; // هذا للانتقال للتفاصيل

  const NewProductCard({super.key, required this.product, required this.onTap});

  // أضف هذا
  @override
  State<NewProductCard> createState() => _NewProductCardState();
}

// وأضف هذا الكلاس الجديد
class _NewProductCardState extends State<NewProductCard> {

  // --- انسخ دوال إضافة السلة من details_screen.dart هنا ---
  // مع تغيير بسيط: استخدام widget.product['id'] بدلاً من productId
  Future<void> _addToCart(BuildContext context) async {
    final currentUser = supabase.auth.currentUser;
    final int currentProductId = widget.product['id'] ?? 0; // استخدم ID المنتج الحالي

    if (currentUser == null) {
      await _addLocalCart(context, currentProductId);
    } else {
      await _addDbCart(context, currentUser.id, currentProductId);
    }
  }
  Future<void> _addLocalCart(BuildContext context, int productId) async {
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
        duration: const Duration(seconds: 1),
      ),
    );
  }
  Future<void> _addDbCart(BuildContext context, String userId, int productId) async {
    try {
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
      await supabase.from('cart').upsert({
        'user_id': userId,
        'product_id': productId,
        'quantity': newQuantity,
      }, onConflict: 'user_id, product_id');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تحديث الكمية في سلة حسابك!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
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
  // --- نهاية دوال إضافة السلة ---


  @override
  Widget build(BuildContext context) {
    // --- الوصول للبيانات أصبح عبر widget.product ---
    final Map<String, dynamic> product = widget.product;
    final VoidCallback onTap = widget.onTap;
    // --- نهاية التعديل ---

    // استخراج البيانات (يبقى كما هو)
    final List<dynamic> imageList = product['image_url'] ?? [];
    final String imageUrl = imageList.isNotEmpty ? imageList.first as String : '';
    final String name = product['name'] ?? 'اسم المنتج';
    final double price = (product['price'] ?? 0.0).toDouble();
    final double oldPrice = (product['old_price'] ?? 0.0).toDouble();
    final double rating = (product['rating'] ?? 0.0).toDouble();
    final int salesCount = (product['sales_count'] ?? 0);

    return GestureDetector(
      onTap: onTap, // هذا للانتقال للتفاصيل
      child: Card(
        // ... (بقية تصميم Card يبقى كما هو) ...
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- الصورة ---
            AspectRatio(
              // ... (كود الصورة يبقى كما هو) ...
              aspectRatio: 1,
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(child: CircularProgressIndicator.adaptive());
                },
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.broken_image, color: Colors.grey, size: 40);
                },
              ),
            ),

            // --- التفاصيل ---
            Padding(
              padding: const EdgeInsets.all(6.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ... (اسم المنتج يبقى كما هو) ...
                  Text(
                    name,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.normal),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // --- السعر وزر السلة ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ... (عمود السعر يبقى كما هو) ...
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${price.toStringAsFixed(0)} د.ع',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                          if (oldPrice > 0)
                            Text(
                              oldPrice.toStringAsFixed(0),
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                        ],
                      ),

                      // --- تعديل زر السلة الصغير ---
                      GestureDetector(
                        onTap: () {
                          // استدعاء دالة الإضافة للسلة
                          _addToCart(context);
                        },
                        child: Container(
                          // ... (تصميم الزر يبقى كما هو) ...
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.add_shopping_cart_outlined,
                            color: Colors.orange,
                            size: 17,
                          ),
                        ),
                      ),
                      // --- نهاية التعديل ---
                    ],
                  ),
                  const SizedBox(height: 4),

                  // ... (التقييم والمبيعات يبقى كما هو) ...
                  Row(
                    children: [
                      Icon(Icons.star, color: Colors.orange[400], size: 14),
                      Text(
                        ' $rating',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      const Spacer(),
                      if (salesCount > 0)
                        Text(
                          'مبيع $salesCount',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                    ],
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
} // نهاية كلاس _NewProductCardState