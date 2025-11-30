import 'package:flutter/material.dart';
import '../../../main.dart'; // ١. استيراد متغير supabase
import '../../offers/offers_screen.dart';
class PromoCarousel extends StatelessWidget {
  const PromoCarousel({super.key});

  @override
  Widget build(BuildContext context) {
    // ٢. استخدام FutureBuilder لجلب بيانات البانر
    return FutureBuilder<List<Map<String, dynamic>>>(
      // ٣. جلب الأعمدة المحددة من جدول 'banners' واقتصارها على بانر واحد
      future: supabase.from('banners').select('image_url, title, subtitle').limit(1),

      builder: (context, snapshot) {

        // ٤. في حالة التحميل: عرض حاوية رمادية مع مؤشر دوران
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

        // ٥. في حالة الخطأ: عرض رسالة خطأ واضحة وطباعة الخطأ في الكونسول
        if (snapshot.hasError) {
          // طباعة الخطأ في الكونسول للمساعدة في تصحيحه
          //print('Error loading banner: ${snapshot.error}');
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            height: 150,
            decoration: BoxDecoration(
              color: Colors.red[100], // لون أحمر خفيف للإشارة للخطأ
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Center(
                child: Text(
                  'حدث خطأ أثناء تحميل البانر',
                  style: TextStyle(color: Colors.red),
                )
            ),
          );
        }

        // ٦. في حالة عدم وجود بيانات (الجدول فارغ)
        final banners = snapshot.data;
        if (banners == null || banners.isEmpty) {
          // إخفاء الويدجت تماماً إذا لم يكن هناك بيانات
          // (SizedBox.shrink أفضل من SizedBox(height: 0))
          return const SizedBox.shrink();
        }

        // ٧. في حالة النجاح، استخراج البيانات
        // نستخدم banners.first لأننا قمنا بالتحقق من أنه ليس فارغاً
        final bannerData = banners.first;

        // استخدام 'as String?' للتحويل الآمن إلى نص
        // هذا يضمن أن المتغيرات ستكون إما نص أو null
        final title = bannerData['title'] as String? ?? '';
        final subtitle = bannerData['subtitle'] as String? ?? '';
        final imageUrl = bannerData['image_url'] as String?;

        return GestureDetector( // <--- التفاف هنا لتفعيل النقر
          onTap: () {
            // ١٢. عند النقر: الانتقال إلى شاشة العروض
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const OffersScreen()),
            );
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            height: 200,
            decoration: BoxDecoration(
              color: Colors.deepOrange[400],
              borderRadius: BorderRadius.circular(20),

              // 💡 --- الظل المضاف سابقاً --- 💡
              boxShadow: [
                BoxShadow(
                  //color: Colors.black.withOpacity(0.15),
                  color: Colors.black.withAlpha(38),
                  spreadRadius: 1,
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
              // 💡 --------------------- 💡

              image: (imageUrl != null && imageUrl.isNotEmpty)
                  ? DecorationImage(
                image: NetworkImage(imageUrl),
                fit: BoxFit.cover,

                // ❌ تم إزالة colorFilter بالكامل كما طلبت

              )
                  : null,
            ),
            child: Center(
              child: Text(
                "$title\n$subtitle",
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(blurRadius: 8.0, color: Colors.black54, offset: Offset(2, 2))
                    ]
                ),
              ),
            ),
          ),
        );
        // ٨. بناء الويدجت بالبيانات الحقيقية
      },
    );
  }
}