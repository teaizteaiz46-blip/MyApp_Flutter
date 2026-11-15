import 'package:flutter/material.dart';

import '../../services/deep_link_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_controller.dart';

const _options = [
  (ThemeMode.dark, Icons.dark_mode_rounded, 'خلفية داكنة، مريحة للعين بالليل'),
  (ThemeMode.light, Icons.light_mode_rounded, 'خلفية فاتحة وبيضاء'),
  (ThemeMode.system, Icons.brightness_auto_rounded, 'يصير ليلي أو فاتح حسب موبايلكم'),
];

/// الخيارات الثلاثة (ليلي / فاتح / حسب إعداد الموبايل): بشاشة أول فتحة وبنافذة "المظهر".
class AppearanceOptions extends StatelessWidget {
  const AppearanceOptions({super.key, required this.value, required this.onChanged});

  final ThemeMode value;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final m = context.modo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (mode, icon, sub) in _options)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: mode == value ? m.brandSoft : m.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: mode == value ? AppColors.brand : m.line, width: mode == value ? 1.6 : 1),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => onChanged(mode),
                child: Semantics(
                  selected: mode == value,
                  button: true,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: m.fill, shape: BoxShape.circle),
                          child: Icon(icon, size: 22, color: mode == value ? AppColors.brand : m.muted),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(ThemeController.label(mode),
                                  style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: m.ink)),
                              Text(sub, style: TextStyle(fontSize: 12.5, color: m.muted)),
                            ],
                          ),
                        ),
                        Icon(
                          mode == value ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                          color: mode == value ? AppColors.brand : m.muted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// شاشة "اختاروا شكل التطبيق": تطلع مرة وحدة بأول فتحة (بعد إعلان الافتتاح)، و"ليلي" مختار.
class ThemeChooserScreen extends StatefulWidget {
  const ThemeChooserScreen({super.key, required this.onDone});

  final ValueChanged<ThemeMode> onDone;

  @override
  State<ThemeChooserScreen> createState() => _ThemeChooserScreenState();
}

class _ThemeChooserScreenState extends State<ThemeChooserScreen> {
  ThemeMode _mode = ThemeMode.dark;

  void _select(ThemeMode mode) {
    setState(() => _mode = mode);
    // نعاين الشكل فوراً، وينحفظ بـ "متابعة"
    ThemeController.preview(mode);
  }

  @override
  Widget build(BuildContext context) {
    final m = context.modo;
    return PopScope(
      canPop: false,
      // زر الرجوع = متابعة بالاختيار الحالي
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) widget.onDone(_mode);
      },
      child: Scaffold(
        backgroundColor: m.page,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: box.maxHeight - 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'MODO',
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.ltr,
                      style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: AppColors.brand, letterSpacing: 3),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'اختاروا شكل التطبيق',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: m.ink),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'تگدرون تغيّرونه بأي وقت من حسابي ← المظهر',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13.5, color: m.muted, height: 1.5),
                    ),
                    const SizedBox(height: 24),
                    AppearanceOptions(value: _mode, onChanged: _select),
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: () => widget.onDone(_mode),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(54),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('متابعة', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// يطلع شاشة اختيار المظهر إذا الزبون بعده ما اختار.
/// ما تطلع إذا التطبيق انفتح من رابط أو إشعار (تتأجل للفتحة الجاية)، وتتسكر بدون حفظ إذا وصل رابط وهي ظاهرة.
/// يرجع false بس إذا انقطعت بفتح من برا وهي ظاهرة (فما نطلع فوق المنتج كوبون الترحيب، يطلع بالفتحة الجاية).
Future<bool> maybeShowThemeChooser(BuildContext context) async {
  if (ThemeController.hasChoice) return true;
  if (DeepLinkService.openedFromLink) return true;
  final route0 = ModalRoute.of(context);
  if (route0 != null && !route0.isCurrent) return true;

  final navigator = Navigator.of(context, rootNavigator: true);
  var interrupted = false;
  late final PageRouteBuilder<ThemeMode> route;

  void close() {
    interrupted = true;
    if (route.isActive) route.navigator?.removeRoute(route);
  }

  route = PageRouteBuilder<ThemeMode>(
    opaque: true,
    transitionDuration: const Duration(milliseconds: 250),
    reverseTransitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (context, _, _) => ThemeChooserScreen(onDone: (mode) => Navigator.of(context).pop(mode)),
    transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
  );

  // رابط/إشعار وصل والشاشة ظاهرة: نسكرها (نفس إعلان الافتتاح)
  final previous = DeepLinkService.onExternalOpen;
  DeepLinkService.onExternalOpen = () {
    previous?.call();
    close();
  };
  final chosen = await navigator.push(route);
  DeepLinkService.onExternalOpen = previous;

  if (chosen != null) {
    await ThemeController.choose(chosen);
    return true;
  }
  // انقطعت: نرجع للشكل الافتراضي وتطلع مرة ثانية بالفتحة الجاية
  await ThemeController.revert();
  return !interrupted;
}

/// نافذة "المظهر" من حسابي: التطبيق يتبدل فوراً ويه الاختيار.
Future<void> showAppearanceSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    // الخلفية ترسمها النافذة نفسها حتى تتبدل وياها لما يتغير الوضع وهي مفتوحة
    backgroundColor: Colors.transparent,
    elevation: 0,
    builder: (sheet) => ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.mode,
      builder: (context, mode, _) {
        final m = context.modo;
        return Container(
          decoration: BoxDecoration(
            color: m.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 32,
                      height: 4,
                      decoration: BoxDecoration(color: m.muted.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text('المظهر',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: m.ink)),
                  const SizedBox(height: 14),
                  AppearanceOptions(value: mode, onChanged: ThemeController.choose),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

/// سطر "المظهر" بصفحة الحساب
class AppearanceTile extends StatelessWidget {
  const AppearanceTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: ThemeController.mode,
        builder: (context, mode, _) => ListTile(
          leading: Icon(mode == ThemeMode.light ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
          title: const Text('المظهر'),
          subtitle: Text(ThemeController.label(mode)),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () => showAppearanceSheet(context),
        ),
      ),
    );
  }
}
