import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;

import '../../core/offline_cache.dart';
import '../../core/product_options.dart';
import '../../core/shop_api.dart';
import '../../main.dart';
import '../../theme/app_theme.dart';

final NumberFormat _money = NumberFormat('#,###');

/// مراحل الطلب بالترتيب (نفس حالات صفحة الإدارة والتليكرام)
const List<String> kOrderFlow = ['قيد المراجعة', 'طلب مثبت', 'مجهز', 'مكتمل'];
const List<String> _stepLabels = ['استلمنا', 'تثبيت', 'تجهيز', 'توصيل'];

int orderStep(String? status) {
  final i = kOrderFlow.indexOf((status ?? '').trim());
  return i < 0 ? 0 : i; // 'new' والحالات القديمة = أول مرحلة
}

/// طلباتي: تبويب للطلبات الحالية وتبويب للسابقة، ويه زر "استلمت طلبي" وكوبون المكافأة.
class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  List<Map<String, dynamic>>? _orders;
  List<Map<String, dynamic>> _coupons = const [];
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) {
      setState(() => _orders = const []);
      return;
    }
    try {
      final rows = await supabase
          .from('orders')
          .select('id, created_at, status, price, delivery_cost, discount_amount, total_amount, governorate, '
              'received_at, received_rating, order_items(product_id, product_name, product_image, color, quantity, unit_price)')
          .eq('user_id', uid)
          .order('created_at', ascending: false)
          .limit(50);
      List<Map<String, dynamic>> coupons = const [];
      try {
        coupons = (await supabase
                .from('reward_coupons')
                .select('id, percent, max_discount, expires_at, source_order_id')
                .isFilter('used_order_id', null)
                .gt('expires_at', DateTime.now().toUtc().toIso8601String())
                .order('expires_at'))
            .cast<Map<String, dynamic>>();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _orders = rows.cast<Map<String, dynamic>>();
        _coupons = coupons;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _confirmReceived(Map<String, dynamic> order) async {
    final rating = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (_) => const _RatingSheet(),
    );
    if (rating == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final res = Map<String, dynamic>.from(await supabase.rpc('confirm_order_received', params: {
        'p_order_id': order['id'],
        'p_rating': rating,
      }) as Map);
      await _load();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => _ThanksDialog(couponIssued: res['coupon_issued'] == true),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(ShopApi.friendlyError(e)), backgroundColor: AppColors.sale));
    }
  }

  @override
  Widget build(BuildContext context) {
    final orders = _orders;
    final current = orders?.where((o) => (o['status'] ?? '') != 'مكتمل').toList() ?? const [];
    final past = orders?.where((o) => (o['status'] ?? '') == 'مكتمل').toList() ?? const [];

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('طلباتي'),
          backgroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(56),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Container(
                decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(14)),
                child: TabBar(
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(12)),
                  labelColor: Colors.white,
                  unselectedLabelColor: AppColors.muted,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  tabs: [
                    Tab(height: 40, text: orders == null ? 'الحالية' : 'الحالية (${current.length})'),
                    Tab(height: 40, text: orders == null ? 'السابقة' : 'السابقة (${past.length})'),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: _error != null
            ? _Message(icon: Icons.wifi_off_rounded, text: 'تعذر تحميل الطلبات، اسحبي للتحديث', onRetry: _load)
            : orders == null
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    children: [
                      _OrdersList(
                        orders: current,
                        coupons: _coupons,
                        onRefresh: _load,
                        empty: 'ماكو طلبات حالية',
                        builder: (o) => _CurrentOrder(order: o, onReceived: () => _confirmReceived(o)),
                      ),
                      _OrdersList(
                        orders: past,
                        coupons: _coupons,
                        onRefresh: _load,
                        empty: 'ماكو طلبات سابقة',
                        builder: (o) => _PastOrder(order: o, onReceived: () => _confirmReceived(o)),
                      ),
                    ],
                  ),
      ),
    );
  }
}

class _OrdersList extends StatelessWidget {
  const _OrdersList({
    required this.orders,
    required this.coupons,
    required this.onRefresh,
    required this.empty,
    required this.builder,
  });

  final List<Map<String, dynamic>> orders;
  final List<Map<String, dynamic>> coupons;
  final Future<void> Function() onRefresh;
  final String empty;
  final Widget Function(Map<String, dynamic>) builder;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          for (final c in coupons) Padding(padding: const EdgeInsets.only(bottom: 12), child: RewardCouponCard(coupon: c)),
          if (orders.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 80),
              child: _Message(icon: Icons.receipt_long_outlined, text: empty),
            ),
          for (final o in orders) Padding(padding: const EdgeInsets.only(bottom: 16), child: builder(o)),
        ],
      ),
    );
  }
}

/// بطاقة كوبون المكافأة (تنستخدم هنا وبصفحة إتمام الطلب)
class RewardCouponCard extends StatelessWidget {
  const RewardCouponCard({super.key, required this.coupon, this.trailing});

