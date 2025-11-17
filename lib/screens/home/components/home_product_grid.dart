import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../../../main.dart'; // لجلب supabase
import 'new_product_card.dart';
import '../../details/details_screen.dart';

// --- 1. التحويل إلى StatefulWidget ---
// نحتاج إلى حالة (State) لتخزين المنتجات التي تم تحميلها، الصفحة الحالية، وحالة التحميل
class HomeProductGrid extends StatefulWidget {
  final int categoryId;
  final Future<List<Map<String, dynamic>>>? productsFuture;
  final bool onlyOffers; // <-- 1. أضف هذا السطر

  const HomeProductGrid({
    super.key,
    required this.categoryId,
    this.productsFuture,
    this.onlyOffers = false, // <-- 2. أضف هذا السطر (القيمة الافتراضية false)
  });

  @override
  State<HomeProductGrid> createState() => _HomeProductGridState();
}

class _HomeProductGridState extends State<HomeProductGrid> {
  // --- 2. متغيرات الحالة الجديدة ---
  final List<Map<String, dynamic>> _products = []; // قائمة المنتجات المحملة
  int _currentPage = 0; // الصفحة الحالية
  bool _isLoading = false; // هل يجري جلب بيانات حالياً؟
  bool _hasMore = true; // هل توجد بيانات إضافية لجلبها؟
  bool _isInitialLoad = true; // هل هذا هو التحميل الأولي؟ (لعرض Spinner مركزي)
  bool _didError = false; // هل حدث خطأ؟
  bool _isExternalFuture = false; // للتعامل مع شاشة العروض (التي ترسل Future جاهز)

  // تحديد عدد المنتجات لكل صفحة
  static const int _pageSize = 10;

  @override
  void initState() {
    super.initState();

    // --- 3. التعامل مع الحالات المختلفة عند بدء التشغيل ---

    // الحالة أ: شاشة العروض (OffersScreen)
    // إذا تم تمرير Future جاهز، قم بتحميله مرة واحدة وعطّل التصفح (Pagination)
    if (widget.productsFuture != null) {
      _isExternalFuture = true;
      _hasMore = false; // لا يوجد "المزيد" لأن القائمة كاملة
      _loadExternalFuture();
    }
    // الحالة ب: الشاشة الرئيسية أو الفئات (Pagination)
    // إذا لم يتم تمرير Future، ابدأ بجلب الصفحة الأولى
    else {
      _isExternalFuture = false;
      _fetchProducts();
    }
  }

  // دالة مساعدة للتعامل مع شاشة العروض
  Future<void> _loadExternalFuture() async {
    setState(() {
      _isInitialLoad = true;
    });
    try {
      final data = await widget.productsFuture!;
      setState(() {
        _products.addAll(data);
        _isInitialLoad = false;
      });
    } catch (e) {
      setState(() {
        _isInitialLoad = false;
        _didError = true;
      });
    }
  }
/////////////
  // ... (داخل كلاس _HomeProductGridState)

