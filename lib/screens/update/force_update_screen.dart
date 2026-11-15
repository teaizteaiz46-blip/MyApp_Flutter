import 'package:flutter/material.dart';

import '../../services/update_service.dart';
import '../../theme/app_theme.dart';

/// شاشة "تحديث مطلوب": تغطي التطبيق كله لحد ما الزبون يحدّث (ما تتسكر بزر الرجوع).
class ForceUpdateScreen extends StatelessWidget {
  const ForceUpdateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final m = context.modo;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: m.page,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'MODO',
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.ltr,
                  style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: AppColors.brand, letterSpacing: 3),
                ),
                const SizedBox(height: 28),
                const Text('🎉', textAlign: TextAlign.center, style: TextStyle(fontSize: 46)),
                const SizedBox(height: 12),
                Text(
                  'نسخة جديدة من التطبيق',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: m.ink),
                ),
                const SizedBox(height: 10),
                Text(
                  'حتى تكملون التسوق، حدّثوا التطبيق لآخر نسخة.\nالتحديث ياخذ دقيقة وحدة.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, height: 1.6, color: m.muted),
                ),
                const SizedBox(height: 30),
                FilledButton(
                  onPressed: UpdateService.openStore,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('حدّثوا الآن', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