  final Map<String, dynamic> coupon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final pct = (coupon['percent'] as num?)?.toInt() ?? 10;
    final max = (coupon['max_discount'] as num?)?.toDouble() ?? 5000;
    final exp = DateTime.tryParse('${coupon['expires_at'] ?? ''}')?.toLocal();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5EC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFB5DEC1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.card_giftcard_rounded, color: Color(0xFF1E7B3A), size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('عندج خصم $pct% لطلبج الجاي 🎁',
                    style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1E7B3A), fontSize: 14.5)),
                Text(
                  'لحد ${_money.format(max)} د.ع${exp == null ? '' : ' · صالح لحد ${DateFormat('d/M').format(exp)}'}',
                  style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

String _statusMessage(String? status) => switch (status) {
      'طلب مثبت' => 'ثبتنا طلبج وراح نبدي نجهزه',
      'مجهز' => 'طلبج جاهز وبالطريق إليج 🚚',
      'مكتمل' => 'وصل طلبج، نتمنى عجبج 🤍',
      _ => 'راح نتصل بيج لتثبيت الطلب خلال ساعات',
    };

String _statusTitle(String? status) => switch (status) {
      'طلب مثبت' => 'تم تثبيت طلبج ✓',
      'مجهز' => 'طلبج بالطريق',
      'مكتمل' => 'وصل طلبج',
      _ => 'طلبج وصلنا 🤍',
    };

String _date(Map<String, dynamic> o) {
  final d = DateTime.tryParse('${o['created_at'] ?? ''}')?.toLocal();
  return d == null ? '' : DateFormat('d/M · h:mm a', 'en').format(d).replaceAll('AM', 'ص').replaceAll('PM', 'م');
}

List<Map<String, dynamic>> _items(Map<String, dynamic> o) => ((o['order_items'] as List?) ?? const []).cast<Map<String, dynamic>>();

int _pieces(Map<String, dynamic> o) => _items(o).fold(0, (s, i) => s + ((i['quantity'] as num?)?.toInt() ?? 0));

bool _canConfirm(Map<String, dynamic> o) =>
    o['received_at'] == null && ((o['status'] ?? '') == 'مجهز' || (o['status'] ?? '') == 'مكتمل');

class _CurrentOrder extends StatelessWidget {
  const _CurrentOrder({required this.order, required this.onReceived});

  final Map<String, dynamic> order;
  final VoidCallback onReceived;

  @override
  Widget build(BuildContext context) {
    final step = orderStep(order['status']?.toString());
    final items = _items(order);
    final price = (order['price'] as num?)?.toDouble() ?? 0;
    final delivery = (order['delivery_cost'] as num?)?.toDouble() ?? 0;
    final discount = (order['discount_amount'] as num?)?.toDouble() ?? 0;
    final total = (order['total_amount'] as num?)?.toDouble() ?? (price + delivery - discount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(colors: [Color(0xFFFF8A55), AppColors.brandDark]),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('طلب #${order['id']} · ${_date(order)}',
                        style: const TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w600)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(99)),
                    child: Text(kOrderFlow[step], style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(_statusTitle(order['status']?.toString()),
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
              Text(_statusMessage(order['status']?.toString()), style: const TextStyle(color: Colors.white, fontSize: 13)),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: (step + 1) / kOrderFlow.length,
                  minHeight: 6,
                  backgroundColor: Colors.white30,
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var i = 0; i < _stepLabels.length; i++)
                    Text(_stepLabels[i],
                        style: TextStyle(
                          color: i <= step ? Colors.white : Colors.white60,
                          fontSize: 11.5,
                          fontWeight: i == step ? FontWeight.w800 : FontWeight.w500,
                        )),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _Card(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) _ItemLine(item: items[i], last: i == items.length - 1),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _Card(
          child: Column(
            children: [
              _kv('المجموع', '${_money.format(price)} د.ع'),
              _kv('التوصيل · ${order['governorate'] ?? ''}', delivery == 0 ? 'مجاني' : '${_money.format(delivery)} د.ع'),
              if (discount > 0) _kv('الخصم', '-${_money.format(discount)} د.ع', color: AppColors.success),
              const Divider(height: 18),
              Row(
                children: [
                  const Expanded(child: Text('الإجمالي (عند الاستلام)', style: TextStyle(fontWeight: FontWeight.w800))),
                  Text('${_money.format(total)} د.ع',
                      style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.brandDark, fontSize: 17)),
                ],
              ),
            ],
          ),
        ),
        if (_canConfirm(order)) ...[
          const SizedBox(height: 10),
          _ReceivedButton(onPressed: onReceived),
        ],
      ],
    );
  }

  static Widget _kv(String k, String v, {Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(child: Text(k, style: const TextStyle(color: AppColors.muted, fontSize: 13.5))),
            Text(v, style: TextStyle(color: color ?? AppColors.ink, fontWeight: FontWeight.w600, fontSize: 13.5)),
          ],
        ),
      );
}

