import 'package:flutter/material.dart';
// ١. استيراد ملف الـ main.dart لنتمكن من استخدام متغير supabase
import '../../../main.dart';

class CategorySection extends StatelessWidget {
  const CategorySection({super.key});

  // ٨. دالة مساعدة لتحويل اسم الأيقونة ( كنص ) إلى أيقونة حقيقية (IconData)
  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'flash_on':
        return Icons.flash_on;
      case 'videogame_asset':
        return Icons.videogame_asset;
      case 'shopping_bag':
        return Icons.shopping_bag;
      case 'devices':
        return Icons.devices;
      case 'more_horiz':
        return Icons.more_horiz;
      default:
        return Icons.category; // أيقونة افتراضية
    }
  }

  @override
  Widget build(BuildContext context) {
    // ٢. حذفنا قائمة categories الثابتة من هنا

    // ٣. استخدام FutureBuilder لجلب البيانات
    return FutureBuilder<List<Map<String, dynamic>>>(
      // ٤. الدالة التي سيتم تنفيذها لجلب البيانات
      //    نحن نطلب من Supabase "اختيار كل شيء" من جدول "categories"
      future: supabase.from('categories').select(),

      builder: (context, snapshot) {
        // ٥. في حالة انتظار البيانات (جاري التحميل)
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // ٦. في حالة حدوث خطأ أثناء جلب البيانات
        // ٦. في حالة حدوث خطأ أثناء جلب البيانات
        if (snapshot.hasError) {
          // طباعة الخطأ في نافذة الـ Run
          print('--- SUPABASE ERROR ---');
          print(snapshot.error);
          print('----------------------');
          return const Center(child: Text('An error occurred!'));
        }
/////////////////////////////////////////////////////////////////////
        // ٧. في حالة نجاح جلب البيانات
        final categories = snapshot.data!;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(
              categories.length,
                  (index) {
                final category = categories[index];
                return CategoryCard(
                  // ٩. استخدام البيانات الحقيقية القادمة من Supabase
                  icon: _getIconData(category['icon_name']),
                  text: category['name'],
                  onTap: () {},
                );
              },
            ),
          ),
        );
      },
    );
  }
}

// ... كود CategoryCard يبقى كما هو بدون تغيير ...
class CategoryCard extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  const CategoryCard({
    super.key,
    required this.icon,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 65,
        child: Column(
          children: [
            Container(
              height: 60,
              width: 60,
              decoration: BoxDecoration(
                color: Colors.orange[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.orange[800], size: 30),
            ),
            const SizedBox(height: 5),
            Text(text, textAlign: TextAlign.center, maxLines: 2),
          ],
        ),
      ),
    );
  }
}