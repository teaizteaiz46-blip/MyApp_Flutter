import 'package:flutter/material.dart';

class NewProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final VoidCallback onTap;

  const NewProductCard({super.key, required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // استخراج البيانات
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
        clipBehavior: Clip.antiAlias, // لقص الصورة
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- الصورة ---
            AspectRatio(
              aspectRatio: 1, // جعل الصورة مربعة
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
              padding: const EdgeInsets.all(6.0), // <-- تم تقليل الحشوة من 8 إلى 6
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- اسم المنتج ---
                  Text(
                    name,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.normal), // <-- تم تقليل الخط
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4), // <-- تم تقليل المسافة

                  // --- السعر وزر السلة (تصميم جديد) ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween, // <-- لفصل السعر عن الزر
                    crossAxisAlignment: CrossAxisAlignment.start, // لمحاذاة العناصر للأعلى
                    children: [
                      // --- عمود السعر ---
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${price.toStringAsFixed(0)} د.ع', // السعر الجديد
                            style: const TextStyle(
                              fontSize: 14, // <-- تم تقليل الخط من 18
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                          if (oldPrice > 0)
                            Text(
                              oldPrice.toStringAsFixed(0),
                              style: const TextStyle(
                                fontSize: 10, // <-- تم تقليل الخط
                                color: Colors.grey,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                        ],
                      ),

                      // --- زر إضافة السلة ---
                      GestureDetector(
                        onTap: () {
                          // TODO: إضافة منطق السلة هنا
                          // يمكنك استخدام (Provider) أو (Riverpod) لإضافة المنتج
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('تمت إضافة "$name" إلى السلة'),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100, // لون خلفية خفيف
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.add_shopping_cart_outlined,
                            color: Colors.orange,
                            size: 17, // حجم الأيقونة
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4), // <-- تم تقليل المسافة

                  // --- التقييم والمبيعات ---
                  Row(
                    children: [
                      Icon(Icons.star, color: Colors.orange[400], size: 14), // <-- تم تقليل الحجم
                      Text(
                        ' $rating',
                        style: const TextStyle(fontSize: 11, color: Colors.grey), // <-- تم تقليل الخط
                      ),
                      const Spacer(), // لدفع المبيعات إلى اليمين
                      if (salesCount > 0)
                        Text(
                          'مبيع $salesCount',
                          style: const TextStyle(fontSize: 11, color: Colors.grey), // <-- تم تقليل الخط
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