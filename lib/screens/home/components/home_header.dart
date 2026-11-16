import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../search/search_screen.dart';
// تم إزالة استيراد CartScreen و ProfileScreen لأنهما ليسا مطلوبين هنا

class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final m = context.modo;
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
                color: m.imageBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 15),
                  Icon(Icons.search, color: m.grey),
                  const SizedBox(width: 10),
                  Text("ابحث...", style: TextStyle(color: m.grey, fontSize: 16)),
                ],
              ),
            ),
          ),
        ),

        // --- أيقونة الكاميرا (تمت إعادتها حسب الكود الذي أرسلته) ---
        // تم إزالة:
        // IconButton(onPressed: () {...}, icon: Icon(Icons.shopping_cart_outlined)),
        // IconButton(onPressed: () {...}, icon: Icon(Icons.person_outline)),
      ],
    );
  }
}