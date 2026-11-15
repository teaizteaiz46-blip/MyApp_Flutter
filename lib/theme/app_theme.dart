import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// ألوان MODO الثابتة (البرتقالي نفسه بالوضعين).
/// ألوان الخلفيات والكروت والنصوص والحدود تجي من [ModoColors] (context.modo) حتى تتبدل ويه الوضع الليلي.
class AppColors {
  AppColors._();

  static const Color brand = Color(0xFFFF773D);
  static const Color brandDark = Color(0xFFE2581C);
  static const Color brandSoft = Color(0xFFFFEEE6);

  static const Color ink = Color(0xFF1E1B18);
  static const Color muted = Color(0xFF7C746D);
  static const Color line = Color(0xFFECE7E2);

  static const Color surface = Colors.white;
  static const Color background = Color(0xFFF6F5F3);
  static const Color placeholder = Color(0xFFF0ECE8);

  static const Color sale = Color(0xFFD6362B);
  static const Color success = Color(0xFF2E7D32);
  static const Color star = Color(0xFFF2A91D);
}

/// ألوان الواجهة حسب الوضع (فاتح/ليلي).
///
/// الفاتح = نفس الألوان الي جانت مكتوبة بالشاشات بالضبط (حتى الشكل الفاتح ما يتغير)،
/// والليلي: خلفية سوداء دافية، كروت رمادية غامقة، نص فاتح، والبرتقالي يبقى لون البراند.
@immutable
class ModoColors extends ThemeExtension<ModoColors> {
  const ModoColors({
    required this.isDark,
    required this.background,
    required this.page,
    required this.surface,
    required this.raised,
    required this.fill,
    required this.placeholder,
    required this.imageBg,
    required this.line,
    required this.border,
    required this.grey300,
    required this.ink,
    required this.textBody,
    required this.textSoft,
    required this.textHint,
    required this.textFaint,
    required this.muted,
    required this.grey,
    required this.grey700,
    required this.disabled,
    required this.strong,
    required this.onStrong,
    required this.brandSoft,
    required this.brandTint,
    required this.brandText,
    required this.sale,
    required this.success,
    required this.savings,
    required this.okBg,
    required this.okBorder,
    required this.greenSoft,
    required this.greenBorder,
    required this.greenText,
    required this.warnBg,
    required this.warnBorder,
    required this.warnText,
    required this.warnIcon,
    required this.hintBg,
    required this.hintBorder,
    required this.hintText,
    required this.gold,
    required this.goldSoft,
    required this.goldBorder,
    required this.pink,
    required this.pinkSoft,
    required this.pinkBorder,
  });

  final bool isDark;

  // --- الخلفيات
  /// خلفية الصفحات الرمادية الفاتحة (AppColors.background)
  final Color background;

  /// الصفحات والأشرطة البيضاء (الرئيسية، صفحة المنتج، الشريط العلوي)
  final Color page;

  /// الكروت والنوافذ والأشرطة السفلية
  final Color surface;

  /// شي أبيض فوق كارت أو مربع رمادي (زر مختار، عدّاد)
  final Color raised;

  /// الحقول والمربعات الرمادية داخل الكروت (البحث، الدردشة، كود الدعوة)
  final Color fill;

  /// مكان الصورة قبل ما تحمّل
  final Color placeholder;

  /// خلفية صور السلة والهدايا (Colors.grey[200])
  final Color imageBg;

  // --- الحدود
  final Color line;

  /// حدود رمادية (0xFFEEEEEE / Colors.grey.shade200)
  final Color border;

  /// حدود أغمق شوية (Colors.grey.shade300)
  final Color grey300;

  // --- النصوص
  final Color ink;

  /// 0xFF555555
  final Color textBody;

  /// 0xFF666666
  final Color textSoft;

  /// 0xFF888888
  final Color textHint;

  /// 0xFFAAAAAA (الأسعار المشطوبة)
  final Color textFaint;
  final Color muted;

  /// Colors.grey
  final Color grey;

  /// Colors.grey[700]
  final Color grey700;

  /// 0xFFCCCCCC (أزرار معطلة)
  final Color disabled;

