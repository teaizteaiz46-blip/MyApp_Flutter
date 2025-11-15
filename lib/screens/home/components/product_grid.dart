import 'package:flutter/material.dart';
import '../../details/details_screen.dart'; // أضف هذا السطر
// -----------------------------------------------------------------
// الجزء الأول: ويدجت ProductGrid (يستخدم لقسم "Special for you")
// -----------------------------------------------------------------
class ProductGrid extends StatelessWidget {
  final int itemCount;
  const ProductGrid({super.key, required this.itemCount});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 20,
          mainAxisSpacing: 20,
          childAspectRatio: 0.75,
        ),
        //
        //
        // -- هذا هو السطر الذي قمنا بإصلاحه --
        // قمنا بتمرير بيانات مؤقتة ليتوقف الخطأ
        //
        itemBuilder: (context, index) {
          // بيانات مؤقتة للقسم الثابت
          const tempId = 0;
          const tempName = 'Product Name';
          const tempPrice = 99.99;
          const tempImageUrl = '';

          return GestureDetector(
            onTap: () {
              // الانتقال إلى شاشة التفاصيل
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DetailsScreen(productId: tempId),
                ),
              );
            },
            child: const ProductCard(
              imageUrl: tempImageUrl,
              name: tempName,
              price: tempPrice,
            ),
          );
        },
        //
        //
        //
      ),
    );
  }
}

// -----------------------------------------------------------------
// الجزء الثاني: ويدجت ProductCard (يستخدم في كل التطبيق)
// -----------------------------------------------------------------
class ProductCard extends StatelessWidget {
  final String imageUrl;
  final String name;
  final double price;

  const ProductCard({
    super.key,
    required this.imageUrl,
    required this.name,
    required this.price,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            //color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(15),
              ),
              child: imageUrl.isEmpty
                  ? const Icon(Icons.shopping_cart, color: Colors.grey)
                  : ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(
                        child: CircularProgressIndicator.adaptive());
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.broken_image,
                        color: Colors.grey);
                  },
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Text(
             // '\$${price.toStringAsFixed(2)}',
              '${price.toStringAsFixed(0)} د.ع',
              style: const TextStyle(
                  color: Colors.orange, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}