import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../main.dart'; // لاستخدام supabase

class DetailsScreen extends StatelessWidget {
  final int productId;

  const DetailsScreen({super.key, required this.productId});

  // --- دوال إضافة السلة (_addToCart, _addLocalCart, _addDbCart) تبقى كما هي ---
  Future<void> _addToCart(BuildContext context) async {
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) {
      await _addLocalCart(context);
    } else {
      await _addDbCart(context, currentUser.id);
    }
  }
  Future<void> _addLocalCart(BuildContext context) async {
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
        duration: const Duration(seconds: 1), // جعل الرسالة أقصر
      ),
    );
  }
  Future<void> _addDbCart(BuildContext context, String userId) async {
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
    return FutureBuilder<Map<String, dynamic>>(
      future: supabase
          .from('products')
          .select() // تأكد من جلب كل الأعمدة اللازمة
          .eq('id', productId)
          .single(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0), // AppBar شفاف مؤقت
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          print('--- DETAILS FETCH ERROR: ${snapshot.error} ---');
          return Scaffold(
            appBar: AppBar(title: const Text('خطأ')),
            body: const Center(child: Text('خطأ في تحميل تفاصيل المنتج.')),
          );
        }

        final product = snapshot.data!;

        // استخراج البيانات
        final List<dynamic> imageList = product['image_url'] ?? [];
        final String imageUrl = imageList.isNotEmpty ? imageList.first as String : '';
        final String name = product['name'] ?? 'اسم المنتج غير متوفر';
        final double price = (product['price'] ?? 0.0).toDouble();
        final String description = product['description'] ?? 'لا يتوفر وصف لهذا المنتج.';

        // --- بناء الواجهة الجديدة ---
        return Scaffold(
          // --- AppBar الجديد ---
          appBar: AppBar(
            backgroundColor: Colors.white, // أو شفاف حسب رغبتك
            elevation: 0, // إزالة الظل
            leading: IconButton( // زر الرجوع
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [ // الأيقونات على اليمين
              IconButton(
                icon: const Icon(Icons.favorite_border, color: Colors.black), // أيقونة القلب
                onPressed: () {
                  // TODO: إضافة منطق إضافة/إزالة من المفضلة
                },
              ),
            ],
          ),
          // --- زر الإضافة للسلة السفلي ---
          bottomNavigationBar: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95), // لون أبيض شبه شفاف
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 5,
                ),
              ],
              // جعل الحواف العلوية دائرية (اختياري)
              // borderRadius: const BorderRadius.only(
              //   topLeft: Radius.circular(20),
              //   topRight: Radius.circular(20),
              // ),
            ),
            child: ElevatedButton.icon( // استخدام ElevatedButton.icon لإضافة الأيقونة
              onPressed: () => _addToCart(context),
              icon: const Icon(Icons.add_shopping_cart_outlined, color: Colors.white),
              label: const Text(
                'أضف إلى السلة',
                style: TextStyle(fontSize: 20, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange, // تغيير اللون إلى بنفسجي
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                minimumSize: const Size(double.infinity, 50), // جعل الزر بعرض الشاشة
              ),
            ),
          ),
          // --- محتوى الشاشة (الصورة والتفاصيل) ---
          body: SingleChildScrollView( // جعل المحتوى قابلاً للتمرير
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, // محاذاة النصوص لليمين (للعربية)
              children: [
                // --- صورة المنتج (بحجم أكبر) ---
                AspectRatio(
                  aspectRatio: 1.1, // تعديل النسبة لتناسب التصميم (اجعلها أعلى قليلاً)
                  child: Container(
                    color: Colors.grey[200], // لون للخلفية أثناء التحميل
                    child: imageUrl.isEmpty
                        ? const Icon(Icons.hide_image_outlined, color: Colors.grey, size: 100)
                        : Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const Center(child: CircularProgressIndicator());
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.broken_image, color: Colors.grey, size: 100);
                      },
                    ),
                  ),
                ),
                // --- التفاصيل (اسم، سعر، وصف) ---
                Padding(
                  padding: const EdgeInsets.all(20.0), // إضافة حشوة حول التفاصيل
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // الاسم
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 24, // خط أكبر
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // السعر
                      Text(
                        '${price.toStringAsFixed(0)} د.ع',
                        style: TextStyle(
                          fontSize: 20, // خط متوسط
                          fontWeight: FontWeight.w600, // وزن أثقل قليلاً
                          color: Colors.orange, // تغيير اللون
                        ),
                      ),
                      const SizedBox(height: 15),
                      // الوصف
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 15, // خط أصغر قليلاً
                          color: Colors.grey[700], // لون أغمق قليلاً للوصف
                          height: 1.5, // تباعد الأسطر
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}