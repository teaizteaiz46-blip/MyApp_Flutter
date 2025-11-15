import 'package:flutter/material.dart';
import '../../main.dart'; // لاستخدام supabase
import 'components/home_header.dart';
import 'components/home_product_grid.dart';
// استيراد الشاشات لنظام التنقل السفلي
import '../auth/profile_screen.dart';
import '../cart/cart_screen.dart';
import '../categories/all_categories_screen.dart'; // <-- أضف هذا
import '../offers/offers_screen.dart';
import '../home/components/promo_carousel.dart'; // أو المسار الصحيح لملف PromoCarousel
// <-- أضف هذا`1`
// =================================================================
// ===== 1. الشاشة الرئيسية (Home Screen) - تحمل الـ STATE =============
// =================================================================

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  // المتغيرات المطلوبة:
  late Future<List<Map<String, dynamic>>> _categoriesFuture;
  int _selectedCategoryId = 0; // لتتبع الفئة المختارة للفلترة
  int _selectedIndex = 4; // نبدأ بـ 4 لأن "الرئيسية" هي الصفحة النشطة

  // قائمة الشاشات (STATIC)
  static final List<Widget> _screens = <Widget>[
    const ProfileScreen(),      // 0: الحساب
    const CartScreen(),         // 1: العربة
    const OffersScreen(),  // 2: العروض (مؤقت)
    //const Text('شاشة الفئات'),   // 3: الفئات (مؤقت)
    const AllCategoriesScreen(),
    // هنا نستخدم HomeScreenContent الذي سيحمل المفتاح
    const Text('الرئيسية'), // وضع Text مؤقت لأن المحتوى سيعرض عبر الـ Builder
  ];

  @override
  void initState() {
    super.initState();
    _categoriesFuture = _fetchCategories();
  }

  // دالة جلب الفئات من Supabase
  Future<List<Map<String, dynamic>>> _fetchCategories() async {
    final data = await supabase.from('categories').select().order('id', ascending: true);
    return data;
  }

  // دالة تحديث الحالة عند النقر على فئة دائرية (المفتاح لتفعيل التفاعل)
  void _selectCategory(int categoryId) {
    setState(() {
      _selectedCategoryId = categoryId; // تحديث معرف الفئة
    });
  }

  // دالة تحديث فهرس الشاشة عند النقر على BottomNavigationBar
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }


  // دالة بناء الواجهة الرئيسية (Scaffold)
  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const HomeHeader(), // شريط البحث فقط
        backgroundColor: Colors.white,
        elevation: 1,
      ),

      // الحل النهائي لـ "لا يحدث شيء عند الضغط"
      body: SafeArea(
        child: Builder(
          builder: (BuildContext context) {
            // إذا كانت الشاشة الحالية هي الرئيسية (4)، نعرض المحتوى
            if (_selectedIndex == 4) {
              // الحل: إعادة إنشاء HomeScreenContent مع تمرير المفتاح
              return HomeScreenContent(
                selectedCategoryId: _selectedCategoryId, // <--- هذا هو المفتاح لإجبار التحديث
              );
            } else {
              // وإلا، نعرض الشاشة الأخرى من القائمة
              return _screens.elementAt(_selectedIndex);
            }
          },
        ),
      ),

      // شريط التنقل السفلي
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'الحساب'),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_cart_outlined), label: 'العربة'),
          BottomNavigationBarItem(icon: Icon(Icons.local_offer_outlined), label: 'عروض'),
          BottomNavigationBarItem(icon: Icon(Icons.category_outlined), label: 'الفئات'),
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'الرئيسية'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFFFF773D), // اللون البرتقالي
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: _onItemTapped, // ربط النقر بدالة التحديث
      ),
    );
  }

  // ----------------------------------------------------------------
  // --- الدوال المساعدة ---
  // ----------------------------------------------------------------

  // الدالة المساعدة لبناء شريط الفئات الدائري
  Widget _buildCircularCategories(
      BuildContext context,
      List<Map<String, dynamic>> categories,
      ) {

    // الوصول إلى قيمة ID الحالية من State الكلاس الأب
    final currentSelectedId = _selectedCategoryId;

    final List<Map<String, dynamic>> tabsData = [
      {'id': 0, 'name': 'الكل', 'image_url':'assets/images/all_category.png'},
      ...categories
    ];

    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: tabsData.length,
        itemBuilder: (context, index) {
          final category = tabsData[index];

          final isSelected = category['id'] == currentSelectedId;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            child: GestureDetector(
              onTap: () {
                // **ربط النقر بدالة التحديث مباشرة:**
                _selectCategory(category['id']);
              },
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: isSelected ? Colors.orange.shade200 : Colors.grey[200],

                    // --- هذا هو الكود الصحيح للتعامل مع الصور ---
                    backgroundImage: (category['image_url'] != null && category['image_url'].isNotEmpty)
                        ? (category['image_url'].startsWith('http')
                        ? NetworkImage(category['image_url']!) // للروابط الخارجية
                        : AssetImage(category['image_url']!) // للملفات المحلية
                    )
                        : null, // لا توجد صورة
                    child: (category['image_url'] == null || category['image_url'].isEmpty)
                        ? Icon(Icons.category, color: isSelected ? Colors.orange : Colors.grey) // أيقونة افتراضية
                        : null, // لا تظهر الأيقونة إذا كانت هناك صورة
                    // --- نهاية الكود الصحيح ---

                  ),
                  const SizedBox(height: 5),
                  Text(
                    category['name'],
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.orange : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // الدالة المساعدة لبناء اللافتة البرتقالية

  // في ملف home_screen.dart (داخل كلاس _HomeScreenState)

  // في ملف home_screen.dart (داخل كلاس _HomeScreenState)



}

// =================================================================
// ===== 2. محتوى الشاشة الرئيسية (HomeScreenContent) - يتم تحديثه تلقائياً =
// =================================================================

// =================================================================
// ===== 2. محتوى الشاشة الرئيسية (HomeScreenContent) =============
// =================================================================
// (هذا الكود يحل مشكلة الخطأ الأحمر في أسفل الشاشة)

class HomeScreenContent extends StatelessWidget {
  final int selectedCategoryId;

  const HomeScreenContent({
    super.key,
    required this.selectedCategoryId,
  });

  @override
  Widget build(BuildContext context) {
    // 1. الوصول إلى الـ State الأب
    final homeScreenState = context.findAncestorStateOfType<_HomeScreenState>()!;

    // 2. استخدام FutureBuilder لجلب الفئات
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

        // 3. الحل: استخدام CustomScrollView مع Slivers
        return CustomScrollView(
          slivers: [
            // 4. اللافتة البرتقالية والفئات (SliverList)
            SliverList(
              delegate: SliverChildListDelegate(
                [
                  //homeScreenState._buildHeroBanner(context),
                  // هذا هو البانر الديناميكي الجديد من Supabase
                  const PromoCarousel(),
                  const SizedBox(height: 30),
                  homeScreenState._buildCircularCategories(context, categories),
                  const SizedBox(height: 10),
                ],
              ),
            ),

            // 5. شبكة المنتجات (HomeProductGrid) كعنصر Sliver
            // **هذا هو التصحيح:**
            // نستخدم SliverPadding ليحيط بالـ SliverGrid
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              // يتم استدعاء HomeProductGrid مباشرة كـ "sliver"
              sliver: HomeProductGrid(categoryId: selectedCategoryId),
            ),

          ],
        );
      },
    );
  }
}


