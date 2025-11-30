import 'package:flutter/material.dart';
import '../../main.dart'; // لاستخدام supabase
import 'components/home_header.dart';
import 'components/home_product_grid.dart';
// استيراد الشاشات لنظام التنقل السفلي
import '../auth/profile_screen.dart';
import '../cart/cart_screen.dart';
import '../categories/all_categories_screen.dart';
import '../offers/offers_screen.dart';
import '../clips/clips_screen.dart';
import '../home/components/promo_carousel.dart';
import 'package:intl/intl.dart';
import '../details/details_screen.dart';

// =================================================================
// ===== 1. الشاشة الرئيسية (Home Screen) - تحمل الـ STATE =============
// =================================================================

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  // --- 1. تعريف ScrollController ---
  final ScrollController _scrollController = ScrollController();

  late Future<List<Map<String, dynamic>>> _categoriesFuture;
  int _selectedCategoryId = 0; // 0 تعني "الكل"
  int _selectedIndex = 5; // نبدأ بـ 5 لأن "الرئيسية" هي الصفحة النشطة

  // قائمة الشاشات (STATIC)
  static final List<Widget> _screens = <Widget>[
    const ProfileScreen(),      // 0: الحساب
    const CartScreen(),         // 1: العربة
    const OffersScreen(),       // 2: العروض
    const ClipsScreen(),        // 3: رييلز
    const AllCategoriesScreen(),// 4: الفئات
    const Text('الرئيسية'),     // 5: الرئيسية (placeholder)
  ];

  @override
  void initState() {
    super.initState();
    _categoriesFuture = _fetchCategories();
  }

  // --- 2. التخلص من الكونترولر عند الخروج ---
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // دالة جلب الفئات من Supabase
  Future<List<Map<String, dynamic>>> _fetchCategories() async {
    final data = await supabase.from('categories').select().order('id', ascending: true);
    return data;
  }

  // دالة تحديث الحالة عند النقر على فئة
  void _selectCategory(int categoryId) {
    setState(() {
      _selectedCategoryId = categoryId;
    });
  }

  // --- 3. دالة النقر المعدلة (المنطق الجديد) ---
  void _onItemTapped(int index) {
    // إذا ضغط المستخدم على زر "الرئيسية" (رقم 5) وهو أصلاً في الصفحة الرئيسية
    if (index == 5 && _selectedIndex == 5) {
      setState(() {
        _selectedCategoryId = 0; // إعادة تعيين الفلتر إلى "الكل"
      });

      // الصعود إلى أعلى الصفحة بنعومة
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    } else {
      // التنقل العادي بين الصفحات
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const HomeHeader(),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: SafeArea(
        child: Builder(
          builder: (BuildContext context) {
            // إذا كانت الشاشة الحالية هي الرئيسية (5)
            if (_selectedIndex == 5) {
              return HomeScreenContent(
                selectedCategoryId: _selectedCategoryId,
                buildFlashDealsList: _buildFlashDealsList,
                scrollController: _scrollController, // <-- تمرير الكونترولر هنا
              );
            } else {
              return _screens.elementAt(_selectedIndex);
            }
          },
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'الحساب'),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_cart_outlined), label: 'العربة'),
          BottomNavigationBarItem(icon: Icon(Icons.local_offer_outlined), label: 'عروض'),
          BottomNavigationBarItem(icon: Icon(Icons.video_collection_outlined), label: 'مقاطع'),
          BottomNavigationBarItem(icon: Icon(Icons.category_outlined), label: 'الفئات'),
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'الرئيسية'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFFFF773D),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: _onItemTapped,
      ),
    );
  }

  // ----------------------------------------------------------------
  // --- الدوال المساعدة ---

  Widget _buildFlashDealsList(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: supabase
          .from('products')
          .select()
          .eq('is_offer', true)
          .gt('stock', 0)
          .limit(10),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final deals = snapshot.data!;
        final formatter = NumberFormat('#,###');

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "صفقات فلاش ⚡",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
                  ),
                  GestureDetector(
                    onTap: () => _onItemTapped(2), // الانتقال لتبويب العروض
                    child: const Text("المزيد", style: TextStyle(color: Colors.grey)),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: deals.length,
                padding: const EdgeInsets.symmetric(horizontal: 15),
                itemBuilder: (context, index) {
                  final deal = deals[index];
                  final List<dynamic> imageList = deal['image_url'] ?? [];
                  final String imageUrl = imageList.isNotEmpty ? imageList.first as String : '';
                  final double price = (deal['price'] ?? 0).toDouble();
                  final double oldPrice = (deal['old_price'] ?? 0).toDouble();
                  int discountPercent = 0;
                  if (oldPrice > 0) {
                    discountPercent = ((oldPrice - price) / oldPrice * 100).round();
                  }

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DetailsScreen(productId: deal['id']),
                        ),
                      );
                    },
                    child: Container(
                      width: 150,
                      margin: const EdgeInsets.only(right: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            height: 150,
                            width: 150,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                              image: imageUrl.isNotEmpty
                                  ? DecorationImage(
                                image: NetworkImage(imageUrl),
                                fit: BoxFit.cover,
                              )
                                  : null,
                            ),
                            child: imageUrl.isEmpty
                                ? const Icon(Icons.broken_image, color: Colors.grey)
                                : null,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${formatter.format(price)} د.ع',
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.right,
                          ),
                          if (oldPrice > 0)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  '%$discountPercent-',
                                  style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  formatter.format(oldPrice),
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCircularCategories(
      BuildContext context,
      List<Map<String, dynamic>> categories,
      ) {
    final currentSelectedId = _selectedCategoryId;
    final List<Map<String, dynamic>> tabsData = [
      {'id': 0, 'name': 'الكل'},
      ...categories
    ];

    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: tabsData.length,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        itemBuilder: (context, index) {
          final category = tabsData[index];
          final isSelected = category['id'] == currentSelectedId;

          return Padding(
            padding: const EdgeInsets.only(left: 10.0),
            child: GestureDetector(
              onTap: () {
                _selectCategory(category['id']);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFF44336) : Colors.grey[200],
                  borderRadius: BorderRadius.circular(30),
                  border: isSelected
                      ? Border.all(color: const Color(0xFFF44336))
                      : Border.all(color: Colors.grey[300]!),
                ),
                child: Center(
                  child: Text(
                    category['name'],
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// =================================================================
// ===== 2. محتوى الشاشة الرئيسية (HomeScreenContent) =============
// =================================================================

class HomeScreenContent extends StatelessWidget {
  final int selectedCategoryId;
  final Function(BuildContext) buildFlashDealsList;
  final ScrollController scrollController; // <-- 1. استقبال الكونترولر

  const HomeScreenContent({
    super.key,
    required this.buildFlashDealsList,
    required this.selectedCategoryId,
    required this.scrollController, // <-- 2. مطلوب في الكونستركتور
  });

  @override
  Widget build(BuildContext context) {
    final homeScreenState = context.findAncestorStateOfType<_HomeScreenState>()!;

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: homeScreenState._categoriesFuture,
      builder: (context, snapshot) {

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('خطأ في جلب الفئات'));
        }

        final categories = snapshot.data ?? [];

        return CustomScrollView(
          controller: scrollController, // <-- 3. ربط الكونترولر هنا لتفعيل الصعود
          slivers: [
            SliverList(
              delegate: SliverChildListDelegate(
                [
                  const PromoCarousel(),
                  const SizedBox(height: 30),
                  homeScreenState._buildCircularCategories(context, categories),
                  const SizedBox(height: 20),
                  buildFlashDealsList(context),
                  const SizedBox(height: 10),
                ],
              ),
            ),

            // شبكة المنتجات
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              sliver: HomeProductGrid(
                categoryId: selectedCategoryId,
                // <-- 4. تفعيل الميكس إذا كانت الفئة "الكل" (0)
                isMix: selectedCategoryId == 0,
              ),
            ),
          ],
        );
      },
    );
  }
}