import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/shop_api.dart';
import '../../facebook_service.dart';
import '../../services/cart_service.dart';
import '../../widgets/welcome_coupon_dialog.dart' show kPendingCouponKey;
import '../home/home_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  static const _kName = 'checkout_name';
  static const _kPhone = 'checkout_phone';
  static const _kGovernorate = 'checkout_governorate';
  static const _kAddress = 'checkout_address';

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _couponController = TextEditingController();
  final NumberFormat _money = NumberFormat('#,###');
  final CartService _cart = CartService.instance;

  String? _governorate;
  Map<String, double> _deliveryCosts = {};
  Map<int, Map<String, dynamic>> _products = {};

  bool _loading = true;
  bool _submitting = false;
  String? _loadError;

  String? _appliedCoupon;
  double _couponAmount = 0;
  bool _checkingCoupon = false;
  String? _couponError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _couponController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      await _cart.load();
      final prefs = await SharedPreferences.getInstance();
      final results = await Future.wait([
        ShopApi.fetchProductsByIds(_cart.lines.value.map((l) => l.productId)),
        ShopApi.fetchDeliveryCosts(),
      ]);
      if (!mounted) return;

      final savedGov = prefs.getString(_kGovernorate);
      final pendingCoupon = (prefs.getString(kPendingCouponKey) ?? '').trim();
      setState(() {
        _products = results[0] as Map<int, Map<String, dynamic>>;
        _deliveryCosts = results[1] as Map<String, double>;
        _nameController.text = prefs.getString(_kName) ?? '';
        _phoneController.text = prefs.getString(_kPhone) ?? '';
        _addressController.text = prefs.getString(_kAddress) ?? '';
        _governorate = kIraqGovernorates.contains(savedGov) ? savedGov : null;
        _loading = false;
        if (pendingCoupon.isNotEmpty) _couponController.text = pendingCoupon;
      });
      // كوبون الترحيب المحفوظ ينطبق تلقائياً
      if (pendingCoupon.isNotEmpty) _applyCoupon();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = ShopApi.friendlyError(e);
      });
    }
  }

  Future<void> _saveCustomerInfo(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kName, _nameController.text.trim());
    await prefs.setString(_kPhone, phone);
    await prefs.setString(_kAddress, _addressController.text.trim());
    if (_governorate != null) await prefs.setString(_kGovernorate, _governorate!);
    if (_appliedCoupon != null) await prefs.remove(kPendingCouponKey);
  }

  // --------------------------------------------------------------------------

  double get _subtotal {
    var sum = 0.0;
    for (final line in _cart.lines.value) {
      final price = (_products[line.productId]?['price'] as num?)?.toDouble() ?? 0;
      sum += price * line.quantity;
    }
    return sum;
  }

  double get _delivery => ShopApi.deliveryFor(_governorate, _deliveryCosts);

  double get _discount => _couponAmount > _subtotal ? _subtotal : _couponAmount;

  double get _total {
    final t = _subtotal + _delivery - _discount;
    return t < 0 ? 0 : t;
  }

  // --------------------------------------------------------------------------

  Future<void> _applyCoupon() async {
    FocusScope.of(context).unfocus();
    final code = _couponController.text.trim();
    if (code.isEmpty) {
      setState(() => _couponError = 'أدخل كود الخصم');
      return;
    }
    setState(() {
      _checkingCoupon = true;
      _couponError = null;
    });
    try {
      final result = await ShopApi.validateCoupon(
        code,
        phone: ShopApi.normalizePhone(_phoneController.text),
      );
      if (!mounted) return;
      setState(() {
        _checkingCoupon = false;
        if (result.valid) {
          _appliedCoupon = code;
          _couponAmount = result.discount;
        } else {
          _couponError = result.message;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _checkingCoupon = false;
        _couponError = ShopApi.friendlyError(e);
      });
    }
  }

  void _removeCoupon() {
    setState(() {
      _appliedCoupon = null;
      _couponAmount = 0;
      _couponError = null;
      _couponController.clear();
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final lines = List<CartLine>.of(_cart.lines.value);

    if (lines.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('سلة المشتريات فارغة'), backgroundColor: Colors.red));
      return;
    }

    final phone = ShopApi.normalizePhone(_phoneController.text)!;
    setState(() => _submitting = true);

    try {
      final result = await ShopApi.placeOrder(
        lines: lines,
        customerName: _nameController.text,
        customerPhone: phone,
        governorate: _governorate!,
        address: _addressController.text,
        couponCode: _appliedCoupon,
      );

      await _saveCustomerInfo(phone);
      await _cart.clear();

      FacebookAnalyticsService.logPurchase(
        amount: result.total,
        productIds: lines.map((l) => l.productId).toSet().toList(),
        numItems: lines.fold(0, (sum, l) => sum + l.quantity),
        orderId: result.orderId,
      );

      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (_) => false,
      );
      messenger.showSnackBar(SnackBar(
        content: Text('تم إرسال طلبك رقم ${result.orderId} بنجاح، راح نتواصل وياك للتأكيد'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 5),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      messenger.showSnackBar(SnackBar(
        content: Text(ShopApi.friendlyError(e)),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ));
    }
  }

  // --------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(title: const Text('إتمام الطلب'), backgroundColor: Colors.white, elevation: 1),
        bottomNavigationBar: _loading || _loadError != null ? null : _buildTotals(),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_loadError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_loadError!, textAlign: TextAlign.center),
            TextButton(
              onPressed: () {
                setState(() {
                  _loading = true;
                  _loadError = null;
                });
                _load();
              },
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SectionTitle('معلومات التوصيل'),
            TextFormField(
              controller: _nameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'الاسم الكامل',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'الرجاء إدخال الاسم' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'رقم الهاتف',
                hintText: '07XXXXXXXXX',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              validator: (v) => ShopApi.normalizePhone(v ?? '') == null
                  ? 'رقم غير صحيح، اكتبه بصيغة 07XXXXXXXXX'
                  : null,
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _governorate,
              isExpanded: true,
              menuMaxHeight: 360,
              hint: const Text('اختر المحافظة'),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_city_outlined),
              ),
              items: [
                for (final gov in kIraqGovernorates)
                  DropdownMenuItem(value: gov, child: Text(gov)),
              ],
              onChanged: (value) => setState(() => _governorate = value),
              validator: (v) => v == null ? 'الرجاء اختيار المحافظة' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _addressController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'تفاصيل العنوان',
                hintText: 'المنطقة، الشارع، أقرب نقطة دالة',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'الرجاء إدخال تفاصيل العنوان' : null,
            ),
            const SizedBox(height: 24),
            const _SectionTitle('طلبك'),
            _buildItemsSummary(),
            const SizedBox(height: 24),
            const _SectionTitle('كود الخصم'),
            _buildCoupon(),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.payments_outlined, color: Colors.grey[700], size: 20),
                const SizedBox(width: 6),
                Text('الدفع نقداً عند الاستلام', style: TextStyle(color: Colors.grey[700])),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsSummary() {
    final lines = _cart.lines.value;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          for (final line in lines)
            ListTile(
              dense: true,
              title: Text(
                (_products[line.productId]?['name'] ?? 'منتج غير متوفر').toString(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                [
                  '${line.quantity} × ${_money.format((_products[line.productId]?['price'] as num?) ?? 0)} د.ع',
                  if (line.color != null) 'اللون: ${line.color}',
                ].join('   '),
              ),
              trailing: Text(
                '${_money.format((((_products[line.productId]?['price'] as num?) ?? 0) * line.quantity))} د.ع',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCoupon() {
    if (_appliedCoupon != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade700),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'الكود $_appliedCoupon: خصم ${_money.format(_discount)} د.ع',
                style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(onPressed: _removeCoupon, child: const Text('إزالة')),
          ],
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: _couponController,
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) {
              if (_couponError != null) setState(() => _couponError = null);
            },
            decoration: InputDecoration(
              hintText: 'أدخل الكود',
              border: const OutlineInputBorder(),
              errorText: _couponError,
              prefixIcon: const Icon(Icons.local_offer_outlined),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: _checkingCoupon ? null : _applyCoupon,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black87,
              foregroundColor: Colors.white,
            ),
            child: _checkingCoupon
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text('تطبيق'),
          ),
        ),
      ],
    );
  }

  Widget _buildTotals() {
    Widget row(String label, String value, {Color? color, bool bold = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(color: color ?? Colors.grey[700], fontWeight: bold ? FontWeight.bold : null, fontSize: bold ? 17 : 14)),
              Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: bold ? 17 : 14)),
            ],
          ),
        );

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            row('مجموع المنتجات', '${_money.format(_subtotal)} د.ع'),
            row(
              'التوصيل',
              _governorate == null ? 'حسب المحافظة' : '${_money.format(_delivery)} د.ع',
            ),
            if (_discount > 0)
              row('الخصم', '-${_money.format(_discount)} د.ع', color: Colors.green.shade700),
            const Divider(height: 16),
            row('الإجمالي', '${_money.format(_total)} د.ع', bold: true),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Text('تأكيد وإرسال الطلب', style: TextStyle(fontSize: 17)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }
}
