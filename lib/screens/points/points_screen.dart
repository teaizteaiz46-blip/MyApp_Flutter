import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;
import 'package:url_launcher/url_launcher.dart';

import '../../core/shop_api.dart';
import '../../services/points_service.dart';
import '../../theme/app_theme.dart';
import '../auth/profile_screen.dart';

final NumberFormat _money = NumberFormat('#,###');

const Color _gold = Color(0xFF8A5A00);
const Color _goldSoft = Color(0xFFFFF4D9);

/// نقاطي: هدية كل يوم (سلسلة 7 أيام)، طرق جمع النقاط، الرصيد، وكود الدعوة.
class PointsScreen extends StatefulWidget {
  const PointsScreen({super.key});

  @override
  State<PointsScreen> createState() => _PointsScreenState();
}

class _PointsScreenState extends State<PointsScreen> {
  final _points = PointsService.instance;
  bool _claiming = false;

  @override
  void initState() {
    super.initState();
    _points.refresh();
  }

  Future<void> _claim() async {
    if (_claiming) return;
    setState(() => _claiming = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final got = await _points.claimDaily();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          icon: const Text('🎁', style: TextStyle(fontSize: 44)),
          title: Text('+$got نقطة', textAlign: TextAlign.center),
          content: const Text('ارجعي باچر حتى تكملين السلسلة، اليوم السابع هديته أكبر 💎', textAlign: TextAlign.center),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.brand),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('حلو'),
            ),
          ],
          actionsAlignment: MainAxisAlignment.center,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(ShopApi.friendlyError(e))));
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  void _share(String code) {
    final text = 'حمّلي تطبيق MODO واستخدمي كودي $code بأول طلب 🎁\n'
        'https://teaizteaiz46-blip.github.io/Modo-orders/app.html?utm_source=referral';
    launchUrl(Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}'), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('نقاطي'),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: !_points.signedIn
          ? _GuestInvite(onLogin: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen())))
          : ValueListenableBuilder<PointsState?>(
              valueListenable: _points.state,
              builder: (context, s, _) {
                if (s == null) return const Center(child: CircularProgressIndicator());
                return RefreshIndicator(
                  onRefresh: _points.refresh,
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      DailyGiftCard(state: s, claiming: _claiming, onClaim: _claim),
                      const SizedBox(height: 12),
                      _BalanceCard(state: s),
                      const SizedBox(height: 12),
                      const _WaysCard(),
                      const SizedBox(height: 12),
                      _ReferralCard(code: s.referralCode, onShare: () => _share(s.referralCode)),
                      if (s.history.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _HistoryCard(history: s.history),
                      ],
                    ],
                  ),
                );
              },
            ),
    );
  }
}

/// بطاقة الهدية اليومية (تنستخدم بصفحة النقاط وبالرئيسية)
class DailyGiftCard extends StatelessWidget {
  const DailyGiftCard({super.key, required this.state, required this.claiming, required this.onClaim});

  final PointsState state;
  final bool claiming;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final current = state.streakDay;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(colors: [Color(0xFFFFB347), AppColors.brand, AppColors.brandDark]),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('هديتج اليومية 🎁', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
              ),
              if (current > 1 || state.claimedToday)
                Text('سلسلة ${state.claimedToday ? current : current - 1} ${(state.claimedToday ? current : current - 1) == 1 ? 'يوم' : 'أيام'} 🔥',
                    style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700)),
            ],
          ),
          const Text('افتحي التطبيق كل يوم، ولا تقطعين السلسلة!', style: TextStyle(color: Colors.white, fontSize: 13)),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var d = 1; d <= 7; d++) ...[
                if (d > 1) const SizedBox(width: 5),
                Expanded(child: _DayBox(day: d, points: state.rule[d - 1], current: current, claimedToday: state.claimedToday)),
              ],
            ],
          ),
          const SizedBox(height: 12),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.brandDark,
              disabledBackgroundColor: Colors.white70,
              disabledForegroundColor: AppColors.muted,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            onPressed: state.claimedToday || claiming ? null : onClaim,
            child: Text(state.claimedToday ? 'استلمتي هدية اليوم ✓ ارجعي باچر' : 'استلمي ${state.todayPoints} نقطة'),
          ),
        ],
      ),
    );
  }
}

class _DayBox extends StatelessWidget {
  const _DayBox({required this.day, required this.points, required this.current, required this.claimedToday});

  final int day;
  final int points;
  final int current;
  final bool claimedToday;

