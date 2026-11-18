import 'package:material_ui/material_ui.dart';

/// رموز التصميم والهوية البصرية الخاصة بالمحرر المرئي (Visual Editor Design Tokens).
///
/// صُممت لتقديم تجربة بصرية راقية وفاخرة بمستوى أدوات بناء التطبيقات الحديثة (SaaS App Builders)،
/// مع الحفاظ التام على ألوان تطبيق القهوة الدافئة والهادئة:
/// - خلفيات رئيسية: Warm Off-White
/// - أسطح البطاقات: Soft Cream
/// - اللون الأساسي: Deep Olive Green
/// - اللون الثانوي: Coffee Brown
/// - نصوص واضحة: Dark Charcoal و Muted Gray
/// - حدود ناعمة: Soft Warm Gray
class VisualEditorTokens {
  // --- ألوان الواجهة الفاتحة (Light Theme) ---
  static const Color bgWarmOffWhite = Color(0xFFFAF9F6);
  static const Color surfaceSoftCream = Color(0xFFFDFBF7);
  static const Color surfaceSoftCreamSecondary = Color(0xFFF6F2EB);
  static const Color canvasBg = Color(0xFFEFECE6);

  static const Color primaryOliveGreen = Color(0xFF2C4C38);
  static const Color primaryOliveGreenLight = Color(0xFFE8EFEA);
  static const Color secondaryCoffeeBrown = Color(0xFF6E473B);
  static const Color secondaryCoffeeLight = Color(0xFFF4ECE8);

  static const Color textDarkCharcoal = Color(0xFF1E2621);
  static const Color textMutedGray = Color(0xFF6E7972);
  static const Color textSubtle = Color(0xFF9AA49E);

  static const Color borderWarmGray = Color(0xFFE4DFD5);
  static const Color borderLight = Color(0xFFEFEBE4);
  static const Color borderFocus = Color(0xFF2C4C38);

  static const Color statusSuccess = Color(0xFF2E7D32);
  static const Color statusSuccessBg = Color(0xFFEDF7ED);
  static const Color statusWarning = Color(0xFFD97706);
  static const Color statusWarningBg = Color(0xFFFFFBEB);
  static const Color statusError = Color(0xFFDC2626);
  static const Color statusErrorBg = Color(0xFFFEF2F2);
  static const Color statusInfo = Color(0xFF2563EB);
  static const Color statusInfoBg = Color(0xFFEFF6FF);

  // --- ألوان الواجهة الداكنة (Dark Theme) ---
  static const Color darkBg = Color(0xFF151916);
  static const Color darkSurface = Color(0xFF1D231F);
  static const Color darkSurfaceSecondary = Color(0xFF262E29);
  static const Color darkCanvasBg = Color(0xFF121513);
  static const Color darkBorder = Color(0xFF323B35);
  static const Color darkText = Color(0xFFF0F4F1);
  static const Color darkTextMuted = Color(0xFFA1ACA4);

  // --- أدوات المساعدة للحصول على الألوان حسب السمة ---
  static Color bg(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkBg : bgWarmOffWhite;

  static Color surface(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkSurface
          : surfaceSoftCream;

  static Color surfaceSecondary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkSurfaceSecondary
          : surfaceSoftCreamSecondary;

  static Color canvas(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkCanvasBg : canvasBg;

  static Color border(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkBorder
          : borderWarmGray;

  static Color text(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkText
          : textDarkCharcoal;

  static Color textMuted(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkTextMuted
          : textMutedGray;

  // --- الظلال والأبعاد ---
  static const double topBarHeight = 60.0;
  static const double navRailWidth = 64.0;
  static const double sidePanelWidth = 290.0;
  static const double inspectorWidth = 320.0;

  static const double radiusSm = 6.0;
  static const double radiusMd = 10.0;
  static const double radiusLg = 14.0;
  static const double radiusXl = 20.0;

  static List<BoxShadow> softShadow(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: isDark
            ? Colors.black.withValues(alpha: 0.3)
            : const Color(0x0C2C4C38),
        blurRadius: 10,
        offset: const Offset(0, 3),
      ),
    ];
  }

  static List<BoxShadow> deviceElevation(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: isDark
            ? Colors.black.withValues(alpha: 0.5)
            : const Color(0x1F22332D),
        blurRadius: 28,
        spreadRadius: 2,
        offset: const Offset(0, 14),
      ),
      BoxShadow(
        color: isDark
            ? Colors.black.withValues(alpha: 0.3)
            : const Color(0x0D22332D),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ];
  }
}
