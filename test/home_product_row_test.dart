import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapprun/screens/home/components/home_product_row.dart';
import 'package:myapprun/services/app_config.dart';
import 'package:myapprun/theme/app_theme.dart';
import 'package:myapprun/widgets/modo_product_card.dart';

// خط حقيقي بيه عربي (خط الاختبار الافتراضي كل حرف بي مربع عريض، فيطلع تجاوزات وهمية)
const _fontRegular = 'C:/Windows/Fonts/tahoma.ttf';
const _fontBold = 'C:/Windows/Fonts/tahomabd.ttf';
final bool _hasFont = File(_fontRegular).existsSync() && File(_fontBold).existsSync();

Map<String, dynamic> _product(int id, {bool worst = false}) => {
      'id': id,
      'name': worst ? 'هاينك شتائي بدون ردن - منقط باللؤلؤ الأصلي' : 'ستريج سادة',
      'price': worst ? 35000 : 5000,
      'old_price': worst ? 42000 : 6000,
      'stock': 10,
      'image_url': <String>[],
      'colors': ['موديل 1', 'موديل 2', 'موديل 3'],
      'category_id': 10,
      'created_at': DateTime.now().toIso8601String(),
      // أصعب حالة: "يبدأ من" + السعر + المشطوب + سطر عرض الكمية
      if (worst)
        'unit_tiers': [
          {'min': 6, 'pct': 10},
          {'min': 12, 'pct': 20},
        ],
    };

