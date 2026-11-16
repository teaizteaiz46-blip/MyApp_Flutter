import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;

import '../../services/influencer_service.dart';
import '../../theme/app_theme.dart';
import 'influencer_apply_screen.dart';
import 'influencer_wallet_screen.dart';

/// سطر برنامج المؤثرين بصفحة الحساب:
/// مؤثر → "أرباحي"، طلب قيد المراجعة → حالة، مرفوض → ما انقبل، وغيرها → "انضموا كمؤثرين".
class InfluencerEntry extends StatefulWidget {
  const InfluencerEntry({super.key});

  @override
  State<InfluencerEntry> createState() => _InfluencerEntryState();
}

class _InfluencerEntryState extends State<InfluencerEntry> {
  static final NumberFormat _money = NumberFormat('#,###');
  late Future<InfluencerStatus?> _future = InfluencerService.status();

  void _reload() => setState(() => _future = InfluencerService.status());

  Future<void> _open(Widget screen) async {
    final sent = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => screen));
    if (!mounted) return;
    if (sent == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('انرسل طلبكم ✅ راح نراجعه ونرد عليكم')),
      );
    }
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<InfluencerStatus?>(
      future: _future,
      builder: (context, snap) {
        final s = snap.data;
        if (snap.connectionState == ConnectionState.waiting || s == null) return const SizedBox.shrink();
        if (s.isInfluencer) {
          final balance = (s.wallet?['balance'] as num?)?.toInt() ?? 0;
          return _tile(
            context,
            icon: '💼',
            title: 'أرباحي',
            subtitle: 'الرصيد المتوفر: ${_money.format(balance)} د.ع',
            onTap: () => _open(const InfluencerWalletScreen()),
          );
        }
        return switch (s.applicationStatus) {
          'pending' => _tile(context, icon: '⏳', title: 'طلب الانضمام كمؤثر', subtitle: 'طلبكم قيد المراجعة'),
          'rejected' => _tile(
              context,
              icon: '🙏',
              title: 'طلب الانضمام كمؤثر',
              subtitle: s.canReapply ? 'طلبكم السابق ما انقبل. تگدرون تقدمون مرة ثانية' : 'نعتذر، طلبكم ما انقبل هالمرة',
              onTap: s.canReapply ? () => _open(const InfluencerApplyScreen()) : null,
            ),
          _ => _tile(
              context,
              icon: '⭐',
              title: 'انضموا كمؤثرين',
              subtitle: 'شاركوا كودكم واربحوا عمولة على كل زبونة جديدة',
              onTap: () => _open(const InfluencerApplyScreen()),
            ),
        };
      },
    );
  }

  Widget _tile(BuildContext context, {required String icon, required String title, required String subtitle, VoidCallback? onTap}) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Material(
        color: context.modo.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: context.modo.line)),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          onTap: onTap,
          leading: Text(icon, style: const TextStyle(fontSize: 24)),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(subtitle, style: TextStyle(color: cs.onSurfaceVariant)),
          trailing: onTap == null ? null : const Icon(Icons.chevron_left_rounded, color: AppColors.brand),
        ),
      ),
    );
  }
}
