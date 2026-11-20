import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapprun/core/offline_cache.dart';
import 'package:myapprun/no_internet_screen.dart';
import 'package:myapprun/screens/appearance/appearance_screen.dart';
import 'package:myapprun/screens/auth/account_view.dart';
import 'package:myapprun/screens/auth/auth_screen.dart';
import 'package:myapprun/screens/cart/cart_screen.dart';
import 'package:myapprun/screens/categories/all_categories_screen.dart';
import 'package:myapprun/screens/chat/chat_screen.dart';
import 'package:myapprun/screens/checkout/checkout_screen.dart';
import 'package:myapprun/screens/details/details_screen.dart';
import 'package:myapprun/screens/home/home_screen.dart';
import 'package:myapprun/screens/offers/offer_products_screen.dart';
import 'package:myapprun/screens/orders/my_orders_screen.dart';
import 'package:myapprun/screens/points/points_screen.dart';
import 'package:myapprun/screens/policy/privacy_policy_screen.dart';
import 'package:myapprun/screens/search/search_screen.dart';
import 'package:myapprun/screens/update/force_update_screen.dart';
import 'package:myapprun/screens/wishlist/wishlist_screen.dart';
import 'package:myapprun/services/cart_service.dart';
import 'package:myapprun/services/offers_service.dart';
import 'package:myapprun/services/order_confirm_service.dart';
import 'package:myapprun/theme/app_theme.dart';
import 'package:myapprun/theme/theme_controller.dart';
import 'package:myapprun/widgets/modo_product_card.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakePathProvider extends PathProviderPlatform with MockPlatformInterfaceMixin {
  _FakePathProvider(this.path);

  final String path;

  @override
  Future<String?> getApplicationSupportPath() async => path;

  @override
  Future<String?> getTemporaryPath() async => path;
}

const int _productId = 861;

final Map<String, dynamic> _product = {
  'id': _productId,
  'name': 'شيلة دلايد الاصليه الكويتية',
  'price': 7000,
  'old_price': 9000,
  'stock': 40,
  'image_url': <String>[],
  'colors': ['موديل 1', 'موديل 2', 'موديل 3'],
  'description': 'قماش ناعم وخفيف',
  'sales_count': 120,
  'rating': 4.6,
  'bulk_tiers': [
    {'qty': 3, 'price': 18000},
  ],
  'category_id': 1,
  'created_at': DateTime.now().toIso8601String(),
};

/// نفس إعدادات التطبيق (عربي، من اليمين لليسار) ويه الثيمين
Widget _app(ThemeMode mode, Widget home) => MaterialApp(
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
      home: home,
    );

Future<void> _show(WidgetTester tester, ThemeMode mode, Widget screen) async {
  // خط الاختبار عريض (كل حرف مربع)، فنعطي الشاشة عرض أكبر حتى ما تطلع تجاوزات وهمية
  tester.view.physicalSize = const Size(640, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app(mode, screen));
  // الطلبات تفشل بهدوء (ماكو سيرفر بالاختبار)، والملفات المحفوظة تنقرا بالوقت الحقيقي (كل خطوة قراءة تحتاج دورة)
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
    await tester.pump(const Duration(milliseconds: 300));
  }
}

/// يتأكد ما طلع خطأ، وإن ألوان الوضع الصحيح وصلت للشاشة
Future<void> _check(WidgetTester tester, ThemeMode mode, Type screen, String? text) async {
  expect(tester.takeException(), isNull);
  if (text != null) expect(find.textContaining(text), findsWidgets);
  final context = tester.element(find.byType(screen).first);
  final dark = mode == ThemeMode.dark;
  expect(Theme.of(context).brightness, dark ? Brightness.dark : Brightness.light);
  expect(context.modo.isDark, dark);
  expect(context.modo.page, dark ? const Color(0xFF121110) : Colors.white);
  // نسكّر الشاشة حتى المؤقتات (الدردشة، العدادات) تتوقف
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 6));
}

