import 'package:flutter/material.dart';

import '../screens/orders/my_orders_screen.dart';
import '../services/guest_orders_service.dart';
import '../theme/app_theme.dart';

/// "📦 طلباتي" بصفحة الحساب للزبون بدون حساب: يطلع بس إذا هذا الموبايل بيه طلبات.
class GuestOrdersEntry extends StatelessWidget {
  const GuestOrdersEntry({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: GuestOrdersService.count,
      builder: (context, n, _) {
        if (n <= 0) return const SizedBox.shrink();
        final m = context.modo;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Material(
            color: AppColors.brand.withValues(alpha: m.isDark ? 0.14 : 0.08),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.brand, width: 1.4),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyOrdersScreen())),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.brand.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('📦', style: TextStyle(fontSize: 22)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Text('طلباتي', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: m.ink)),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                              decoration: BoxDecoration(color: AppColors.brand, borderRadius: BorderRadius.circular(99)),
                              child: Text('$n', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                            ),
                          ]),
                          const SizedBox(height: 2),
                          Text('تابعوا حالة طلباتكم بدون حساب', style: TextStyle(fontSize: 13, color: m.muted)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_left_rounded, color: AppColors.brand),
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
