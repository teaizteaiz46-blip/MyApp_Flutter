import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../main.dart'; // لاستخدام supabase
import 'package:intl/intl.dart';
// 1. استيراد حزمة فيسبوك
import 'package:facebook_app_events/facebook_app_events.dart';

class DetailsScreen extends StatefulWidget {
  final int productId;

  const DetailsScreen({super.key, required this.productId});

  @override
  State<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> {
  int _currentPage = 0;
  late PageController _pageController;
  late Future<Map<String, dynamic>> _productFuture;

  // 2. تعريف متغير التتبع
  static final facebookAppEvents = FacebookAppEvents();

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _productFuture = _fetchProductDetails();
  }

  Future<Map<String, dynamic>> _fetchProductDetails() async {
    final data = await supabase
        .from('products')
        .select()
        .eq('id', widget.productId)
        .single();

    // 3. تتبع "مشاهدة محتوى" عند تحميل البيانات
    facebookAppEvents.logViewContent(
      id: widget.productId.toString(),
      type: 'product',
      currency: 'IQD',
      price: (data['price'] ?? 0.0).toDouble(),
    );

    return data;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _addToCart() async {
    // نحتاج لجلب السعر أولاً للتتبع (يمكن تحسينه بتمريره للدالة)
    // هنا سنعتمد على أن البيانات قد تم تحميلها
    final productData = await _productFuture;
    final double price = (productData['price'] ?? 0.0).toDouble();

    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) {
      await _addLocalCart(price);
    } else {
      await _addDbCart(currentUser.id, price);
    }
  }

  Future<void> _addLocalCart(double price) async {
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

    // 4. تتبع "إضافة للسلة" (زائر)
    facebookAppEvents.logAddToCart(
      id: widget.productId.toString(),
      type: 'product',
      currency: 'IQD',
      price: price,
    );

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

  Future<void> _addDbCart(String userId, double price) async {
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

      // 5. تتبع "إضافة للسلة" (مسجل)
      facebookAppEvents.logAddToCart(
        id: widget.productId.toString(),
        type: 'product',
        currency: 'IQD',
        price: price,
      );

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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _productFuture,
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
            // تمت إزالة زر المفضلة لتنظيف الكود كما في نسختك
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
                style: TextStyle(fontSize: 20, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
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
                          // --- استخدام GestureDetector للنقر وفتح الشاشة الكاملة ---
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => FullScreenImageViewer(
                                    imageUrls: imageList,
                                    initialIndex: index,
                                  ),
                                ),
                              );
                            },
                            child: Image.network(
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
                            ),
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

// --- كلاس عارض الصور بالحجم الكامل ---
class FullScreenImageViewer extends StatelessWidget {
  final List<dynamic> imageUrls;
  final int initialIndex;

  const FullScreenImageViewer({
    super.key,
    required this.imageUrls,
    required this.initialIndex,
  });

  @override
  Widget build(BuildContext context) {
    PageController pageController = PageController(initialPage: initialIndex);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: PageView.builder(
        controller: pageController,
        itemCount: imageUrls.length,
        itemBuilder: (context, index) {
          final String imageUrl = imageUrls[index] as String;
          return InteractiveViewer(
            panEnabled: true,
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(child: CircularProgressIndicator(color: Colors.white));
                },
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.broken_image, color: Colors.grey, size: 100);
                },
              ),
            ),
          );
        },
      ),
    );
  }
}