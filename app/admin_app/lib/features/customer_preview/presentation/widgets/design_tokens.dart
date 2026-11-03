import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/theme/typography.dart';

/// أسماء التوكنات التي يحملها المستند، محوّلة إلى أرقام الشبكة نفسها.
///
/// المستند لا يخزّن رقمًا أبدًا: يخزّن `lg` وهذا يرجعه `AppSpacing.lg`. الرقم الحرّ
/// كان يصل إلى شاشة الزبون بمقياس لم تُقسَ عليه شاشة، وهو ما تمنعه لوحة الخصائص
/// أصلًا حين لا تعرض إلا الأسماء.
///
/// الاسم المجهول يرجع قيمة الشبكة المعتادة لا صفرًا: شجرة وصلت من قاعدة فيها
/// توكن لم يعد مسجَّلًا تبقى مقروءة أمام الموظف بدل أن تنطبق على بعضها.
abstract final class DesignTokens {
  DesignTokens._();

  static double spacing(String name) => switch (name) {
    'none' => AppSpacing.none,
    'xxs' => AppSpacing.xxs,
    'xs' => AppSpacing.xs,
    'sm' => AppSpacing.sm,
    'md' => AppSpacing.md,
    'xl' => AppSpacing.xl,
    'xxl' => AppSpacing.xxl,
    'xxxl' => AppSpacing.xxxl,
    _ => AppSpacing.lg,
  };

  static double radius(String name) => switch (name) {
    'none' => AppRadius.none,
    'xs' => AppRadius.xs,
    'sm' => AppRadius.sm,
    'md' => AppRadius.md,
    'lg' => AppRadius.lg,
    'xl' => AppRadius.xl,
    'xxl' => AppRadius.xxl,
    'pill' => AppRadius.pill,
    _ => AppRadius.md,
  };

  /// خط عنوان أو فقرة بالأحجام الأربعة المسجّلة في [DesignTokenChoices].
  static TextStyle text(BuildContext context, String size, {bool strong = false}) {
    if (strong) {
      return switch (size) {
        '12' => AppFonts.semiBold12(context),
        '14' => AppFonts.semiBold14(context),
        '18' => AppFonts.semiBold18(context),
        _ => AppFonts.semiBold16(context),
      };
    }
    return switch (size) {
      '12' => AppFonts.regular12(context),
      '14' => AppFonts.regular14(context),
      '18' => AppFonts.regular18(context),
      _ => AppFonts.regular16(context),
    };
  }
}
