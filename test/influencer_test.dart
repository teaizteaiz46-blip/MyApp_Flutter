import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapprun/screens/influencer/influencer_wallet_screen.dart';
import 'package:myapprun/services/influencer_service.dart';

void main() {
  testWidgets('"أرباحي" تعرض الكود والرصيد وحالات الطلبات (بدون أي معلومات زبائن)', (tester) async {
    final wallet = <String, dynamic>{
      'name': 'سارة', 'code': 'SARA', 'discount': 2000, 'commission': 1000, 'active': true,
      'earned': 3000, 'paid': 1000, 'balance': 2000, 'counted': 3,
      'recent': [
        {'at': '2026-11-15T10:00:00Z', 'state': 'counted', 'amount': 1000},
        {'at': '2026-11-14T10:00:00Z', 'state': 'in_progress', 'amount': null},
        {'at': '2026-11-13T10:00:00Z', 'state': 'cancelled', 'amount': null},
        {'at': '2026-11-12T10:00:00Z', 'state': 'not_counted', 'amount': null},
      ],
      'payouts': [
        {'amount': 1000, 'at': '2026-11-10T10:00:00Z'},
      ],
    };
    await tester.pumpWidget(MaterialApp(
      home: Directionality(textDirection: TextDirection.rtl, child: Scaffold(body: InfluencerWalletBody(wallet: wallet))),
    ));
    expect(find.text('SARA'), findsOneWidget);
    expect(find.text('2,000 د.ع'), findsWidgets); // الرصيد
    expect(find.text('محسوب +1,000 د.ع'), findsOneWidget);
    expect(find.text('قيد التوصيل'), findsOneWidget);
    expect(find.text('ملغي'), findsOneWidget);
    expect(find.text('غير محسوب (مو أول طلب للزبونة)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('بعد الرفض يقدم مرة ثانية بعد أسبوع (نفس شرط السيرفر)', () {
    final recent = InfluencerStatus(
      isInfluencer: false,
      applicationStatus: 'rejected',
      reviewedAt: DateTime.now().subtract(const Duration(days: 2)),
    );
    expect(recent.canReapply, isFalse);
    final old = InfluencerStatus(
      isInfluencer: false,
      applicationStatus: 'rejected',
      reviewedAt: DateTime.now().subtract(const Duration(days: 8)),
    );
    expect(old.canReapply, isTrue);
    expect(const InfluencerStatus(isInfluencer: false, applicationStatus: 'pending').canReapply, isFalse);
  });

  test('رابط المؤثر نفس رابط صفحة الأدمن (حتى الزيارات تنحسب له)', () {
    expect(
      InfluencerService.shareLink('HAJAR'),
      'https://teaizteaiz46-blip.github.io/Modo-orders/app.html?utm_source=influencer&utm_campaign=inf_hajar',
    );
  });
}
