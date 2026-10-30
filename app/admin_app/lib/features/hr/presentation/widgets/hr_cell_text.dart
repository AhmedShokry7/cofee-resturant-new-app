import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:flutter/material.dart';

/// نص خلية واحد لكل جداول HR: مقاس ثابت، ولون يميّز الاسم عن التفصيل.
///
/// الأعمدة تتجاور في سطر واحد، فالخلية لا تنكسر على أسطر: ما طال يُقطع بعلامة
/// حذف والقيمة الكاملة تُقرأ في البطاقة أو السطر التفصيلي.
class HrCellText extends StatelessWidget {
  const HrCellText(
    this.value, {
    super.key,
    this.muted = false,
    this.strong = false,
    this.danger = false,
  });

  final String value;

  /// للسياق الذي لا يقرر شيئًا: ملاحظة أو تاريخ ثانوي.
  final bool muted;

  /// لاسم السطر أو رقمه، وهو أول ما يُقرأ في العمود.
  final bool strong;

  /// للقيمة السالبة أو المتأخرة، بلون الخطأ لا بلون الحالة.
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = danger
        ? theme.colorScheme.error
        : strong
        ? adminHeadingColor(theme)
        : muted
        ? adminMutedColor(theme)
        : adminBodyColor(theme);
    return Text(
      // ما لم يُكتب في العمود يُقرأ «—» كما يُقرأ التاريخ الغائب، لا خلية
      // صامتة: الفارغ يسأل «فشل القراء أم لا شيء هناك؟» والشرطة تجيب.
      value.trim().isEmpty ? S.hrNoValue : value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: color,
        fontSize: AppFontSizes.size11_5,
        fontWeight: strong ? AppFontWeights.semiBold : AppFontWeights.regular,
        height: AppTextHeights.line1_5,
      ),
    );
  }
}
