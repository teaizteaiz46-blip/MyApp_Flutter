import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapprun/services/order_confirm_service.dart';

Map<String, dynamic> _info({int items = 2}) => {
      'id': 412,
      'pending': true,
      'phone': '07701234567',
      'governorate': 'بغداد',
      'address': 'الكرادة، قرب ساحة كهرمانة، شارع 62 بيت 14 الطابق الثاني',
      'total': 31000,
      'pieces': items * 2,
      'items': [
        for (var i = 0; i < items; i++) {'name': 'شيلة دلايد الاصليه الكويتية موديل رقم $i', 'color': '${i + 1}', 'qty': 2},
      ],
    };

/// يفتح النافذة على شاشة تلفون صغيرة (من اليمين لليسار مثل التطبيق)، وجواب الزبون يوصل لـ [onResult]
Future<void> _openSheet(WidgetTester tester, Map<String, dynamic> info, void Function(String?) onResult) async {
  tester.view.physicalSize = const Size(320, 568);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () async => onResult(await showModalBottomSheet<String>(
              context: context,
              isScrollControlled: true,
              builder: (_) => OrderConfirmSheet(info: info),
            )),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('تعرض تفاصيل الطلب بدون ما تطلع برّا الشاشة', (tester) async {
    await _openSheet(tester, _info(items: 5), (_) {});
    expect(tester.takeException(), isNull);
    expect(find.text('أكّدوا طلبكم \u2066#412\u2069'), findsOneWidget);
    expect(find.text('و 2 منتجات ثانية'), findsOneWidget);
    expect(find.text('31,000 د.ع'), findsOneWidget);
    expect(find.text('07701234567'), findsOneWidget);
  });

  for (final (label, expected) in [('تأكيد الطلب ✓', 'confirm'), ('أريد أعدّل أو ألغي', 'change'), ('لاحقاً', null)]) {
    testWidgets('زر "$label" يرجع $expected', (tester) async {
      String? result = 'ما تسكّرت';
      await _openSheet(tester, _info(), (r) => result = r);
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(result, expected);
      expect(find.byType(OrderConfirmSheet), findsNothing);
    });
  }
}
