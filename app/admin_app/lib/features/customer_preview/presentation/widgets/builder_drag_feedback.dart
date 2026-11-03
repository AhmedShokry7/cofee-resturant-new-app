import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';

/// البطاقة التي تُرافق الإصبع أثناء السحب: اسم العنصر وحده على سطح اللوحة.
///
/// لا نسخة من رسم العنصر هنا: السحب يُنبئ بما سيُضاف، والرسم كاملًا يبقى في
/// اللوحة حتى لا يُبنى شريط منتجات مرتين في نفس الإطار.
class BuilderDragFeedback extends StatelessWidget {
  const BuilderDragFeedback({super.key, required this.label});

  final String label;

  static const double _maxWidth = 220.0;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        constraints: const BoxConstraints(maxWidth: _maxWidth),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppColor.adminAccent,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          boxShadow: const [
            BoxShadow(
              color: AppColor.black20,
              blurRadius: AppSizes.px12,
              offset: Offset(0, AppSizes.px4),
            ),
          ],
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColor.whiteColor,
            fontSize: AppFontSizes.size11,
            fontWeight: AppFontWeights.semiBold,
            height: AppTextHeights.line1_4,
          ),
        ),
      ),
    );
  }
}
