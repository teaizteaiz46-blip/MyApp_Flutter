import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/shop_api.dart';
import '../main.dart';
import '../theme/app_theme.dart';

/// تأكيد الطلب من التطبيق بدل الاتصال:
/// - بعد الطلب مباشرة تطلع نافذة "أكّدوا طلبكم" ويه التفاصيل (العنوان والهاتف والمبلغ).
/// - "تأكيد الطلب" يخليه "طلب مثبت"، و"أريد أعدّل أو ألغي" يبلغ كروب التيليكرام يتصلون بيه
///   (public.customer_respond_order).
/// - إذا ما رد: السيرفر يرسل إشعار تذكير بعد 20 دقيقة، والنافذة ترجع تطلع لما يفتح التطبيق (مرة كل 6 ساعات).
/// الزائر يتعرف على طلبه برقم الطلب + رقم الهاتف المحفوظين بالجهاز، وصاحب الحساب بحسابه.
class OrderConfirmService {
  OrderConfirmService._();

  static const String _refsKey = 'order_confirm_refs_v1';
  static const Duration _maxAge = Duration(days: 3);
  static const Duration _reaskAfter = Duration(hours: 6);

  static GlobalKey<NavigatorState>? _navigatorKey;
  static GlobalKey<ScaffoldMessengerState>? _messengerKey;
  static AppLifecycleListener? _lifecycle;
  static bool _showing = false;

  static void init({
    required GlobalKey<NavigatorState> navigatorKey,
    required GlobalKey<ScaffoldMessengerState> messengerKey,
  }) {
    _navigatorKey = navigatorKey;
    _messengerKey = messengerKey;
    _lifecycle ??= AppLifecycleListener(onResume: () => unawaited(checkPending()));
    // بعد ما تخلص نوافذ البداية (التتبع والإشعارات وإعلان الافتتاح)
    unawaited(Future<void>.delayed(const Duration(seconds: 5), checkPending));
  }

