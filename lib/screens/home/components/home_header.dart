import 'package:flutter/material.dart';
import '../../search/search_screen.dart';
// تم إزالة استيراد CartScreen و ProfileScreen لأنهما ليسا مطلوبين هنا

class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // --- شريط البحث (يبقى كما هو) ---
        Expanded(
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SearchScreen()),
              );
            },
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                children: [
                  SizedBox(width: 15),
                  Icon(Icons.search, color: Colors.grey),
                  SizedBox(width: 10),
                  Text("ابحث...", style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            ),
          ),
        ),

        // --- أيقونة الكاميرا (تمت إعادتها حسب الكود الذي أرسلته) ---
        IconButton(
          onPressed: () {
            // TODO: برمجة البحث بالكاميرا
          },
          icon: const Icon(Icons.camera_alt_outlined, color: Colors.black),
        ),

        // تم إزالة:
        // IconButton(onPressed: () {...}, icon: Icon(Icons.shopping_cart_outlined)),
        // IconButton(onPressed: () {...}, icon: Icon(Icons.person_outline)),
      ],
    );
  }
}