  @override
  Widget build(BuildContext context) {
    final done = day < current || (day == current && claimedToday);
    final today = day == current && !claimedToday;
    final bg = done ? Colors.white : (today ? AppColors.ink : Colors.white24);
    final fg = done ? AppColors.brandDark : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: today ? Border.all(color: Colors.white, width: 2) : null,
      ),
      child: Column(
        children: [
          Text(today ? 'اليوم' : 'يوم $day', style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.w700)),
          Text(done ? '✓' : (day == 7 ? '💎' : '🎁'), style: TextStyle(color: fg, fontSize: 15, fontWeight: FontWeight.w800)),
          Text('$points', style: TextStyle(color: fg, fontSize: 11.5, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.state});

  final PointsState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _goldSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF5DFA8)),
      ),
      child: Row(
        children: [
          const Text('🪙', style: TextStyle(fontSize: 30)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('رصيدج: ${_money.format(state.balance)} نقطة = ${_money.format(state.balanceIqd)} د.ع',
                    style: const TextStyle(color: _gold, fontWeight: FontWeight.w800, fontSize: 15)),
                const Text('تنصرف بصفحة إتمام الطلب (لحد 20% من الطلب) · تنتهي إذا ما فتحتي التطبيق 30 يوم',
                    style: TextStyle(color: AppColors.muted, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WaysCard extends StatelessWidget {
  const _WaysCard();

  static const _ways = [
    ('🎁', 'هدية كل يوم تفتحين التطبيق', 'لحد 40'),
    ('🛍️', 'كل 1,000 د.ع بطلبج (بدون التوصيل)', '+2'),
    ('📦', 'أكدي استلام طلبج', '+50'),
    ('👭', 'ادعي صديقتج وتطلب', '+300'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Expanded(child: Text('اجمعي نقاط أكثر', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
              Text('100 نقطة = 1,000 د.ع', style: TextStyle(color: AppColors.muted, fontSize: 12)),
            ],
          ),
          for (var i = 0; i < _ways.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                border: i == _ways.length - 1 ? null : const Border(bottom: BorderSide(color: AppColors.line)),
              ),
              child: Row(
                children: [
                  SizedBox(width: 32, child: Text(_ways[i].$1, style: const TextStyle(fontSize: 20))),
                  Expanded(child: Text(_ways[i].$2, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(color: _goldSoft, borderRadius: BorderRadius.circular(99)),
                    child: Text(_ways[i].$3, style: const TextStyle(color: _gold, fontWeight: FontWeight.w800, fontSize: 12)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ReferralCard extends StatelessWidget {
  const _ReferralCard({required this.code, required this.onShare});

  final String code;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('ادعي صديقتج 👭', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const Text('صديقتج تكتب كودج بأول طلب، ولما يوصلها: إنتي تاخذين 300 نقطة وهي 100',
              style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('انتسخ الكود ✓')));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(code,
                            textDirection: TextDirection.ltr,
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 3)),
                        const SizedBox(width: 8),
                        const Icon(Icons.copy_rounded, size: 18, color: AppColors.muted),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: onShare,
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text('واتساب'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.history});

  final List<Map<String, dynamic>> history;

  static String _label(String reason) => switch (reason) {
        'daily' => 'هدية يومية',
        'order' => 'نقاط طلب',
        'received' => 'تأكيد استلام',
        'referral' => 'دعوة صديقة',
        'referred' => 'هدية الدعوة',
        'redeem' => 'استخدمتيها بطلب',
        'refund' => 'رجعت من طلب',
        'expire' => 'انتهت',
        _ => 'تعديل',
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('آخر الحركات', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          for (final h in history)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  Expanded(child: Text(_label('${h['reason']}'), style: const TextStyle(fontSize: 13.5))),
                  Text(
                    DateFormat('d/M').format(DateTime.tryParse('${h['created_at']}')?.toLocal() ?? DateTime.now()),
                    style: const TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${((h['delta'] as num?) ?? 0) > 0 ? '+' : ''}${h['delta']}',
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: ((h['delta'] as num?) ?? 0) > 0 ? AppColors.success : AppColors.sale,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _GuestInvite extends StatelessWidget {
  const _GuestInvite({required this.onLogin});

  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🪙', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 8),
            const Text('اجمعي نقاط وحوليها خصم', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text('هدية كل يوم، ونقاط من كل طلب، و100 نقطة = 1,000 د.ع.\nسجّلي دخول حتى تبدين تجمعين.',
                textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.brand, minimumSize: const Size(220, 48)),
              onPressed: onLogin,
              child: const Text('سجّلي دخول / حساب جديد'),
            ),
          ],
        ),
      ),
    );
  }
}
