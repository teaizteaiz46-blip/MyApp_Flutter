import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapprun/screens/details/details_screen.dart';

/// لوحة ألوان مثل صفحة المنتج: كل لون بعدده، والدوسات تغيّر العدد مثل الصفحة
class _Picker extends StatefulWidget {
  const _Picker({required this.colors, this.stock = 1000});
  final List<String> colors;
  final int stock;

  @override
  State<_Picker> createState() => _PickerState();
}

class _PickerState extends State<_Picker> {
  final Map<String, int> counts = {};
  int get total => counts.values.fold(0, (s, n) => s + n);

  void change(String c, int d) => setState(() {
        final n = (counts[c] ?? 0) + d;
        n <= 0 ? counts.remove(c) : counts[c] = n;
      });

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Wrap(children: [
            for (final c in widget.colors)
              ColorCountChip(
                label: c,
                count: counts[c] ?? 0,
                canAdd: (counts[c] ?? 0) < 100 && total < widget.stock,
                onAdd: () => change(c, 1),
                onRemove: () => change(c, -1),
              ),
          ]),
          Text('total:$total ${counts.entries.map((e) => '${e.key}=${e.value}').join(',')}'),
        ],
      );
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(320, 568);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    builder: (context, c) => Directionality(textDirection: TextDirection.rtl, child: c!),
    home: Scaffold(body: Padding(padding: const EdgeInsets.all(14), child: child)),
  ));
}

final _colors = [for (final n in [2, 3, 4, 5, 6, 8, 9, 11, 12, 13, 14, 15]) 'موديل $n'];

Finder _inChip(String label, Finder f) =>
    find.descendant(of: find.ancestor(of: find.text(label), matching: find.byType(ColorCountChip)), matching: f);

void main() {
  testWidgets('دوسة على اللون = قطعة وحدة، وبعدها + و − يغيّرون العدد، وبالـ 1 السلة تشيله', (tester) async {
    await _pump(tester, _Picker(colors: _colors));

    await tester.tap(find.text('موديل 3'));
    await tester.pump();
    expect(find.text('total:1 موديل 3=1'), findsOneWidget);
    // بالعدد 1 الـ − يصير سلة مهملات
    expect(_inChip('موديل 3', find.byIcon(Icons.delete_outline)), findsOneWidget);

    await tester.tap(_inChip('موديل 3', find.text('+')));
    await tester.tap(_inChip('موديل 3', find.text('+')));
    await tester.pump();
    expect(find.text('total:3 موديل 3=3'), findsOneWidget);
    expect(_inChip('موديل 3', find.text('−')), findsOneWidget);

    await tester.tap(find.text('موديل 8'));
    await tester.pump();
    await tester.tap(_inChip('موديل 8', find.text('+')));
    await tester.tap(find.text('موديل 12'));
    await tester.pump();
    expect(find.text('total:6 موديل 3=3,موديل 8=2,موديل 12=1'), findsOneWidget);

    await tester.tap(_inChip('موديل 3', find.text('−')));
    await tester.pump();
    expect(find.text('total:5 موديل 3=2,موديل 8=2,موديل 12=1'), findsOneWidget);

    // السلة على موديل 12 تشيله من الاختيار
    await tester.tap(_inChip('موديل 12', find.byIcon(Icons.delete_outline)));
    await tester.pump();
    expect(find.text('total:4 موديل 3=2,موديل 8=2'), findsOneWidget);
    expect(_inChip('موديل 12', find.text('+')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('الـ + يوقف من يخلص المخزون', (tester) async {
    await _pump(tester, _Picker(colors: _colors, stock: 2));
    await tester.tap(find.text('موديل 3'));
    await tester.pump();
    await tester.tap(_inChip('موديل 3', find.text('+')));
    await tester.pump();
    await tester.tap(_inChip('موديل 3', find.text('+')));
    await tester.tap(find.text('موديل 8'));
    await tester.pump();
    expect(find.text('total:2 موديل 3=2'), findsOneWidget);
  });

  testWidgets('ثلاث ألوان مختارة بعدد كبير تنعرض بدون تجاوز على شاشة صغيرة', (tester) async {
    await _pump(
      tester,
      Wrap(children: [
        for (final c in _colors)
          ColorCountChip(
            label: c,
            count: switch (c) { 'موديل 3' => 100, 'موديل 8' => 12, 'موديل 12' => 1, _ => 0 },
            canAdd: c != 'موديل 3',
            onAdd: () {},
            onRemove: () {},
          ),
        const ColorCountChip(label: 'أسود – XXXL طويل جداً', count: 7, canAdd: true, onAdd: _noop, onRemove: _noop),
      ]),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('100'), findsOneWidget);
  });
}

void _noop() {}