  /// بعد نجاح الطلب: نحفظه بالجهاز، ونطلع نافذة التأكيد بعد ما تبين رسالة "تم إرسال طلبك"
  static Future<void> afterOrder({required int orderId, required String phone}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refs = _loadRefs(prefs)..removeWhere((r) => r['id'] == orderId);
      refs.insert(0, {'id': orderId, 'phone': phone, 'at': DateTime.now().toIso8601String()});
      await _saveRefs(prefs, refs);
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      await open(orderId);
    } catch (e) {
      debugPrint('Order confirm after order failed: $e');
    }
  }

  /// فتح التطبيق أو الرجوع له: إذا اكو طلب بعده ينتظر التأكيد نطلع نافذته
  static Future<void> checkPending() async {
    if (_showing) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final r in _loadRefs(prefs)) {
        if (r['done'] == true) continue;
        if (now - ((r['asked'] as num?)?.toInt() ?? 0) < _reaskAfter.inMilliseconds) continue;
        // ما نطلع فوق صفحة ثانية أو نافذة مفتوحة
        final nav = _navigatorKey?.currentState;
        if (nav == null || nav.canPop()) return;
        await open((r['id'] as num).toInt());
        return;
      }
    } catch (e) {
      debugPrint('Order confirm check failed: $e');
    }
  }

  /// نافذة التأكيد لطلب معيّن. [explicit]: الزبون طلبها (إشعار أو "طلباتي")، فنبلغه حتى إذا الطلب ما يحتاج تأكيد.
  static Future<bool> open(int orderId, {bool explicit = false}) async {
    if (_showing) return false;
    _showing = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final phone = _loadRefs(prefs).where((r) => r['id'] == orderId).map((r) => r['phone'] as String?).firstOrNull;

      final res = await supabase.rpc('order_confirm_info', params: {'p_order_id': orderId, 'p_phone': phone});
      if (res is! Map) {
        if (explicit) _snack('ما لگينا الطلب ${_num(orderId)}، تواصلوا ويانا إذا تحتاجون مساعدة');
        return false;
      }
      final info = Map<String, dynamic>.from(res);
      if (info['pending'] != true) {
        await _mark(orderId, done: true);
        if (explicit) _snack(_doneMessage(info));
        return false;
      }
      await _mark(orderId, asked: true);

      final context = await _context();
      if (context == null || !context.mounted) return false;
      final action = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) => OrderConfirmSheet(info: info),
      );
      if (action == null) return false;

      final out = Map<String, dynamic>.from(await supabase.rpc('customer_respond_order', params: {
        'p_order_id': orderId,
        'p_phone': phone,
        'p_action': action,
      }) as Map);
      await _mark(orderId, done: true);
      if (out['already'] == true) {
        _snack(_doneMessage(out..['id'] = orderId));
      } else if (action == 'confirm') {
        _snack('تم تأكيد طلبكم ${_num(orderId)} ✓ بدينا بالتجهيز', color: AppColors.success);
      } else {
        _snack('وصلنا طلبكم، راح نتصل بيكم قريباً حتى نعدّل الطلب');
      }
      return true;
    } catch (e) {
      debugPrint('Order confirm failed: $e');
      if (explicit) _snack(ShopApi.friendlyError(e), color: AppColors.sale);
      return false;
    } finally {
      _showing = false;
    }
  }

  static String _doneMessage(Map<String, dynamic> info) {
    final id = _num(info['id']);
    if (info['confirmed'] == true) return 'طلبكم $id متأكد ✓';
    if (info['change_requested'] == true) return 'وصلنا طلب التعديل، راح نتصل بيكم قريباً';
    return 'طلبكم $id حالته: ${info['status'] ?? ''}';
  }

  /// "#412" وسط نص عربي ينقلب لـ "412#"، فنثبّت اتجاهه
  static String _num(Object? id) => '\u2066#$id\u2069';

  /// الإشعار ممكن يفتح التطبيق قبل ما تجهز الصفحات: ننتظر كم إطار
  static Future<BuildContext?> _context() async {
    for (var i = 0; i < 20; i++) {
      final context = _navigatorKey?.currentContext;
      if (context != null) return context;
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
    return null;
  }

  static void _snack(String text, {Color? color}) {
    _messengerKey?.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), backgroundColor: color, duration: const Duration(seconds: 5)));
  }

  static List<Map<String, dynamic>> _loadRefs(SharedPreferences prefs) {
    try {
      final now = DateTime.now();
      return (jsonDecode(prefs.getString(_refsKey) ?? '[]') as List)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .where((r) {
        final at = DateTime.tryParse('${r['at']}');
        return at != null && now.difference(at) < _maxAge;
      }).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _saveRefs(SharedPreferences prefs, List<Map<String, dynamic>> refs) =>
      prefs.setString(_refsKey, jsonEncode(refs.take(5).toList()));

  static Future<void> _mark(int orderId, {bool asked = false, bool done = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final refs = _loadRefs(prefs);
    for (final r in refs) {
      if (r['id'] != orderId) continue;
      if (asked) r['asked'] = DateTime.now().millisecondsSinceEpoch;
      if (done) r['done'] = true;
    }
    await _saveRefs(prefs, refs);
  }
}

/// تفاصيل الطلب وأزرار الرد. ترجع 'confirm' أو 'change'، أو null لـ "لاحقاً".
class OrderConfirmSheet extends StatelessWidget {
  const OrderConfirmSheet({super.key, required this.info});

  final Map<String, dynamic> info;

  static final NumberFormat _money = NumberFormat('#,###');

  @override
  Widget build(BuildContext context) {
    final items = ((info['items'] as List?) ?? const []).cast<Map>();
    final pieces = (info['pieces'] as num?)?.toInt() ?? 0;
    final total = (info['total'] as num?)?.toDouble() ?? 0;
    final address = [info['governorate'], info['address']]
        .map((s) => (s ?? '').toString().trim())
        .where((s) => s.isNotEmpty)
        .join('، ');

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('📝', textAlign: TextAlign.center, style: TextStyle(fontSize: 40)),
            const SizedBox(height: 6),
            Text(
              'أكّدوا طلبكم ${OrderConfirmService._num(info['id'])}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.ink),
            ),
            const SizedBox(height: 4),
            const Text(
              'راجعوا التفاصيل واضغطوا تأكيد، ونبدي بالتجهيز فوراً بدون ما تنتظرون اتصال.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: AppColors.muted, height: 1.5),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final item in items.take(3))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '• ${item['name'] ?? ''}${item['color'] == null ? '' : ' · ${item['color']}'} × ${item['qty'] ?? 1}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13.5, color: AppColors.ink),
                      ),
                    ),
                  if (items.length > 3)
                    Text(
                      items.length == 4 ? 'ومنتج ثاني' : 'و ${items.length - 3} منتجات ثانية',
                      style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
                    ),
                  const Divider(height: 20, color: AppColors.line),
                  if (address.isNotEmpty) _row('العنوان', address),
                  _row('الهاتف', '${info['phone'] ?? ''}', ltr: true),
                  _row('عدد القطع', '$pieces'),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Expanded(
                        child: Text('المبلغ عند الاستلام', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink)),
                      ),
                      Text(
                        '${_money.format(total)} د.ع',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: AppColors.brandDark),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, 'confirm'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('تأكيد الطلب ✓', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, 'change'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.ink,
                  side: const BorderSide(color: AppColors.line),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('أريد أعدّل أو ألغي', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('لاحقاً', style: TextStyle(color: AppColors.muted)),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _row(String label, String value, {bool ltr = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 78, child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.muted))),
            Expanded(
              child: Text(
                value,
                textDirection: ltr ? TextDirection.ltr : null,
                textAlign: ltr ? TextAlign.end : TextAlign.start,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.ink),
              ),
            ),
          ],
        ),
      );
}
