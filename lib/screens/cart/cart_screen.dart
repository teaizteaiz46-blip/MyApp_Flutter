import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/shop_api.dart';
import '../../facebook_service.dart';
import '../../services/cart_service.dart';
import '../checkout/checkout_screen.dart';
import '../details/details_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final CartService _cart = CartService.instance;
  final NumberFormat _money = NumberFormat('#,###');

  Map<int, Map<String, dynamic>> _products = {};
  Set<int> _checkedIds = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cart.lines.addListener(_onCartChanged);
    _refresh();
  }

  @override
  void dispose() {
    _cart.lines.removeListener(_onCartChanged);
    super.dispose();
  }

  void _onCartChanged() {
    final hasUnknown = _cart.lines.value.any((l) => !_checkedIds.contains(l.productId));
    if (hasUnknown) {
      _refresh();
    } else if (mounted) {
      setState(() {});
    }
  }

  Future<void> _refresh() async {
    try {
      await _cart.load();
      final ids = _cart.lines.value.map((l) => l.productId).toSet();
      final data = await ShopApi.fetchProductsByIds(ids);
      if (!mounted) return;
      setState(() {
        _products = data;
        _checkedIds = ids;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = ShopApi.friendlyError(e);
      });
    }
  }

  // --------------------------------------------------------------------------

  static double _price(Map<String, dynamic> p) => (p['price'] as num?)?.toDouble() ?? 0;
  static int _stock(Map<String, dynamic> p) => (p['stock'] as num?)?.toInt() ?? 0;
  static List<String> _colors(Map<String, dynamic> p) =>
      ((p['colors'] as List?) ?? const []).map((e) => '$e'.trim()).where((e) => e.isNotEmpty).toList();

  int _qtyForProduct(int productId) => _cart.lines.value
      .where((l) => l.productId == productId)
      .fold(0, (sum, l) => sum + l.quantity);

  String? _problemFor(CartLine line) {
    final product = _products[line.productId];
    if (product == null) return 'هذا المنتج لم يعد متوفراً، احذفه من السلة';
    final stock = _stock(product);
    if (stock <= 0) return 'نفد من المخزون، احذفه من السلة';
    final colors = _colors(product);
    if (colors.isNotEmpty && (line.color == null || !colors.contains(line.color))) {
      return 'اللون غير محدد، اضغط على المنتج واختر اللون';
    }
    if (_qtyForProduct(line.productId) > stock) return 'المتوفر $stock قطع فقط، قلل الكمية';
    return null;
  }

  double get _total {
    var sum = 0.0;
    for (final line in _cart.lines.value) {
      final product = _products[line.productId];
      if (product != null) sum += _price(product) * line.quantity;
    }
    return sum;
  }

  void _openProduct(int productId) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DetailsScreen(productId: productId)),
    );
  }

  void _goToCheckout() {
    final messenger = ScaffoldMessenger.of(context);
    final lines = _cart.lines.value;
    if (lines.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('سلتك فارغة')));
      return;
    }
    if (lines.any((l) => _problemFor(l) != null)) {
      messenger.showSnackBar(const SnackBar(
        content: Text('عدّل المنتجات المعلّمة بالأحمر قبل إتمام الطلب'),
        backgroundColor: Colors.red,
      ));
      return;
    }
    FacebookAnalyticsService.logInitiatedCheckout(
      totalPrice: _total,
      numItems: _cart.itemCount,
    );
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CheckoutScreen()));
  }

  // --------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final lines = _cart.lines.value;

    return Scaffold(
      appBar: AppBar(title: Text(lines.isEmpty ? 'سلتي' : 'سلتي (${_cart.itemCount})')),
      bottomNavigationBar: lines.isEmpty ? null : _buildBottomBar(),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _buildBody(lines),
      ),
    );
  }

  Widget _buildBody(List<CartLine> lines) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null && _products.isEmpty && lines.isNotEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Center(child: Text(_error!, textAlign: TextAlign.center)),
          const SizedBox(height: 12),
          Center(child: TextButton(onPressed: _refresh, child: const Text('إعادة المحاولة'))),
        ],
      );
    }

    if (lines.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 120),
          Icon(Icons.shopping_cart_outlined, size: 72, color: Colors.grey),
          SizedBox(height: 16),
          Center(
            child: Text('سلتك فارغة', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ),
          SizedBox(height: 6),
          Center(
            child: Text(
              'أضف منتجات من الصفحة الرئيسية وراح تظهر هنا.',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      itemCount: lines.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _buildLine(lines[index]),
    );
  }

  Widget _buildLine(CartLine line) {
    final product = _products[line.productId];
    final problem = _problemFor(line);
    final images = ((product?['image_url'] as List?) ?? const []).map((e) => '$e').toList();
    final imageUrl = images.isNotEmpty ? images.first : '';
    final name = (product?['name'] ?? 'منتج غير متوفر').toString();
    final price = product == null ? 0.0 : _price(product);
    final stock = product == null ? 0 : _stock(product);
    final maxQty = stock < CartService.maxQuantityPerLine ? stock : CartService.maxQuantityPerLine;
    final canIncrease = product != null && line.quantity < maxQty;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: problem != null ? Colors.red.shade200 : Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: product == null ? null : () => _openProduct(line.productId),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 76,
                height: 76,
                color: Colors.grey[200],
                child: imageUrl.isEmpty
                    ? const Icon(Icons.image_not_supported_outlined, color: Colors.grey)
                    : Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.broken_image, color: Colors.grey),
                      ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: product == null ? null : () => _openProduct(line.productId),
                  child: Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                if (line.color != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('اللون: ${line.color}', style: TextStyle(color: Colors.grey[700])),
                  ),
                const SizedBox(height: 4),
                Text(
                  '${_money.format(price)} د.ع',
                  style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold),
                ),
                if (problem != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(problem, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _QtyButton(
                      icon: line.quantity <= 1 ? Icons.delete_outline : Icons.remove,
                      color: line.quantity <= 1 ? Colors.red : null,
                      tooltip: line.quantity <= 1 ? 'حذف' : 'إنقاص',
                      onPressed: () => line.quantity <= 1
                          ? _cart.remove(line)
                          : _cart.setQuantity(line, line.quantity - 1),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        '${line.quantity}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    _QtyButton(
                      icon: Icons.add,
                      tooltip: 'زيادة',
                      onPressed: canIncrease ? () => _cart.setQuantity(line, line.quantity + 1) : null,
                    ),
                    const Spacer(),
                    if (product != null)
                      Text(
                        '${_money.format(price * line.quantity)} د.ع',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('المجموع (بدون التوصيل)', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  Text(
                    '${_money.format(_total)} د.ع',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: _goToCheckout,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('إتمام الطلب', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({required this.icon, required this.onPressed, required this.tooltip, this.color});

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 34,
      child: IconButton.outlined(
        padding: EdgeInsets.zero,
        iconSize: 18,
        tooltip: tooltip,
        color: color,
        onPressed: onPressed,
        icon: Icon(icon),
      ),
    );
  }
}
