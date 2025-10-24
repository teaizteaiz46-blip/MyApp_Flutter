import 'package:flutter/material.dart';
import '../../../main.dart'; // ١. استيراد متغير supabase

class PromoCarousel extends StatelessWidget {
  const PromoCarousel({super.key});

  @override
  Widget build(BuildContext context) {
    // ٢. استخدام FutureBuilder لجلب بيانات البانر
    return FutureBuilder<List<Map<String, dynamic>>>(
      // ٣. جلب كل البيانات من جدول 'banners'
      //    سنضيف .limit(1) لجلب بانر واحد فقط
      future: supabase.from('banners').select().limit(1),

      builder: (context, snapshot) {
        // ٤. في حالة التحميل
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            height: 150,
            decoration: BoxDecoration(
              color: Colors.grey[200], // لون مؤقت أثناء التحميل
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        // ٥. في حالة الخطأ
        if (snapshot.hasError) {
          return const Center(child: Text('Error loading banner'));
        }

        // ٦. في حالة عدم وجود بيانات (الجدول فارغ)
        final banners = snapshot.data;
        if (banners == null || banners.isEmpty) {
          return const SizedBox(height: 0); // إخفاء البانر إذا كان فارغًا
        }

        // ٧. في حالة النجاح، اعرض البانر بالبيانات الحقيقية
        final bannerData = banners.first; // أخذ أول بانر من القائمة
        final title = bannerData['title'] ?? 'No Title';
        final subtitle = bannerData['subtitle'] ?? '';

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          height: 150,
          decoration: BoxDecoration(
            color: Colors.orange[400], // يمكنك لاحقًا استخدام صورة من image_url
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: Text(
              "$title\n$subtitle", // ٨. عرض النصوص من قاعدة البيانات
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }
}