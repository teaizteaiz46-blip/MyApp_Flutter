import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';
import 'modo_product_card.dart' show kMoney;

/// الكوبون المحفوظ يتعبّى تلقائياً بصفحة إتمام الطلب.
const String kPendingCouponKey = 'pending_coupon_code';
const String _kShownKey = 'welcome_coupon_shown_v1';

/// يطلع مرة وحدة بس لكل جهاز، إذا أكو كوبون ترحيبي فعّال بالقاعدة.
Future<void> maybeShowWelcomeCoupon(BuildContext context) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_kShownKey) ?? false) return;

    final res = await Supabase.instance.client.rpc('get_welcome_coupon');
    if (res == null || res is! Map) return;
    final coupon = Map<String, dynamic>.from(res);
    final code = (coupon['code'] ?? '').toString();
    if (code.isEmpty) return;

    await prefs.setBool(_kShownKey, true);
    if (!context.mounted) return;

    final accepted = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'إغلاق',
      barrierColor: Colors.black.withValues(alpha: 0.6),
      transitionDuration: const Duration(milliseconds: 380),
      pageBuilder: (_, _, _) => _WelcomeCouponDialog(coupon: coupon),
      transitionBuilder: (context, anim, _, child) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
          child: child,
        ),
      ),
    );

    if (accepted == true) {
      await prefs.setString(kPendingCouponKey, code);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('انحفظ الكوبون، وراح ينطبق تلقائياً عند إتمام الطلب')),
        );
      }
    }
  } catch (e) {
    debugPrint('Welcome coupon: $e');
  }
}

class _WelcomeCouponDialog extends StatelessWidget {
  const _WelcomeCouponDialog({required this.coupon});

  final Map<String, dynamic> coupon;

  @override
  Widget build(BuildContext context) {
    final code = (coupon['code'] ?? '').toString();
    final discount = (coupon['discount'] as num?)?.toDouble() ?? 0;
    final title = (coupon['title'] ?? '').toString().trim();
    final firstOrderOnly = coupon['first_order_only'] == true;
    final expiresAt = DateTime.tryParse('${coupon['expires_at'] ?? ''}');

    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.topCenter,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 56),
                        padding: const EdgeInsets.fromLTRB(20, 64, 20, 20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFFFFF8F2), Color(0xFFFFE2CC)],
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'مبروك!',
                              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.ink),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'هدية ترحيب إلك من MODO',
                              style: TextStyle(fontSize: 14, color: AppColors.muted),
                            ),
                            const SizedBox(height: 16),
                            _Ticket(
                              top: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text.rich(
                                    TextSpan(children: [
                                      TextSpan(
                                        text: kMoney.format(discount),
                                        style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
                                      ),
                                      const TextSpan(
                                        text: ' د.ع خصم',
                                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                                      ),
                                    ]),
                                    style: const TextStyle(color: AppColors.sale),
                                  ),
                                  if (title.isNotEmpty)
                                    Text(
                                      title,
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.ink),
                                    ),
                                ],
                              ),
                              bottom: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Text('الكود: ', style: TextStyle(color: AppColors.muted)),
                                      Text(
                                        code,
                                        textDirection: TextDirection.ltr,
                                        style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.5),
                                      ),
                                      const Spacer(),
                                      InkWell(
                                        borderRadius: BorderRadius.circular(8),
                                        onTap: () {
                                          Clipboard.setData(ClipboardData(text: code));
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('تم نسخ الكود')),
                                          );
                                        },
                                        child: const Padding(
                                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.copy_rounded, size: 16, color: AppColors.brandDark),
                                              SizedBox(width: 3),
                                              Text('نسخ', style: TextStyle(color: AppColors.brandDark, fontWeight: FontWeight.w700)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    [
                                      if (firstOrderOnly) 'صالح لأول طلب فقط',
                                      if (expiresAt != null)
                                        'ينتهي ${expiresAt.toLocal().day}/${expiresAt.toLocal().month}/${expiresAt.toLocal().year}',
                                    ].join(' · '),
                                    style: const TextStyle(fontSize: 12, color: AppColors.muted),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(28),
                                  gradient: const LinearGradient(colors: [Color(0xFFFF8A4C), Color(0xFFEF3E2D)]),
                                  boxShadow: const [
                                    BoxShadow(color: Color(0x40EF3E2D), blurRadius: 12, offset: Offset(0, 5)),
                                  ],
                                ),
                                child: Material(
                                  type: MaterialType.transparency,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(28),
                                    onTap: () => Navigator.of(context).pop(true),
                                    child: const Center(
                                      child: Text(
                                        'حسناً، احفظ الكوبون',
                                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const _GiftBadge(),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: 'إغلاق',
                      icon: const Icon(Icons.close_rounded, color: AppColors.ink),
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GiftBadge extends StatelessWidget {
  const _GiftBadge();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      height: 112,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 108,
            height: 108,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFF8A4C), Color(0xFFEF3E2D)],
              ),
              border: Border.all(color: Colors.white, width: 5),
              boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 16, offset: Offset(0, 6))],
            ),
            child: const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 54),
          ),
          const Positioned(top: 4, left: 8, child: Icon(Icons.auto_awesome, color: Color(0xFFFFD54F), size: 22)),
          const Positioned(bottom: 10, right: 4, child: Icon(Icons.auto_awesome, color: Color(0xFFFFD54F), size: 16)),
          const Positioned(top: 18, right: 10, child: Icon(Icons.circle, color: Color(0xFFFFC107), size: 10)),
        ],
      ),
    );
  }
}

/// كارت بشكل تذكرة: قصّات دائرية بالجانبين وخط منقط بالنص.
class _Ticket extends StatelessWidget {
  const _Ticket({required this.top, required this.bottom});

  final Widget top;
  final Widget bottom;

  static const double _notch = 10;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ClipPath(
          clipper: _TicketClipper(notchRadius: _notch, notchY: 86),
          child: Container(
            width: constraints.maxWidth,
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 86,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Align(alignment: AlignmentDirectional.centerStart, child: top),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: CustomPaint(size: Size(double.infinity, 1), painter: _DashPainter()),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
                  child: bottom,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TicketClipper extends CustomClipper<Path> {
  const _TicketClipper({required this.notchRadius, required this.notchY});

  final double notchRadius;
  final double notchY;

  @override
  Path getClip(Size size) {
    final card = Path()
      ..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(14)));
    final notches = Path()
      ..addOval(Rect.fromCircle(center: Offset(0, notchY), radius: notchRadius))
      ..addOval(Rect.fromCircle(center: Offset(size.width, notchY), radius: notchRadius));
    return Path.combine(PathOperation.difference, card, notches);
  }

  @override
  bool shouldReclip(_TicketClipper old) => old.notchY != notchY || old.notchRadius != notchRadius;
}

class _DashPainter extends CustomPainter {
  const _DashPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.line
      ..strokeWidth = 1.2;
    const dash = 6.0, gap = 4.0;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(math.min(x + dash, size.width), 0), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