  /// زر/مؤشر غامق بالفاتح (يصير فاتح بالليلي) والنص فوقه
  final Color strong;
  final Color onStrong;

  // --- البرتقالي
  final Color brandSoft;

  /// خلفية الاختيار البرتقالية الفاتحة (0xFFFFF1E8)
  final Color brandTint;

  /// نص برتقالي غامق (AppColors.brandDark كنص)
  final Color brandText;

  // --- الأحمر والأخضر
  /// نص أحمر (الخلفيات الحمرة تبقى AppColors.sale)
  final Color sale;
  final Color success;

  /// "وفّرت" (Colors.green.shade700)
  final Color savings;

  /// مربع أخضر (Colors.green.shade50 / shade200)
  final Color okBg;
  final Color okBorder;

  /// كوبون المكافأة والعروض (0xFFE8F5EC / 0xFFB5DEC1 / 0xFF1E7B3A)
  final Color greenSoft;
  final Color greenBorder;
  final Color greenText;

  // --- تنبيهات السلة البرتقالية (Colors.orange.shade50 ...)
  final Color warnBg;
  final Color warnBorder;
  final Color warnText;
  final Color warnIcon;

  // --- تلميح أسعار الجملة (0xFFFFF4EC)
  final Color hintBg;
  final Color hintBorder;
  final Color hintText;

  // --- النقاط (الذهبي)
  final Color gold;
  final Color goldSoft;
  final Color goldBorder;

  // --- الوردي (أسعار الكمية، الترتيب)
  final Color pink;
  final Color pinkSoft;
  final Color pinkBorder;

  /// لون لمكان واحد بس: الفاتح كما هو، والليلي البديل.
  Color pick(Color light, Color dark) => isDark ? dark : light;

