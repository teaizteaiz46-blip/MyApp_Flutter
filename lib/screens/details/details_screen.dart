import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../main.dart'; // لاستخدام supabase
import 'package:intl/intl.dart';

class DetailsScreen extends StatefulWidget {
  final int productId;

  const DetailsScreen({super.key, required this.productId});

  @override
  State<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> {
  int _currentPage = 0;
  late PageController _pageController;

  // --- 1. تعريف الـ Future كمتغير في الـ State ---
  late Future<Map<String, dynamic>> _productFuture;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    // --- 2. جلب البيانات مرة واحدة فقط عند تهيئة الشاشة ---
    _productFuture = _fetchProductDetails();
  }

  // --- 3. إنشاء دالة منفصلة لجلب البيانات ---
  Future<Map<String, dynamic>> _fetchProductDetails() {
    return supabase
        .from('products')
        .select()
        .eq('id', widget.productId)
        .single();
  }
  // --- نهاية التعديلات ---


  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // --- دوال إضافة السلة (تبقى كما هي) ---
  Future<void> _addToCart() async {
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) {
      await _addLocalCart();
    } else {
      await _addDbCart(currentUser.id);
    }
  }

  Future<void> _addLocalCart() async {
    final prefs = await SharedPreferences.getInstance();
    final String? cartString = prefs.getString('cartMap');
    final Map<String, dynamic> cartMap = cartString != null
        ? json.decode(cartString) as Map<String, dynamic>
        : {};
    final String productIdStr = widget.productId.toString();

    if (cartMap.containsKey(productIdStr)) {
      cartMap[productIdStr] = (cartMap[productIdStr] as int) + 1;
    } else {
      cartMap[productIdStr] = 1;
    }

    await prefs.setString('cartMap', json.encode(cartMap));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تمت الإضافة للسلة! لديك ${cartMap[productIdStr]} من هذا المنتج.'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _addDbCart(String userId) async {
    try {
      final existingItem = await supabase
          .from('cart')
          .select('quantity')
          .eq('user_id', userId)
          .eq('product_id', widget.productId)
          .maybeSingle();
      int newQuantity = 1;
      if (existingItem != null) {
        newQuantity = (existingItem['quantity'] as int) + 1;
      }

      await supabase.from('cart').upsert({
        'user_id': userId,
        'product_id': widget.productId,
        'quantity': newQuantity,
      }, onConflict: 'user_id, product_id');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديث الكمية في سلة حسابك!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('خطأ في إضافة المنتج لسلة الحساب'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  // --- نهاية دوال إضافة السلة ---


  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      // --- 4. استخدام المتغير _productFuture هنا ---
      future: _productFuture,
      // --- نهاية التعديل ---
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('خطأ')),
            body: const Center(child: Text('خطأ في تحميل تفاصيل المنتج.')),
          );
        }

        final product = snapshot.data!;
        final List<dynamic> imageList = product['image_url'] ?? [];
        final String name = product['name'] ?? 'اسم المنتج غير متوفر';
        final double price = (product['price'] ?? 0.0).toDouble();
        final String description = product['description'] ?? 'لا يتوفر وصف لهذا المنتج.';
        final formatter = NumberFormat('#,###');

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ////////////////
            //actions: [
            //  IconButton(
            //    icon: const Icon(Icons.favorite_border, color: Colors.black),
            //    onPressed: () {
                  // TODO: إضافة منطق إضافة/إزالة من المفضلة
            //    },
           //   ),
           // ],
            ////////////////////////////
          ),
          bottomNavigationBar: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(242),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withAlpha(51),
                  spreadRadius: 1,
                  blurRadius: 5,
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: _addToCart,
              icon: const Icon(Icons.add_shopping_cart_outlined, color: Colors.white),
              label: const Text(
                'أضف إلى السلة',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 1.1,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      PageView.builder(
                        controller: _pageController,
                        itemCount: imageList.isNotEmpty ? imageList.length : 1,
                        onPageChanged: (value) {
                          setState(() {
                            _currentPage = value;
                          });
                        },
                        itemBuilder: (context, index) {
                          if (imageList.isEmpty) {
                            return Container(
                              color: Colors.grey[200],
                              child: const Icon(Icons.hide_image_outlined, color: Colors.grey, size: 100),
                            );
                          }
                          final String imageUrl = imageList[index] as String;
                          return Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return Container(
                                  color: Colors.grey[200],
                                  child: const Center(child: CircularProgressIndicator())
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.broken_image, color: Colors.grey, size: 100)
                              );
                            },
                          );
                        },
                      ),

                      if (imageList.length > 1)
                        Positioned(
                          bottom: 15.0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(imageList.length, (index) {
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                width: _currentPage == index ? 12.0 : 8.0,
                                height: 8.0,
                                margin: const EdgeInsets.symmetric(horizontal: 4.0),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _currentPage == index
                                      ? Colors.orange
                                      : Colors.grey.withAlpha(150),
                                ),
                              );
                            }),
                          ),
                        ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${formatter.format(price)} د.ع',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[700],
                          height: 1.5,
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