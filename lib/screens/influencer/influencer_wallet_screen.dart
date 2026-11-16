import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;
import 'package:share_plus/share_plus.dart';

import '../../core/shop_api.dart';
import '../../services/influencer_service.dart';
import '../../theme/app_theme.dart';

/// "أرباحي": كود المؤثر، الرصيد، وآخر الطلبات بالكود (بدون اسم أو رقم أو عنوان أي زبونة).
class InfluencerWalletScreen extends StatefulWidget {
  const InfluencerWalletScreen({super.key});

  @override
  State<InfluencerWalletScreen> createState() => _InfluencerWalletScreenState();
}

class _InfluencerWalletScreenState extends State<InfluencerWalletScreen> {
  late Future<InfluencerStatus?> _future = InfluencerService.status();

  Future<void> _reload() async {
    setState(() => _future = InfluencerService.status());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('أرباحي')),
      body: FutureBuilder<InfluencerStatus?>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _message(ShopApi.friendlyError(snap.error!), retry: true);
          }
          final w = snap.data?.wallet;
          if (w == null) return _message('حسابكم مو مربوط كمؤثر.');
          return RefreshIndicator(onRefresh: _reload, child: InfluencerWalletBody(wallet: w));
        },
      ),
    );
  }

  Widget _message(String text, {bool retry = false}) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(text, textAlign: TextAlign.center),
            if (retry) TextButton(onPressed: _reload, child: const Text('إعادة المحاولة')),
          ]),
        ),
      );
}

/// محتوى "أرباحي" (منفصل حتى ينجرب بالاختبار بدون سيرفر)
class InfluencerWalletBody extends StatelessWidget {
  const InfluencerWalletBody({super.key, required this.wallet});

  final Map<String, dynamic> wallet;

  static final NumberFormat _money = NumberFormat('#,###');
  static final DateFormat _date = DateFormat('d/M/yyyy');
  static const Color _green = Color(0xFF1B7F3B);

  static int _int(dynamic v) => (v as num?)?.toInt() ?? 0;
  static String _iqd(dynamic v) => '${_money.format(_int(v))} د.ع';

  static String _fmtDate(dynamic v) {
    final d = DateTime.tryParse('${v ?? ''}')?.toLocal();
    return d == null ? '' : _date.format(d);
  }

  void _copy(BuildContext context, String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('انخسخ الكود ✅'), duration: Duration(seconds: 2)));
  }

  Future<void> _share(String code, int discount) async {
    final link = InfluencerService.shareLink(code);
    await SharePlus.instance.share(ShareParams(
      text: 'استعملوا كودي $code وخذوا خصم ${_money.format(discount)} د.ع على أول طلب من MODO 🛍️\n$link',
    ));
  }

  @override
  Widget build(BuildContext context) {
    final w = wallet;
    final cs = Theme.of(context).colorScheme;
    final code = (w['code'] ?? '').toString();
    final active = w['active'] == true;
    final recent = ((w['recent'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final payouts = ((w['payouts'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

    Widget card({required Widget child, EdgeInsets padding = const EdgeInsets.all(14)}) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: padding,
          decoration: BoxDecoration(
            color: context.modo.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.modo.line),
          ),
          child: child,
        );

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        if (!active)
          card(
            child: const Text('⏸️ الكود موقوف حالياً. رصيدكم محفوظ، وللاستفسار راسلونا.',
                style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.sale)),
          ),
        // الكود
        card(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('كودكم', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
            const SizedBox(height: 4),
            SelectableText(code,
                textAlign: TextAlign.center,
                textDirection: TextDirection.ltr,
                style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 2, color: AppColors.brand)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _copy(context, code),
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('نسخ'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _share(code, _int(w['discount'])),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.brand),
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text('مشاركة'),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            Text(
              'الزبونة تاخذ خصم ${_iqd(w['discount'])} على أول طلب، وإنتو تاخذون ${_iqd(w['commission'])} على كل طلب أول يكتمل.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, height: 1.6, color: cs.onSurfaceVariant),
            ),
          ]),
        ),
        // الرصيد
        card(
          child: Column(children: [
            Text('الرصيد المتوفر', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text(_iqd(w['balance']), style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: _green)),
            const SizedBox(height: 10),
            Row(children: [
              _stat(context, 'مجموع العمولات', _iqd(w['earned'])),
              _stat(context, 'المستلم', _iqd(w['paid'])),
              _stat(context, 'طلبات محسوبة', '${_int(w['counted'])}'),
            ]),
          ]),
        ),
        _title('آخر الطلبات بكودكم'),
        if (recent.isEmpty)
          card(child: Text('ماكو طلبات بكودكم لحد هسه.', style: TextStyle(color: cs.onSurfaceVariant)))
        else
          card(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Column(children: [
              for (var i = 0; i < recent.length; i++) ...[
                if (i > 0) Divider(height: 1, color: context.modo.line),
                _orderRow(context, recent[i]),
              ],
            ]),
          ),
        _title('المبالغ المستلمة'),
        if (payouts.isEmpty)
          card(child: Text('ما استلمتوا مبالغ لحد هسه.', style: TextStyle(color: cs.onSurfaceVariant)))
        else
          card(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Column(children: [
              for (var i = 0; i < payouts.length; i++) ...[
                if (i > 0) Divider(height: 1, color: context.modo.line),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(children: [
                    Expanded(child: Text(_fmtDate(payouts[i]['at']), style: TextStyle(color: cs.onSurfaceVariant))),
                    Text(_iqd(payouts[i]['amount']), style: const TextStyle(fontWeight: FontWeight.w800, color: _green)),
                  ]),
                ),
              ],
            ]),
          ),
      ],
    );
  }

  Widget _title(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
        child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
      );

  Widget _stat(BuildContext context, String label, String value) => Expanded(
        child: Column(children: [
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11.5, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ]),
      );

  /// حالة الطلب: قيد التوصيل / محسوب (ويه المبلغ) / ملغي / غير محسوب (مو أول طلب للزبونة)
  Widget _orderRow(BuildContext context, Map<String, dynamic> o) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final (label, color) = switch (o['state']) {
      'counted' => ('محسوب +${_iqd(o['amount'])}', _green),
      'cancelled' => ('ملغي', AppColors.sale),
      'not_counted' => ('غير محسوب (مو أول طلب للزبونة)', muted),
      _ => ('قيد التوصيل', AppColors.brand),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Expanded(child: Text(_fmtDate(o['at']), style: TextStyle(color: muted))),
        Flexible(
          child: Text(label, textAlign: TextAlign.end, style: TextStyle(fontWeight: FontWeight.w800, color: color, fontSize: 13)),
        ),
      ]),
    );
  }
}