Widget _app(ThemeMode mode, Widget child, {double textScale = 1}) => MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: mode,
      locale: const Locale('ar', 'IQ'),
      supportedLocales: const [Locale('ar', 'IQ')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  setUpAll(() async {
    if (!_hasFont) return;
    final loader = FontLoader('Muli')
      ..addFont(File(_fontRegular).readAsBytes().then(ByteData.sublistView))
      ..addFont(File(_fontBold).readAsBytes().then(ByteData.sublistView));
    await loader.load();
  });

  group('إعدادات الصف من store_settings', () {
    test('مطفي = null (يطلع البانر)', () {
      expect(HomeRowConfig.fromSettings(const {}), isNull);
      expect(HomeRowConfig.fromSettings(const {'home_row_on': false, 'home_row_category_id': 10}), isNull);
    });

    test('من قسم', () {
      final c = HomeRowConfig.fromSettings(const {
        'home_row_on': true,
        'home_row_source': 'category',
        'home_row_category_id': 10,
        'home_row_title': ' 👗 ملابس ',
        'home_row_subtitle': 'وصلت جديد',
        'home_row_limit': 50,
      })!;
      expect(c.isPicked, isFalse);
      expect(c.categoryId, 10);
      expect(c.title, '👗 ملابس');
      expect(c.limit, 20); // أكثر شي 20
      expect(c.cacheKey, 'c_10_20');
    });

    test('منتجات مختارة: الترتيب يبقى والمكرر ينشال', () {
      final c = HomeRowConfig.fromSettings(const {
        'home_row_on': true,
        'home_row_source': 'products',
        'home_row_category_id': 10, // ينهمل لأن المصدر "منتجات"
        'home_row_product_ids': [933, 908, 933, 935],
        'home_row_limit': 2,
        'home_row_all_category_id': 10,
      })!;
      expect(c.isPicked, isTrue);
      expect(c.categoryId, isNull);
      expect(c.productIds, [933, 908, 935]);
      expect(c.limit, 3); // أقل شي 3
      expect(c.allCategoryId, 10);
    });

    test('مشغّل بس بدون قسم أو منتجات = null', () {
      expect(HomeRowConfig.fromSettings(const {'home_row_on': true, 'home_row_source': 'category'}), isNull);
      expect(HomeRowConfig.fromSettings(const {'home_row_on': true, 'home_row_source': 'products', 'home_row_product_ids': []}), isNull);
    });

    test('AppConfig.homeRow يقرا نفس الصف', () {
      AppConfig.debugSet(const {'home_row_on': true, 'home_row_category_id': 4});
      expect(AppConfig.homeRow?.categoryId, 4);
      AppConfig.debugSet(const {});
      expect(AppConfig.homeRow, isNull);
    });
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('الصف بموبايل ضيق بدون تجاوز (${mode.name}، حجم خط $scale)', (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        Map<String, dynamic>? tapped;
        var seeAll = 0;
        await tester.pumpWidget(_app(
          mode,
          HomeProductRowView(
            title: '👗 ملابس',
            subtitle: 'وصلت جديد',
            products: [_product(1, worst: true), _product(2), _product(3, worst: true), _product(4)],
            onProductTap: (p) => tapped = p,
            onSeeAll: () => seeAll++,
          ),
          textScale: scale,
        ));
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.textContaining('👗 ملابس'), findsOneWidget);
        expect(find.textContaining('وصلت جديد'), findsOneWidget);
        expect(find.byType(ModoProductCard), findsWidgets);
        // الكارت الأول يبين كامل والثالث مكصوص (يبين إنه ينسحب)
        final first = tester.getRect(find.byType(ModoProductCard).first);
        expect(first.width, HomeProductRowView.cardWidth);
        expect(first.right, lessThanOrEqualTo(360 - 14 + 0.5));

        await tester.tap(find.text('عرض الكل ←'));
        expect(seeAll, 1);
        await tester.tap(find.byType(ModoProductCard).first);
        expect(tapped?['id'], 1);

        // السحب يحرّك الصف
        final before = tester.getRect(find.byType(ModoProductCard).first).left;
        await tester.drag(find.byType(ListView), const Offset(250, 0));
        await tester.pumpAndSettle();
        expect(tester.getRect(find.byType(ModoProductCard).first).left, isNot(before));
        expect(tester.takeException(), isNull);
      }, skip: !_hasFont);
    }
  }

  testWidgets('كروت الصف: شارة وحدة بس فوق الصورة (الخصم، وإلا جديد)، والجملة بالسطر الأخضر', (tester) async {
    tester.view.physicalSize = const Size(700, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final old = DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
    // الكروت نفسها بدون ارتفاع الصف الثابت: الفحص يبقى صحيح حتى بخط الفحوصات العريض
    // (بالماك ماكو Tahoma، والكلام العريض كان يطلع برا الارتفاع الثابت ويفشل بـ Codemagic)
    await tester.pumpWidget(_app(
      ThemeMode.light,
      Column(
        children: [
          // خصم + جملة: الخصم بس فوق الصورة
          SizedBox(
            width: HomeProductRowView.cardWidth,
            child: ModoProductCard(product: {..._product(1, worst: true), 'created_at': old}, onTap: () {}, swipeImages: false, singleBadge: true),
          ),
          // جديد بدون خصم: "جديد" بس
          SizedBox(
            width: HomeProductRowView.cardWidth,
            child: ModoProductCard(product: {..._product(2), 'old_price': null}, onTap: () {}, swipeImages: false, singleBadge: true),
          ),
        ],
      ),
    ));
    await tester.pump();
    // شارة الخصم وحدة بس (النسبة تنحسب من أقل سعر جملة)
    expect(find.byWidgetPredicate((w) => w is Text && RegExp(r'^-\d+%$').hasMatch(w.data ?? '')), findsOneWidget);
    expect(find.textContaining('جملة من'), findsNothing);
    expect(find.textContaining('+ قطع بـ'), findsOneWidget); // معلومة الجملة تحت السعر
    expect(find.text('جديد ✨'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('وهو يحمّل: مربعات بنفس الحجم، وبدون "عرض الكل" إذا ماكو أكثر', (tester) async {
    await tester.pumpWidget(_app(
      ThemeMode.light,
      HomeProductRowView(title: 'مختارات لكم', subtitle: '', products: null, onProductTap: (_) {}),
    ));
    expect(tester.takeException(), isNull);
    expect(find.byType(ModoProductCard), findsNothing);
    expect(find.text('عرض الكل ←'), findsNothing);
    expect(find.textContaining('مختارات لكم'), findsOneWidget);
  });
}
