import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/bulk_pricing.dart';
import '../../core/product_options.dart';
import '../../core/shop_api.dart';
import '../../facebook_service.dart';
import '../../main.dart' show supabase;
import '../../services/points_service.dart';
import '../../services/cart_service.dart';
import '../../services/push_service.dart';
import '../../widgets/welcome_coupon_dialog.dart' show kPendingCouponKey;
import '../home/home_screen.dart';
import '../orders/my_orders_screen.dart' show RewardCouponCard;

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

  /// كوبون المكافأة المحفوظ بالحساب (خصم % بعد استلام طلب سابق)
  Map<String, dynamic>? _reward;
  bool _useReward = false;

  /// نقاط MODO: النقطة = 10 د.ع، لحد 20% من المجموع
  bool _usePoints = false;

  /// كود دعوة صديقة (الطلب الأول بس)
  final _referralController = TextEditingController();
  String? _referralCode;
  String? _referralMsg;
  bool _referralOk = false;
  bool _checkingReferral = false;

  /// خيارات الطلب الجاهزة (من قاعدة البيانات) والي اختارها الزبون
  List<String> _orderOptions = const [];
  final Set<String> _selectedOptions = {};

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
    _referralController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      await _cart.load();
      final prefs = await SharedPreferences.getInstance();
      final results = await Future.wait([
        ShopApi.fetchProductsByIds(_cart.lines.value.map((l) => l.productId)),
        ShopApi.fetchDeliveryCosts(),
        ShopApi.fetchOrderOptions(),
      ]);
      if (!mounted) return;

      final savedGov = prefs.getString(_kGovernorate);
      final pendingCoupon = (prefs.getString(kPendingCouponKey) ?? '').trim();
      setState(() {
        _products = results[0] as Map<int, Map<String, dynamic>>;
        _deliveryCosts = results[1] as Map<String, double>;
        _orderOptions = results[2] as List<String>;
        _nameController.text = prefs.getString(_kName) ?? '';
        _phoneController.text = prefs.getString(_kPhone) ?? '';
        _addressController.text = prefs.getString(_kAddress) ?? '';
        _governorate = kIraqGovernorates.contains(savedGov) ? savedGov : null;
        _loading = false;
        if (pendingCoupon.isNotEmpty) _couponController.text = pendingCoupon;
      });
      // كوبون الترحيب المحفوظ ينطبق تلقائياً
      if (pendingCoupon.isNotEmpty) _applyCoupon();
      _loadReward(autoUse: pendingCoupon.isEmpty);
      PointsService.instance.refresh();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = ShopApi.friendlyError(e);
      });
    }
  }

  Future<void> _loadReward({required bool autoUse}) async {
    if (supabase.auth.currentUser == null) return;
    try {
      final rows = await supabase
          .from('reward_coupons')
          .select('id, percent, max_discount, expires_at')
          .isFilter('used_order_id', null)
          .gt('expires_at', DateTime.now().toUtc().toIso8601String())
          .order('expires_at')
          .limit(1);
      if (!mounted || rows.isEmpty) return;
      setState(() {
        _reward = rows.first;
        _useReward = autoUse && _appliedCoupon == null;
      });
    } catch (_) {}
  }

  double get _rewardDiscount {
    final r = _reward;
    if (r == null) return 0;
    final pct = (r['percent'] as num?)?.toDouble() ?? 10;
    final max = (r['max_discount'] as num?)?.toDouble() ?? 5000;
    final v = (_subtotal * pct / 100).roundToDouble();
    return [v, max, _subtotal].reduce((a, b) => a < b ? a : b);
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

  /// نفس حساب place_order: عروض الكمية على مجموع كل منتج، والتوصيل صفر إذا أي منتج وصل درجة توصيل مجاني.
  /// للعرض فقط؛ السيرفر هو المرجع.
  CartQuote get _quote => quoteCart(_cart.lines.value, _products);

  double get _subtotal => _quote.subtotal;

  bool get _freeDelivery => _quote.freeDelivery;

  double get _delivery => _freeDelivery ? 0 : ShopApi.deliveryFor(_governorate, _deliveryCosts);

  double get _couponDiscount => _useReward
      ? _rewardDiscount
      : (_couponAmount > _subtotal ? _subtotal : _couponAmount);

  /// كم نقطة تنصرف بهذا الطلب (نفس حساب السيرفر)
  int get _usablePoints {
    final s = PointsService.instance.state.value;
    if (s == null || s.balance <= 0) return 0;
    final byCap = (_subtotal * 0.20 / PointsState.iqdPerPoint).floor();
    final byLeft = ((_subtotal - _couponDiscount).clamp(0, double.infinity) / PointsState.iqdPerPoint).floor();
    return [s.balance, byCap, byLeft].reduce((a, b) => a < b ? a : b);
  }

  int get _pointsUsed => _usePoints ? _usablePoints : 0;

  double get _discount => _couponDiscount + _pointsUsed * PointsState.iqdPerPoint;

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
        couponCode: _useReward ? null : _appliedCoupon,
        rewardCouponId: _useReward ? (_reward?['id'] as num?)?.toInt() : null,
        points: _pointsUsed,
        referralCode: _referralOk ? _referralCode : null,
        options: [for (final o in _orderOptions) if (_selectedOptions.contains(o)) o],
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
      // نربط الطلب بهذا الجهاز حتى توصل إشعارات حالته حتى بدون حساب
      unawaited(PushService.afterOrder(orderId: result.orderId, phone: phone));
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
            if (_orderOptions.isNotEmpty) ...[
              const _SectionTitle('خيارات الطلب (اختياري)'),
              _buildOrderOptions(),
              const SizedBox(height: 24),
            ],
            const _SectionTitle('كود الخصم'),
            _buildCoupon(),
            _buildPoints(),
            _buildReferral(),
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
    final quote = _quote;
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
                  if (line.color != null) '${optionTitle(optionsOf(_products[line.productId]))}: ${line.color}',
                ].join('   '),
              ),
              trailing: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (quote.lineRegularTotal(line) - quote.lineTotal(line) >= 1)
                    Text(
                      '${_money.format(quote.lineRegularTotal(line))} د.ع',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 11,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  Text(
                    '${_money.format(quote.lineTotal(line))} د.ع',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOrderOptions() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          for (final option in _orderOptions)
            CheckboxListTile(
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: Colors.deepOrange,
              value: _selectedOptions.contains(option),
              title: Text(option),
              onChanged: (v) => setState(() {
                if (v == true) {
                  _selectedOptions.add(option);
                } else {
                  _selectedOptions.remove(option);
                }
              }),
            ),
        ],
      ),
    );
  }

  Widget _buildPoints() {
    return ValueListenableBuilder<PointsState?>(
      valueListenable: PointsService.instance.state,
      builder: (context, s, _) {
        final usable = _usablePoints;
        if (s == null || s.balance <= 0) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF4D9),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFF5DFA8)),
          ),
          child: Row(
            children: [
              const Text('🪙', style: TextStyle(fontSize: 26)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('استخدمي نقاطج', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF8A5A00))),
                    Text(
                      usable > 0
                          ? 'عندج ${_money.format(s.balance)} نقطة · ينصرف منها $usable = خصم ${_money.format(usable * PointsState.iqdPerPoint)} د.ع'
                          : 'عندج ${_money.format(s.balance)} نقطة · زيدي طلبج حتى تكدرين تستخدمينها',
                      style: const TextStyle(fontSize: 12.5, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              Switch(value: _usePoints && usable > 0, onChanged: usable > 0 ? (v) => setState(() => _usePoints = v) : null),
            ],
          ),
        );
      },
    );
  }

  Future<void> _checkReferral() async {
    FocusScope.of(context).unfocus();
    final code = _referralController.text.trim();
    if (code.isEmpty) return;
    setState(() => _checkingReferral = true);
    try {
      final r = await ShopApi.checkReferral(code, phone: ShopApi.normalizePhone(_phoneController.text));
      if (!mounted) return;
      setState(() {
        _referralOk = r.valid;
        _referralCode = r.valid ? code.toUpperCase() : null;
        _referralMsg = r.message;
      });
    } catch (e) {
      if (mounted) setState(() => _referralMsg = ShopApi.friendlyError(e));
    } finally {
      if (mounted) setState(() => _checkingReferral = false);
    }
  }

  Widget _buildReferral() {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: const Text('عندج كود دعوة من صديقة؟ 👭', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _referralController,
                  textCapitalization: TextCapitalization.characters,
                  enabled: !_referralOk,
                  decoration: InputDecoration(
                    hintText: 'مثلاً M6719D',
                    border: const OutlineInputBorder(),
                    helperText: _referralOk ? _referralMsg : null,
                    helperStyle: TextStyle(color: Colors.green.shade700),
                    errorText: !_referralOk ? _referralMsg : null,
                  ),
                  onChanged: (_) {
                    if (_referralMsg != null) setState(() => _referralMsg = null);
                  },
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 56,
                child: _referralOk
                    ? TextButton(
                        onPressed: () => setState(() {
                          _referralOk = false;
                          _referralCode = null;
                          _referralMsg = null;
                          _referralController.clear();
                        }),
                        child: const Text('إزالة'),
                      )
                    : ElevatedButton(
                        onPressed: _checkingReferral ? null : _checkReferral,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.black87, foregroundColor: Colors.white),
                        child: const Text('تحقق'),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCoupon() {
    final reward = _reward;
    if (reward != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RewardCouponCard(
            coupon: reward,
            trailing: Switch(
              value: _useReward,
              onChanged: (v) => setState(() {
                _useReward = v;
                if (v) _removeCoupon();
              }),
            ),
          ),
          if (_useReward)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('خصم ${_money.format(_rewardDiscount)} د.ع على هذا الطلب · ما ينجمع ويا كود ثاني',
                  style: TextStyle(color: Colors.green.shade800, fontSize: 12.5, fontWeight: FontWeight.w600)),
            )
          else ...[
            const SizedBox(height: 10),
            _buildCodeCoupon(),
          ],
        ],
      );
    }
    return _buildCodeCoupon();
  }

  Widget _buildCodeCoupon() {
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
            if (_freeDelivery)
              row('التوصيل', 'مجاني', color: Colors.green.shade700)
            else
              row(
                'التوصيل',
                _governorate == null ? 'حسب المحافظة' : '${_money.format(_delivery)} د.ع',
              ),
            if (_couponDiscount > 0)
              row('الخصم', '-${_money.format(_couponDiscount)} د.ع', color: Colors.green.shade700),
            if (_pointsUsed > 0)
              row('خصم النقاط ($_pointsUsed نقطة)', '-${_money.format(_pointsUsed * PointsState.iqdPerPoint)} د.ع', color: Colors.green.shade700),
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
