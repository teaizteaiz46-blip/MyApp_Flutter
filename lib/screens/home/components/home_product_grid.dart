import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../../../main.dart'; // تأكد من مسار ملف main.dart
import 'new_product_card.dart';
import '../../details/details_screen.dart';

class HomeProductGrid extends StatefulWidget {
  final int categoryId;
  final Future<List<Map<String, dynamic>>>? productsFuture;
  final bool onlyOffers;
  final bool isMix; // <-- 1. تعريف المتغير الذي يسبب الخطأ

  const HomeProductGrid({
    super.key,
    required this.categoryId,
    this.productsFuture,
    this.onlyOffers = false,
    this.isMix = false, // <-- 2. إضافته في الكونستركتور
  });

  @override
  State<HomeProductGrid> createState() => _HomeProductGridState();
}

class _HomeProductGridState extends State<HomeProductGrid> {
  final List<Map<String, dynamic>> _products = [];
  int _currentPage = 0;
  bool _isLoading = false;
  bool _hasMore = true;
  bool _isInitialLoad = true;
  bool _didError = false;
  bool _isExternalFuture = false;

  static const int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    if (widget.productsFuture != null) {
      _isExternalFuture = true;
      _hasMore = false;
      _loadExternalFuture();
    } else {
      _isExternalFuture = false;
      _fetchProducts();
    }
  }

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

  @override
  void didUpdateWidget(HomeProductGrid oldWidget) {
    super.didUpdateWidget(oldWidget);

    // التحقق من التغييرات لإعادة التحميل
    if (!_isExternalFuture &&
        (oldWidget.categoryId != widget.categoryId ||
            oldWidget.onlyOffers != widget.onlyOffers ||
            oldWidget.isMix != widget.isMix)) { // <-- التحقق من isMix

      setState(() {
        _products.clear();
        _currentPage = 0;
        _isLoading = false;
        _hasMore = true;
        _isInitialLoad = true;
        _didError = false;
      });

      _fetchProducts();
    }
  }

  // --- دالة جلب المنتجات ---
  Future<void> _fetchProducts() async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final from = _currentPage * _pageSize;
      final to = from + _pageSize - 1;

      var query = supabase.from('products').select().gt('stock', 0);

      // تطبيق الفلاتر
      if (!widget.isMix && widget.categoryId != 0) {
        query = query.eq('category_id', widget.categoryId);
      }

      if (widget.onlyOffers) {
        query = query.eq('is_offer', true);
      }

      dynamic data;

      // --- منطق الترتيب (الميكس باستخدام random_id) ---
      if (widget.isMix) {
        // يجب أن يكون لديك عمود random_id في Supabase
        data = await query
            .order('random_id', ascending: true)
            .range(from, to);
      } else {
        // الترتيب العادي حسب الأحدث
        data = await query
            .order('created_at', ascending: false)
            .range(from, to);
      }

      setState(() {
        _products.addAll(List<Map<String, dynamic>>.from(data));
        _currentPage++;
        _isLoading = false;
        _isInitialLoad = false;

        if (data.length < _pageSize) {
          _hasMore = false;
        }
      });
    } catch (e) {
      // print('Error: $e');
      setState(() {
        _isLoading = false;
        _isInitialLoad = false;
        _didError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitialLoad) {
      return const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_didError) {
      return const SliverFillRemaining(
        child: Center(child: Text('خطأ في جلب المنتجات')),
      );
    }

    if (_products.isEmpty) {
      return const SliverFillRemaining(
        child: Center(child: Text('لا توجد منتجات حاليًا.')),
      );
    }

    return SliverMasonryGrid(
      delegate: SliverChildBuilderDelegate(
            (context, index) {
          if (index >= _products.length) {
            if (!_isExternalFuture && !_isLoading) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _fetchProducts();
                }
              });
            }
            return const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 32.0),
                child: CircularProgressIndicator(),
              ),
            );
          }

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
        childCount: _products.length + (_hasMore ? 1 : 0),
      ),
      gridDelegate: const SliverSimpleGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
      ),
    );
  }
}