import 'dart:convert'; // لإضافة السلة المحلية
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // لإضافة السلة المحلية
import '../../../main.dart'; // لاستخدام supabase

class NewProductCard extends StatefulWidget {
  final Map<String, dynamic> product;
  final VoidCallback onTap; // هذا للانتقال للتفاصيل

  const NewProductCard({super.key, required this.product, required this.onTap});

  @override
  State<NewProductCard> createState() => _NewProductCardState();
}

class _NewProductCardState extends State<NewProductCard> {

  Future<void> _addToCart(BuildContext context) async {
    // We pass the context here because _addLocalCart and _addDbCart
    // are part of the State and 'mounted' is available.
    final currentUser = supabase.auth.currentUser;
    final int currentProductId = widget.product['id'] ?? 0;

    if (currentUser == null) {
      await _addLocalCart(currentProductId);
    } else {
      await _addDbCart(currentUser.id, currentProductId);
    }
  }

  Future<void> _addLocalCart(int productId) async {
    final prefs = await SharedPreferences.getInstance(); // <-- Async Gap
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
    await prefs.setString('cartMap', json.encode(cartMap)); // <-- Async Gap

    // --- FIX: Check if mounted ---
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تمت الإضافة للسلة! لديك ${cartMap[productIdStr]} من هذا المنتج.'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 1),
        ),
      );
    }
    // --- End Fix ---
  }

  Future<void> _addDbCart(String userId, int productId) async {
    try {
      final existingItem = await supabase
          .from('cart')
          .select('quantity')
          .eq('user_id', userId)
          .eq('product_id', productId)
          .maybeSingle(); // <-- Async Gap
      int newQuantity = 1;
      if (existingItem != null) {
        newQuantity = (existingItem['quantity'] as int) + 1;
      }
      await supabase.from('cart').upsert({ // <-- Async Gap
        'user_id': userId,
        'product_id': productId,
        'quantity': newQuantity,
      }, onConflict: 'user_id, product_id');

      // --- FIX: Check if mounted ---
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديث الكمية في سلة حسابك!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      }
      // --- End Fix ---

    } catch (error) {
      // --- FIX: Check if mounted ---
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('خطأ في إضافة المنتج لسلة الحساب'),
            backgroundColor: Colors.red,
          ),
        );
      }
      // --- End Fix ---
    }
  }


  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> product = widget.product;
    final VoidCallback onTap = widget.onTap;

    final List<dynamic> imageList = product['image_url'] ?? [];
    final String imageUrl = imageList.isNotEmpty ? imageList.first as String : '';
    final String name = product['name'] ?? 'اسم المنتج';
    final double price = (product['price'] ?? 0.0).toDouble();
    final double oldPrice = (product['old_price'] ?? 0.0).toDouble();
    final double rating = (product['rating'] ?? 0.0).toDouble();
    final int salesCount = (product['sales_count'] ?? 0);

    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
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
            Padding(
              padding: const EdgeInsets.all(6.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.normal),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                      GestureDetector(
                        onTap: () {
                          // Pass the context from the build method
                          _addToCart(context);
                        },
                        child: Container(
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
                    ],
                  ),
                  const SizedBox(height: 4),
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
}