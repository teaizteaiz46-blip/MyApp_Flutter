import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapprun/screens/splash/splash_ad_screen.dart';

void main() {
  Widget host(Map<String, dynamic> ad, {required VoidCallback onClose, required ValueChanged<Widget> onOpen}) => MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: SplashAdScreen(key: ValueKey(ad), ad: ad, imageFile: File('missing.jpg'), onClose: onClose, onOpen: onOpen),
        ),
      );

  testWidgets('يعد تنازلي ويتسكّر لوحده بعد المدة', (tester) async {
    var closed = 0;
    await tester.pumpWidget(host({'duration_sec': 3, 'link_type': 'none'}, onClose: () => closed++, onOpen: (_) {}));
    expect(find.text('تخطي (3)'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.text('تخطي (2)'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1600));
    expect(closed, 1);
  });

  testWidgets('زر تخطي يسكّره فوراً', (tester) async {
    var closed = 0;
    await tester.pumpWidget(host({'duration_sec': 5, 'link_type': 'none'}, onClose: () => closed++, onOpen: (_) {}));
    await tester.tap(find.textContaining('تخطي'));
    expect(closed, 1);
  });

  testWidgets('زر العرض يطلع بس إذا اكو رابط', (tester) async {
    Widget? opened;
    await tester.pumpWidget(host(
      {'duration_sec': 4, 'link_type': 'bulk', 'button_text': 'تسوّقي العرض'},
      onClose: () {},
      onOpen: (w) => opened = w,
    ));
    await tester.tap(find.text('تسوّقي العرض'));
    expect(opened, isNotNull);

    await tester.pumpWidget(host({'duration_sec': 4, 'link_type': 'none', 'button_text': 'تسوّقي'}, onClose: () {}, onOpen: (_) {}));
    expect(find.text('تسوّقي'), findsNothing);
  });
}
