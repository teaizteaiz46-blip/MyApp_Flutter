import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../facebook_service.dart';
import '../../../services/cart_service.dart';
// import 'fitting_room_sheet.dart'; // 👈 غرفة القياس الافتراضية (الميزة ملغية حالياً، شوف الزر المعلّق تحت)

class NewProductCard extends StatefulWidget {
  final Map<String, dynamic> product;
  final VoidCallback onTap;

  const NewProductCard({super.key, required this.product, required this.onTap});

  @override
  State<NewProductCard> createState() => _NewProductCardState();
}

class _NewProductCardState extends State<NewProductCard> {
  static final NumberFormat _money = NumberFormat('#,###');
  int _currentPage = 0;

  Future<void> _addToCart() async {
    final product = widget.product;
    final productId = (product['id'] as num?)?.toInt();
    if (productId == null) return;

    final messenger = ScaffoldMessenger.of(context);
    final colors = (product['colors'] as List?) ?? const [];

    // المنتج الي بي ألوان لازم ينختار لونه من صفحة التفاصيل
    if (colors.isNotEmpty) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('اختر اللون من صفحة المنتج'),
          duration: Duration(seconds: 2),
        ));
      widget.onTap();
      return;
    }

    try {
      await CartService.instance.add(productId);
      FacebookAnalyticsService.logAddToCart(
        id: '$productId',
        price: (product['price'] as num?)?.toDouble() ?? 0,
      );
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('تمت الإضافة للسلة'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ));
    } catch (e) {
      messenger.showSnackBar(const SnackBar(
        content: Text('تعذر حفظ السلة، حاول مرة ثانية'),
        backgroundColor: Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final List<dynamic> imageList = product['image_url'] ?? [];
    final String name = product['name'] ?? 'اسم المنتج';
    final double price = (product['price'] as num?)?.toDouble() ?? 0;
    final double oldPrice = (product['old_price'] as num?)?.toDouble() ?? 0;
    final double rating = (product['rating'] as num?)?.toDouble() ?? 0;
    final int salesCount = (product['sales_count'] as num?)?.toInt() ?? 0;

    return GestureDetector(
      onTap: widget.onTap,
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  PageView.builder(
                    itemCount: imageList.isNotEmpty ? imageList.length : 1,
                    onPageChanged: (value) => setState(() => _currentPage = value),
                    itemBuilder: (context, index) {
                      if (imageList.isEmpty) {
                        return const Icon(Icons.broken_image, color: Colors.grey, size: 40);
                      }
                      return Image.network(
                        '${imageList[index]}',
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) => progress == null
                            ? child
                            : const Center(child: CircularProgressIndicator.adaptive()),
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.broken_image, color: Colors.grey, size: 40),
                      );
                    },
                  ),
                  if (imageList.length > 1)
                    Positioned(
                      bottom: 8.0,
                      child: Row(
                        children: List.generate(imageList.length, (index) {
                          return Container(
                            width: 8.0,
                            height: 8.0,
                            margin: const EdgeInsets.symmetric(horizontal: 4.0),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.orange.withAlpha(_currentPage == index ? 230 : 102),
                            ),
                          );
                        }),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(6.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontSize: 13),
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
                            '${_money.format(price)} د.ع',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepOrange,
                            ),
                          ),
                          if (oldPrice > 0)
                            Text(
                              '${_money.format(oldPrice)} د.ع',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                        ],
                      ),
                      // --- أزرار التحكم: (زر غرفة القياس + زر إضافة السلة) ---
                      Row(
                        children: [
                          // 1. زر غرفة القياس الافتراضية
                          // ❌ تم إلغاء ميزة غرفة القياس واختصار الأيقونة
                          /*
                          GestureDetector(
                            onTap: () {
                              if (imageList.isNotEmpty) {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (context) => FittingRoomBottomSheet(
                                    garmentImageUrl: imageList.first as String,
                                  ),
                                );
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.purple.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.checkroom_outlined, // أيقونة علاقة الملابس
                                color: Colors.purple,
                                size: 17,
                              ),
                            ),
                          ),

                          const SizedBox(width: 5), // مسافة بين الزرين
                          */
                          // 2. زر إضافة السلة
                          InkWell(
                            onTap: _addToCart,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.deepOrange.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.add_shopping_cart_outlined,
                                color: Colors.deepOrange,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.star, color: Colors.deepOrange[400], size: 14),
                      Text(' $rating', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      const Spacer(),
                      if (salesCount > 0)
                        Text('مبيع $salesCount', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