class _PastOrder extends StatelessWidget {
  const _PastOrder({required this.order, required this.onReceived});

  final Map<String, dynamic> order;
  final VoidCallback onReceived;

  @override
  Widget build(BuildContext context) {
    final items = _items(order);
    final images = items.map((i) => '${i['product_image'] ?? ''}').where((u) => u.isNotEmpty).toList();
    final total = (order['total_amount'] as num?)?.toDouble() ?? 0;
    final received = order['received_at'] != null;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('طلب #${order['id']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    Text(_date(order), style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFFE5F5EA), borderRadius: BorderRadius.circular(99)),
                child: Text(received ? 'استلمتيه ✓' : 'تم التوصيل ✓',
                    style: const TextStyle(color: Color(0xFF1E7B3A), fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          if (images.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 58,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: images.length > 5 ? 5 : images.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 58,
                    height: 58,
                    child: i == 4 && images.length > 5
                        ? ColoredBox(
                            color: AppColors.background,
                            child: Center(child: Text('+${images.length - 4}', style: const TextStyle(fontWeight: FontWeight.w800))),
                          )
                        : Image(
                            image: cachedImage(images[i], decodeWidth: decodeWidthFor(context, 58, 58)),
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const ColoredBox(color: AppColors.placeholder),
                          ),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: Text('${pieces(_pieces(order))} · ${order['governorate'] ?? ''}', style: const TextStyle(color: AppColors.muted))),
              Text('${_money.format(total)} د.ع', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.brandDark, fontSize: 16)),
            ],
          ),
          if (_canConfirm(order)) ...[
            const SizedBox(height: 10),
            _ReceivedButton(onPressed: onReceived),
          ],
        ],
      ),
    );
  }
}

class _ReceivedButton extends StatelessWidget {
  const _ReceivedButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF1E7B3A),
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
      ),
      onPressed: onPressed,
      icon: const Icon(Icons.check_circle_outline_rounded),
      label: const Text('استلمت طلبي · خذي خصم 10% 🎁'),
    );
  }
}

class _ItemLine extends StatelessWidget {
  const _ItemLine({required this.item, required this.last});

  final Map<String, dynamic> item;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final img = '${item['product_image'] ?? ''}';
    final qty = (item['quantity'] as num?)?.toInt() ?? 1;
    final unit = (item['unit_price'] as num?)?.toDouble() ?? 0;
    final color = '${item['color'] ?? ''}'.trim();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: AppColors.line))),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 52,
              height: 52,
              child: img.isEmpty
                  ? const ColoredBox(color: AppColors.placeholder)
                  : Image(
                      image: cachedImage(img, decodeWidth: decodeWidthFor(context, 52, 52)),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const ColoredBox(color: AppColors.placeholder),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${item['product_name'] ?? ''}',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                Text([if (color.isNotEmpty) color, pieces(qty)].join(' · '),
                    style: const TextStyle(color: AppColors.muted, fontSize: 12)),
              ],
            ),
          ),
          Text(_money.format(unit * qty), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = const EdgeInsets.all(14)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: child,
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.onRetry});

  final IconData icon;
  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 46, color: AppColors.muted),
          const SizedBox(height: 10),
          Text(text, style: const TextStyle(color: AppColors.muted)),
          if (onRetry != null) TextButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
        ],
      ),
    );
  }
}

class _RatingSheet extends StatelessWidget {
  const _RatingSheet();

  @override
  Widget build(BuildContext context) {
    Widget option(int v, String emoji, String label) => Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => Navigator.of(context).pop(v),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 34)),
                  const SizedBox(height: 4),
                  Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        );
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('شلون جانت تجربتج؟', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('اختاري وحدة حتى نأكد استلامج للطلب', style: TextStyle(color: AppColors.muted)),
            const SizedBox(height: 16),
            Row(
              children: [
                option(3, '😍', 'ممتازة'),
                const SizedBox(width: 10),
                option(2, '🙂', 'زينة'),
                const SizedBox(width: 10),
                option(1, '😐', 'مقبولة'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ThanksDialog extends StatelessWidget {
  const _ThanksDialog({required this.couponIssued});

  final bool couponIssued;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: Icon(couponIssued ? Icons.card_giftcard_rounded : Icons.favorite_rounded,
          color: couponIssued ? const Color(0xFF1E7B3A) : AppColors.brand, size: 40),
      title: Text(couponIssued ? 'انضافلج خصم 10% 🎁' : 'شكراً إلج 🤍', textAlign: TextAlign.center),
      content: Text(
        couponIssued
            ? 'الكوبون محفوظ بحسابج لمدة 60 يوم، لحد 5,000 د.ع. يطلعلج تلقائياً بصفحة إتمام الطلب.'
            : 'سجلنا استلامج. أول ما نأكد وصول الطلب، ينضاف كوبون خصم 10% لحسابج.',
        textAlign: TextAlign.center,
      ),
      actions: [
        FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('تمام')),
      ],
      actionsAlignment: MainAxisAlignment.center,
    );
  }
}
