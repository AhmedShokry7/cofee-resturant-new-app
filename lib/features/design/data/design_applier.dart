import 'package:flutter/widgets.dart';

import 'package:new_coffee/core/startup/preview_theme.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/features/design/data/model/published_design.dart';

/// يكتب طبقة الشكل المنشورة على رموز الألوان، ثم يعيد المعاينة فوقها.
///
/// الوظيفة استدعائية بحتة: كل دور يملكه الاستوديو يُكتب من جديد، الغائب بأصله.
/// طبعة تكتب سبعة أدوار تاركةً ما بقي على حاله تسرّب لونًا من مستند مُلغى إلى
/// شاشة تعمل من بعد، فيبقى الرجوع إلى الأصلي نصف رجوع.
///
/// الأدوار الثلاثة الباقية (النجاح والخطأ والتعطيل) يقرأها المستند ولا يكتب بها
/// شيئًا: لا موضع في ثيم العميل يقرّرّها اليوم، ووعد بلون لا يصل إلى الهاتف أصدق
/// من لوحة تُلوّن ما لا يراه الزبون.
///
/// آخر خطوة ثابتة: معاينة الرابط فوق المنشور، لأن «لا تلمس ما يُختبر الآن» قرار
/// سابق على أي نشر.
void applyPublishedTheme(PublishedTheme theme) {
  AppColor.primaryColor =
      theme.color(ThemeColorRole.primary) ?? AppColor.primaryDefault;
  AppColor.secondryColor =
      theme.color(ThemeColorRole.secondary) ?? AppColor.secondryDefault;
  AppColor.cardSurface =
      theme.color(ThemeColorRole.surface) ?? AppColor.cardSurfaceDefault;
  AppColor.background =
      theme.color(ThemeColorRole.background) ?? AppColor.backgroundDefault;
  AppColor.textPrimary =
      theme.color(ThemeColorRole.textPrimary) ?? AppColor.textPrimaryDefault;
  AppColor.textSecondary =
      theme.color(ThemeColorRole.textSecondary) ??
      AppColor.textSecondaryDefault;
  AppColor.borderColor =
      theme.color(ThemeColorRole.border) ?? AppColor.borderDefault;
  applyPreviewTheme();
}

/// يلفّ [child] بمضاعف الخط المنشور فوق مقياس الجهاز، ولا يلفّه وهو 1.
///
/// المضاعف على مقياس الجهاز لا بدلًا منه: زبون كبّر الخط من إعدادات النظام يحصل
/// على تكبيره ثم على مقياس الموظف فوقه. واللف مغزول عند 1 حتى لا ترى الشاشة
/// وسيطًا غيّر قياسًا لم يُطلب.
Widget applyDesignTextScale({
  required BuildContext context,
  required double factor,
  required Widget child,
}) {
  if (factor == 1) return child;
  final media = MediaQuery.maybeOf(context);
  if (media == null) return child;
  final device = media.textScaler.scale(1);
  return MediaQuery(
    data: media.copyWith(textScaler: TextScaler.linear(device * factor)),
    child: child,
  );
}