  /// أيقونات شريط الحالة (فوق) وشريط التنقل (جوة)
  SystemUiOverlayStyle get overlay => isDark
      ? SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: const Color(0xFF121110),
          systemNavigationBarDividerColor: Colors.transparent,
        )
      : SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent);

  static const ModoColors light = ModoColors(
    isDark: false,
    background: Color(0xFFF6F5F3),
    page: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    raised: Color(0xFFFFFFFF),
    fill: Color(0xFFF6F5F3),
    placeholder: Color(0xFFF0ECE8),
    imageBg: Color(0xFFEEEEEE),
    line: Color(0xFFECE7E2),
    border: Color(0xFFEEEEEE),
    grey300: Color(0xFFE0E0E0),
    ink: Color(0xFF1E1B18),
    textBody: Color(0xFF555555),
    textSoft: Color(0xFF666666),
    textHint: Color(0xFF888888),
    textFaint: Color(0xFFAAAAAA),
    muted: Color(0xFF7C746D),
    grey: Color(0xFF9E9E9E),
    grey700: Color(0xFF616161),
    disabled: Color(0xFFCCCCCC),
    strong: Color(0xFF1E1B18),
    onStrong: Color(0xFFFFFFFF),
    brandSoft: Color(0xFFFFEEE6),
    brandTint: Color(0xFFFFF1E8),
    brandText: Color(0xFFE2581C),
    sale: Color(0xFFD6362B),
    success: Color(0xFF2E7D32),
    savings: Color(0xFF388E3C),
    okBg: Color(0xFFE8F5E9),
    okBorder: Color(0xFFA5D6A7),
    greenSoft: Color(0xFFE8F5EC),
    greenBorder: Color(0xFFB5DEC1),
    greenText: Color(0xFF1E7B3A),
    warnBg: Color(0xFFFFF3E0),
    warnBorder: Color(0xFFFFCC80),
    warnText: Color(0xFFD84315),
    warnIcon: Color(0xFFE64A19),
    hintBg: Color(0xFFFFF4EC),
    hintBorder: Color(0xFFF5B183),
    hintText: Color(0xFFB4501A),
    gold: Color(0xFF8A5A00),
    goldSoft: Color(0xFFFFF4D9),
    goldBorder: Color(0xFFF5DFA8),
    pink: Color(0xFFC2185B),
    pinkSoft: Color(0xFFFFF0F3),
    pinkBorder: Color(0xFFF8C8D6),
  );

  static const ModoColors dark = ModoColors(
    isDark: true,
    background: Color(0xFF121110),
    page: Color(0xFF121110),
    surface: Color(0xFF1E1C1A),
    raised: Color(0xFF2E2B28),
    fill: Color(0xFF262422),
    placeholder: Color(0xFF262422),
    imageBg: Color(0xFF262422),
    line: Color(0xFF33302C),
    border: Color(0xFF33302C),
    grey300: Color(0xFF3D3934),
    ink: Color(0xFFF2EFEA),
    textBody: Color(0xFFD3CCC3),
    textSoft: Color(0xFFBDB6AD),
    textHint: Color(0xFF9C968E),
    textFaint: Color(0xFF7F7972),
    muted: Color(0xFFA8A29A),
    grey: Color(0xFF9A948C),
    grey700: Color(0xFFC2BBB2),
    disabled: Color(0xFF4A4540),
    strong: Color(0xFFF2EFEA),
    onStrong: Color(0xFF121110),
    brandSoft: Color(0xFF3A2519),
    brandTint: Color(0xFF3B2417),
    brandText: Color(0xFFFF8A55),
    sale: Color(0xFFF05A4C),
    success: Color(0xFF66C984),
    savings: Color(0xFF6CCB86),
    okBg: Color(0xFF172A1D),
    okBorder: Color(0xFF2F5A3B),
    greenSoft: Color(0xFF172A1D),
    greenBorder: Color(0xFF2F5A3B),
    greenText: Color(0xFF6FD08C),
    warnBg: Color(0xFF2E2117),
    warnBorder: Color(0xFF6B4426),
    warnText: Color(0xFFFFAB80),
    warnIcon: Color(0xFFFF8A55),
    hintBg: Color(0xFF2E2117),
    hintBorder: Color(0xFF7A4A2E),
    hintText: Color(0xFFFFAD80),
    gold: Color(0xFFE9C46A),
    goldSoft: Color(0xFF2D2614),
    goldBorder: Color(0xFF5C4A1F),
    pink: Color(0xFFFF8AB4),
    pinkSoft: Color(0xFF3A1A27),
    pinkBorder: Color(0xFF6B2D45),
  );

  /// ألوان الثيم الحالي. إذا الثيم ما بيه الامتداد (مثلاً بالاختبارات) ناخذ حسب السطوع.
  static ModoColors of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<ModoColors>() ?? (theme.brightness == Brightness.dark ? dark : light);
  }

  /// الألوان ثابتة لكل وضع، فما نحتاج نبدل لون وحده.
  @override
  ModoColors copyWith() => this;

  @override
  ModoColors lerp(ModoColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return ModoColors(
      isDark: t < 0.5 ? isDark : other.isDark,
      background: l(background, other.background),
      page: l(page, other.page),
      surface: l(surface, other.surface),
      raised: l(raised, other.raised),
      fill: l(fill, other.fill),
      placeholder: l(placeholder, other.placeholder),
      imageBg: l(imageBg, other.imageBg),
      line: l(line, other.line),
      border: l(border, other.border),
      grey300: l(grey300, other.grey300),
      ink: l(ink, other.ink),
      textBody: l(textBody, other.textBody),
      textSoft: l(textSoft, other.textSoft),
      textHint: l(textHint, other.textHint),
      textFaint: l(textFaint, other.textFaint),
      muted: l(muted, other.muted),
      grey: l(grey, other.grey),
      grey700: l(grey700, other.grey700),
      disabled: l(disabled, other.disabled),
      strong: l(strong, other.strong),
      onStrong: l(onStrong, other.onStrong),
      brandSoft: l(brandSoft, other.brandSoft),
      brandTint: l(brandTint, other.brandTint),
      brandText: l(brandText, other.brandText),
      sale: l(sale, other.sale),
      success: l(success, other.success),
      savings: l(savings, other.savings),
      okBg: l(okBg, other.okBg),
      okBorder: l(okBorder, other.okBorder),
      greenSoft: l(greenSoft, other.greenSoft),
      greenBorder: l(greenBorder, other.greenBorder),
      greenText: l(greenText, other.greenText),
      warnBg: l(warnBg, other.warnBg),
      warnBorder: l(warnBorder, other.warnBorder),
      warnText: l(warnText, other.warnText),
      warnIcon: l(warnIcon, other.warnIcon),
      hintBg: l(hintBg, other.hintBg),
      hintBorder: l(hintBorder, other.hintBorder),
      hintText: l(hintText, other.hintText),
      gold: l(gold, other.gold),
      goldSoft: l(goldSoft, other.goldSoft),
      goldBorder: l(goldBorder, other.goldBorder),
      pink: l(pink, other.pink),
      pinkSoft: l(pinkSoft, other.pinkSoft),
      pinkBorder: l(pinkBorder, other.pinkBorder),
    );
  }
}

