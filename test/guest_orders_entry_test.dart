import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapprun/services/guest_orders_service.dart';
import 'package:myapprun/theme/app_theme.dart';
import 'package:myapprun/widgets/guest_orders_entry.dart';

void main() {
  Widget app() => MaterialApp(
        theme: AppTheme.dark,
        home: const Directionality(textDirection: TextDirection.rtl, child: Scaffold(body: GuestOrdersEntry())),
      );

  testWidgets('"طلباتي" للضيف تطلع بس إذا الموبايل بيه طلبات', (tester) async {
    GuestOrdersService.count.value = 0;
    await tester.pumpWidget(app());
    expect(find.text('طلباتي'), findsNothing);

    GuestOrdersService.count.value = 3;
    await tester.pump();
    expect(find.text('طلباتي'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('تابعوا حالة طلباتكم بدون حساب'), findsOneWidget);
    expect(tester.takeException(), isNull);
    GuestOrdersService.count.value = 0;
  });
}
