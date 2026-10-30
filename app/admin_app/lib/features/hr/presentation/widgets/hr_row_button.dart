import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/shared/widgets/custom_btn.dart';
import 'package:flutter/material.dart';

/// زر قرار بمقاس صفّ الجدول: هو `CustomBtn` نفسه، لكن بارتفاع ومحايدة الصف.
///
/// أزرار القرار تظهر داخل سطر الجدول على الشاشة الواسعة لا في البطاقة وحدها،
/// ولو كان مقاسها الافتراضي (٥٢) لضاعف ارتفاع السطر وفُقدت فائدة الجدول.
class HrRowButton extends StatelessWidget {
  const HrRowButton({
    super.key,
    required this.text,
    this.onPressed,
    this.danger = false,
  });

  final String text;
  final VoidCallback? onPressed;

  /// للرفض والإلغاء: نفس اللفظ المحلي بلون الخطر لا بلون النجاح.
  final bool danger;

  @override
  Widget build(BuildContext context) => CustomBtn(
    text: text,
    onPressed: onPressed,
    variant: danger ? BtnVariant.destructive : BtnVariant.primary,
    height: AppSizes.px32,
    borderRadius: AppRadius.md,
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
    textStyle: AppFonts.semiBold12(context),
  );
}

/// صفّ أزرار القرار كما يليق بالسطر والبطاقة معًا: بلا فراغ حين لا قرار.
///
/// المكان الذي كان زرًّا يطبع سبب عدمه، فلا يُترك السطر عمودًا فارغًا يوحي أن
/// القرار معطّل عند الواجهة وهو محسوم في القاعدة.
Widget? hrActionsWrap(List<Widget> actions) {
  if (actions.isEmpty) return null;
  return Wrap(
    spacing: AppSpacing.sm,
    runSpacing: AppSpacing.sm,
    children: actions,
  );
}