  @override
  void didUpdateWidget(HomeProductGrid oldWidget) {
    super.didUpdateWidget(oldWidget);

    // التحقق مما إذا كانت الفئة قد تغيرت
    // (ولا ينطبق هذا على شاشة العروض التي تستخدم Future خارجي)
    if (!_isExternalFuture &&
        (oldWidget.categoryId != widget.categoryId ||
            oldWidget.onlyOffers != widget.onlyOffers)) {

      // 1. إعادة تعيين الحالة (Reset State)
      // هذا ضروري لإزالة المنتجات القديمة وعرض مؤشر التحميل
      setState(() {
        _products.clear(); // مسح المنتجات القديمة
        _currentPage = 0;  // البدء من الصفحة الأولى
        _isLoading = false; // إلغاء أي تحميل جاري
        _hasMore = true;    // افتراض وجود المزيد
        _isInitialLoad = true; // إظهار مؤشر التحميل المركزي
        _didError = false;
      });

      // 2. جلب المنتجات للفئة الجديدة
      _fetchProducts();
    }
  }

// ... (تستمر باقي الدوال: _fetchProducts, build, etc.)
 ////////////////
  // --- 4. دالة جلب المنتجات (النسخة المعدلة للتصفح) ---
  Future<void> _fetchProducts() async {
    // منع الطلبات المتعددة إذا كنا نحمل بالفعل أو إذا انتهت البيانات
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // حساب نطاق الجلب (Range)
      final from = _currentPage * _pageSize;
      final to = from + _pageSize - 1;

      // بناء الاستعلام الأساسي (نفس الكود السابق)
      var query = supabase.from('products').select().gt('stock', 0);
      if (widget.categoryId != 0) {
        query = query.eq('category_id', widget.categoryId);
      }

      // --- 3. أضف هذا الشرط الجديد ---
      // هذا هو الفلتر الخاص بشاشة العروض
      if (widget.onlyOffers) {
        query = query.eq('is_offer', true);
      }
      // --- نهاية الإضافة ---

      // إضافة الترتيب + نطاق التصفح (Pagination)
      final data = await query
          .order('created_at', ascending: false)
          .range(from, to);

      // تحديث الحالة بالبيانات الجديدة
      setState(() {
        _products.addAll(data); // إضافة البيانات الجديدة للقائمة الحالية
        _currentPage++; // الانتقال للصفحة التالية
        _isLoading = false;
        _isInitialLoad = false; // انتهاء التحميل الأولي

        // إذا كانت البيانات المرتجعة أقل من حجم الصفحة، فهذا يعني أننا وصلنا للنهاية
        if (data.length < _pageSize) {
          _hasMore = false;
        }
      });
    } catch (e) {
      // print('--- PRODUCT GRID PAGINATION ERROR: $e ---');
      setState(() {
        _isLoading = false;
        _isInitialLoad = false;
        _didError = true;
      });
    }
  }

  // --- 5. تعديل دالة الـ build (إزالة FutureBuilder) ---
  @override
  Widget build(BuildContext context) {
    // عرض مؤشر تحميل في المنتصف عند التحميل الأولي فقط
    if (_isInitialLoad) {
      return const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    // عرض رسالة خطأ
    if (_didError) {
      return const SliverFillRemaining(
        child: Center(child: Text('خطأ في جلب المنتجات')),
      );
    }

    // عرض رسالة إذا كانت القائمة فارغة تماماً
    if (_products.isEmpty) {
      return const SliverFillRemaining(
        child: Center(child: Text('لا توجد منتجات في هذه الفئة حاليًا.')),
      );
    }

    // بناء الشبكة + العنصر الإضافي للتحميل
    return SliverMasonryGrid(
      // ... (داخل دالة build، بعد السطر: return SliverMasonryGrid( )

      delegate: SliverChildBuilderDelegate(
            (context, index) {

          // --- هذا هو التعديل ---
          if (index >= _products.length) {
            // هذا الفهرس (index) يتم بناؤه فقط إذا كان _hasMore = true
            // (بسبب السطر: childCount: _products.length + (_hasMore ? 1 : 0))

            // التأكد أننا لا نحمل بيانات حالياً
            if (!_isExternalFuture && !_isLoading) {
              // جدولة جلب البيانات "بعد" انتهاء هذا الإطار (frame)
              WidgetsBinding.instance.addPostFrameCallback((_) {
                // نتأكد أن الويدجت ما زال موجوداً قبل الجلب
                if (mounted) {
                  _fetchProducts();
                }
              });
            }

            // إظهار مؤشر التحميل دائماً عند الوصول لهذه النقطة
            return const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 32.0),
                child: CircularProgressIndicator(),
              ),
            );
          }
          // --- نهاية التعديل ---

          // إذا كان عنصراً عادياً، اعرض بطاقة المنتج
          final product = _products[index];
          return NewProductCard(
            product: product,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DetailsScreen(productId: product['id']),
                ),
              );
            },
          );
        },
        // هذا السطر يبقى كما هو، وهو مهم جداً
        childCount: _products.length + (_hasMore ? 1 : 0),
      ),

// ... (باقي الكود: gridDelegate: ...)
      gridDelegate: const SliverSimpleGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
      ),
    );
  }
}