void main() {
  late Directory tmp;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    tmp = Directory.systemTemp.createTempSync('dark_mode_test');
    PathProviderPlatform.instance = _FakePathProvider(tmp.path);
    await Supabase.initialize(
      url: 'http://127.0.0.1:9',
      anonKey: 'test-anon-key',
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
    );
    // صفحة المنتج تفتح من آخر نسخة محفوظة بالجهاز
    await OfflineCache.fetch('product_$_productId', () async => [_product]);
    // الشاشات ما تطلع شاشة اختيار المظهر فوقها
    await ThemeController.choose(ThemeMode.dark);
    // السلة تتحمّل مرة وحدة (المستقبل المحفوظ لازم ينخلق برا اختبارات الواجهة)
    await CartService.instance.load();
  });

  tearDownAll(() {
    try {
      tmp.deleteSync(recursive: true);
    } catch (_) {}
  });

  test('بدون أي اختيار محفوظ التطبيق ليلي، والاختيار ينحفظ', () async {
    ThemeController.debugReset();
    expect(ThemeController.mode.value, ThemeMode.dark);
    expect(ThemeController.hasChoice, isFalse);

    await ThemeController.choose(ThemeMode.light);
    final prefs = await SharedPreferences.getInstance();
    ThemeController.debugReset();
    await ThemeController.init();
    expect(ThemeController.mode.value, ThemeMode.light);
    expect(ThemeController.hasChoice, isTrue);
    expect(prefs.getString('app_theme_mode_v1'), 'light');

    await ThemeController.choose(ThemeMode.dark);
  });

  test('الفاتح نفس الألوان القديمة بالضبط', () {
    final light = AppTheme.light;
    expect(light.scaffoldBackgroundColor, const Color(0xFFF5F5F5));
    expect(light.brightness, Brightness.light);
    expect(light.appBarTheme.elevation, 0);
    expect(ModoColors.light.background, AppColors.background);
    expect(ModoColors.light.ink, AppColors.ink);
    expect(ModoColors.light.surface, Colors.white);
    expect(AppTheme.dark.scaffoldBackgroundColor, const Color(0xFF121110));
    expect(AppTheme.dark.colorScheme.primary, AppColors.brand);
  });

  final screens = <String, (Type, Widget Function(), String?)>{
    'الرئيسية': (HomeScreen, () => const HomeScreen(), 'كل التشكيلة'),
    'صفحة المنتج': (DetailsScreen, () => const DetailsScreen(productId: _productId), 'شيلة دلايد'),
    'السلة': (CartScreen, () => const CartScreen(), 'سلتك فارغة'),
    'إتمام الطلب': (CheckoutScreen, () => const CheckoutScreen(), 'إتمام الطلب'),
    'طلباتي': (MyOrdersScreen, () => const MyOrdersScreen(), 'ماكو طلبات حالية'),
    'تسجيل الدخول': (AuthScreen, () => const AuthScreen(), 'المظهر'),
    'حسابي': (
      AccountView,
      () => AccountView(
            user: User(
              id: 'u1',
              appMetadata: const {},
              userMetadata: const {},
              aud: 'authenticated',
              createdAt: '2026-01-01T00:00:00Z',
              email: 'test@example.com',
            ),
          ),
      'المظهر',
    ),
    'البحث': (SearchScreen, () => const SearchScreen(), null),
    'المفضلة': (WishlistScreen, () => const WishlistScreen(), 'ماكو قطع بالمفضلة'),
    'الفئات': (AllCategoriesScreen, () => const AllCategoriesScreen(), 'جميع الفئات'),
    'الدردشة': (ChatScreen, () => const ChatScreen(), 'هلا بيكم'),
    'نقاطي': (PointsScreen, () => const PointsScreen(), 'اجمعي نقاط'),
    'العروض': (
      OfferProductsScreen,
      () => OfferProductsScreen(
            offer: Offer(
              id: 1,
              title: 'أي 3 قطع بـ 20,000',
              isBundle: true,
              qty: 3,
              price: 20000,
              freeDelivery: true,
              endsAt: DateTime.now().add(const Duration(hours: 5)),
              productIds: const [_productId, 862],
            ),
          ),
      'تگدرون تجمعون',
    ),
    'تحديث مطلوب': (ForceUpdateScreen, () => const ForceUpdateScreen(), 'نسخة جديدة'),
    'ماكو إنترنت': (NoInternetScreen, () => NoInternetScreen(onRetry: () {}), 'لا يوجد اتصال'),
    'سياسة الخصوصية': (PrivacyPolicyScreen, () => const PrivacyPolicyScreen(), 'حقوقك'),
    'اختيار المظهر': (ThemeChooserScreen, () => ThemeChooserScreen(onDone: (_) {}), 'اختاروا شكل التطبيق'),
    'كروت المنتجات': (
      ModoProductCard,
      () => Scaffold(
            body: GridView.count(
              crossAxisCount: 2,
              childAspectRatio: 0.55,
              children: [
                for (var i = 0; i < 4; i++) ModoProductCard(product: {..._product, 'id': i + 1}, onTap: () {}),
              ],
            ),
          ),
      'يبدأ من',
    ),
  };

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    for (final entry in screens.entries) {
      testWidgets('${entry.key} تنبني بالوضع ${mode == ThemeMode.dark ? 'الليلي' : 'الفاتح'}', (tester) async {
        await _show(tester, mode, entry.value.$2());
        await _check(tester, mode, entry.value.$1, entry.value.$3);
      });
    }

    testWidgets('نافذة تأكيد الطلب ونافذة المظهر بالوضع ${mode.name}', (tester) async {
      await _show(
        tester,
        mode,
        Builder(
          builder: (context) => Scaffold(
            body: Column(
              children: [
                TextButton(
                  onPressed: () => showModalBottomSheet<String>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: context.modo.surface,
                    builder: (_) => const OrderConfirmSheet(info: {
                      'id': 5,
                      'phone': '07701234567',
                      'governorate': 'بغداد',
                      'total': 31000,
                      'pieces': 4,
                      'items': [
                        {'name': 'شيلة', 'color': '1', 'qty': 2},
                      ],
                    }),
                  ),
                  child: const Text('confirm'),
                ),
                TextButton(onPressed: () => showAppearanceSheet(context), child: const Text('appearance')),
                const RewardCouponCard(coupon: {'percent': 10, 'max_discount': 5000}),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.text('confirm'));
      await tester.pumpAndSettle();
      expect(find.byType(OrderConfirmSheet), findsOneWidget);
      Navigator.of(tester.element(find.byType(OrderConfirmSheet))).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.text('appearance'));
      await tester.pumpAndSettle();
      expect(find.text('المظهر'), findsOneWidget);
      expect(find.text('حسب إعداد الموبايل'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('الرئيسية: الأقسام بس ثابتة، وزر الترتيب يفتح القائمة ويبدّل', (tester) async {
    await _show(tester, ThemeMode.light, const HomeScreen());
    expect(tester.takeException(), isNull);
    // صف الترتيب القديم انشال، وسطر الجملة صار سطر صغير
    expect(find.text('ترتيب: '), findsNothing);
    expect(find.textContaining('سعر القطعة ينزل تلقائياً'), findsOneWidget);
    expect(find.text('الأكثر طلباً'), findsOneWidget); // الزر يم العنوان

    await tester.tap(find.text('الأكثر طلباً'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('ترتيب المنتجات'), findsOneWidget);
    expect(find.text('عروض الكمية'), findsOneWidget);

    await tester.tap(find.text('الأحدث'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('ترتيب المنتجات'), findsNothing);
    expect(find.text('الأحدث'), findsOneWidget); // الزر صار "الأحدث"
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('المظهر يتبدل فوراً بدون إعادة تشغيل', (tester) async {
    await ThemeController.choose(ThemeMode.dark);
    await tester.pumpWidget(ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.mode,
      builder: (context, mode, _) => _app(
        mode,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(onPressed: () => showAppearanceSheet(context), child: const Text('open')),
            ),
          ),
        ),
      ),
    ));
    BuildContext ctx() => tester.element(find.text('open'));
    expect(Theme.of(ctx()).brightness, Brightness.dark);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('فاتح'));
    await tester.pumpAndSettle();
    expect(ThemeController.mode.value, ThemeMode.light);
    expect(Theme.of(ctx()).brightness, Brightness.light);
    expect(ctx().modo.page, Colors.white);

    await tester.tap(find.text('ليلي'));
    await tester.pumpAndSettle();
    expect(Theme.of(ctx()).brightness, Brightness.dark);
    expect(tester.takeException(), isNull);
  });

  testWidgets('شاشة أول فتحة: ليلي مختار، والاختيار ينحفظ بـ متابعة', (tester) async {
    ThemeController.debugReset();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.mode,
      builder: (context, mode, _) => _app(
        mode,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(onPressed: () => maybeShowThemeChooser(context), child: const Text('start')),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('start'));
    await tester.pumpAndSettle();
    expect(find.text('اختاروا شكل التطبيق'), findsOneWidget);
    expect(find.text('متابعة'), findsOneWidget);
    // ليلي مختار من البداية
    final darkTile = find.ancestor(of: find.text('ليلي'), matching: find.byType(Material)).first;
    expect(tester.widget<Material>(darkTile).color, ModoColors.dark.brandSoft);

    await tester.tap(find.text('فاتح'));
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.text('متابعة'))).brightness, Brightness.light);
    expect(ThemeController.hasChoice, isFalse);

    await tester.tap(find.text('متابعة'));
    await tester.pumpAndSettle();
    expect(find.text('اختاروا شكل التطبيق'), findsNothing);
    expect(ThemeController.hasChoice, isTrue);
    expect(ThemeController.mode.value, ThemeMode.light);

    // ما تطلع مرة ثانية
    await tester.tap(find.text('start'));
    await tester.pumpAndSettle();
    expect(find.text('اختاروا شكل التطبيق'), findsNothing);
    expect(tester.takeException(), isNull);
    await ThemeController.choose(ThemeMode.dark);
  });
}