extension ModoThemeContext on BuildContext {
  /// ألوان MODO حسب الوضع الحالي (فاتح/ليلي)
  ModoColors get modo => ModoColors.of(this);
}

class AppTheme {
  AppTheme._();

  /// نفس ثيم التطبيق القديم بالضبط (كان داخل main.dart) + ألوان MODO الفاتحة.
  static final ThemeData light = ThemeData(
    primarySwatch: Colors.orange,
    scaffoldBackgroundColor: const Color(0xFFF5F5F5),
    fontFamily: 'Muli',
    appBarTheme: const AppBarTheme(
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.black),
      titleTextStyle: TextStyle(color: Colors.black, fontSize: 18),
    ),
    extensions: const [ModoColors.light],
  );

  /// الوضع الليلي: خلفية 0xFF121110، كروت 0xFF1E1C1A / 0xFF262422، نص 0xFFF2EFEA، ثانوي 0xFFA8A29A.
  static final ThemeData dark = _buildDark();

  static ThemeData _buildDark() {
    const m = ModoColors.dark;
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.brand,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFF4A2615),
      onPrimaryContainer: Color(0xFFFFDBCB),
      secondary: Color(0xFFFFB59A),
      onSecondary: Color(0xFF3B1A0A),
      secondaryContainer: Color(0xFF4A2615),
      onSecondaryContainer: Color(0xFFFFDBCB),
      tertiary: Color(0xFF6FD08C),
      onTertiary: Color(0xFF0D2414),
      error: Color(0xFFFF6B5E),
      onError: Color(0xFF2A0703),
      errorContainer: Color(0xFF5C1A14),
      onErrorContainer: Color(0xFFFFDAD5),
      surface: Color(0xFF121110),
      onSurface: Color(0xFFF2EFEA),
      onSurfaceVariant: Color(0xFFA8A29A),
      surfaceDim: Color(0xFF121110),
      surfaceBright: Color(0xFF3A3632),
      surfaceContainerLowest: Color(0xFF0D0C0B),
      surfaceContainerLow: Color(0xFF1E1C1A),
      surfaceContainer: Color(0xFF221F1D),
      surfaceContainerHigh: Color(0xFF262422),
      surfaceContainerHighest: Color(0xFF2E2B28),
      outline: Color(0xFF5A544D),
      outlineVariant: Color(0xFF33302C),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: Color(0xFFF2EFEA),
      onInverseSurface: Color(0xFF1E1C1A),
      inversePrimary: Color(0xFFB8501F),
      surfaceTint: Colors.transparent,
    );

    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: m.background,
      canvasColor: m.surface,
      cardColor: m.surface,
      dividerColor: m.line,
      fontFamily: 'Muli',
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: m.page,
        foregroundColor: m.ink,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: m.ink),
        titleTextStyle: TextStyle(color: m.ink, fontSize: 18),
      ),
      cardTheme: CardThemeData(color: m.surface, surfaceTintColor: Colors.transparent),
      dialogTheme: const DialogThemeData(backgroundColor: Color(0xFF262422), surfaceTintColor: Colors.transparent),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: m.surface,
        modalBackgroundColor: m.surface,
        surfaceTintColor: Colors.transparent,
      ),
      popupMenuTheme: const PopupMenuThemeData(color: Color(0xFF262422), surfaceTintColor: Colors.transparent),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF3A3632),
        contentTextStyle: TextStyle(color: m.ink, fontSize: 14),
        actionTextColor: m.brandText,
      ),
      dividerTheme: DividerThemeData(color: m.line),
      extensions: const [m],
    );
  }
}
