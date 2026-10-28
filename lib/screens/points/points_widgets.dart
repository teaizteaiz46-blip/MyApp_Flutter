import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;

import '../../services/points_service.dart';
import '../../theme/app_theme.dart';
import 'points_screen.dart';

final NumberFormat _money = NumberFormat('#,###');

void openPoints(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PointsScreen()));

/// شارة الرصيد بأعلى الرئيسية (للزائرة: هدية)
class PointsChip extends StatelessWidget {
  const PointsChip({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PointsState?>(
      valueListenable: PointsService.instance.state,
      builder: (context, s, _) {
        final dot = s != null && !s.claimedToday;
        return InkWell(
          borderRadius: BorderRadius.circular(99),
          onTap: () => openPoints(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(color: const Color(0xFFFFF4D9), borderRadius: BorderRadius.circular(99)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(dot || s == null ? '🎁' : '🪙', style: const TextStyle(fontSize: 15)),
                if (s != null) ...[
                  const SizedBox(width: 4),
                  Text(_money.format(s.balance),
                      style: const TextStyle(color: Color(0xFF8A5A00), fontWeight: FontWeight.w800, fontSize: 13.5)),
                ],
                if (dot) ...[
                  const SizedBox(width: 4),
                  Container(width: 7, height: 7, decoration: const BoxDecoration(color: AppColors.sale, shape: BoxShape.circle)),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// شريط "هديتج اليومية" بالرئيسية: يطلع إذا ما استلمت هدية اليوم (وللزائرة يشجعها تسجل)
class DailyGiftBanner extends StatelessWidget {
  const DailyGiftBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PointsState?>(
      valueListenable: PointsService.instance.state,
      builder: (context, s, _) {
        final signedIn = PointsService.instance.signedIn;
        if (signedIn && (s == null || s.claimedToday)) return const SizedBox.shrink();
        final title = signedIn ? 'هديتج اليومية تنتظرج 🎁' : 'اجمعي نقاط وحوليها خصم 🪙';
        final sub = signedIn
            ? 'استلمي ${s!.todayPoints} نقطة · يوم ${s.streakDay} من 7'
            : 'سجّلي واستلمي هدية كل يوم';
        return Container(
          color: AppColors.surface,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: Material(
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => openPoints(context),
              child: Ink(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0xFFFFB347), AppColors.brand]),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                          Text(sub, style: const TextStyle(color: Colors.white, fontSize: 12.5)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(99)),
                      child: Text(signedIn ? 'استلمي' : 'ابدي',
                          style: const TextStyle(color: AppColors.brandDark, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
