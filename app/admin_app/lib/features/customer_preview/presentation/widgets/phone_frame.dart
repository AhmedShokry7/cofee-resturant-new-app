import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/theme/app_color.dart';

/// جسم الهاتف الذي تُعرض داخله شاشة العميل.
///
/// العرض يُقاس من `AppDimensions.simulatorScreenWidth`، والارتفاع يُشتق منه
/// بنسبة شاشة العميل، فمقاس الهاتف يتغيّر من مكان واحد.
class PhoneFrame extends StatelessWidget {
  const PhoneFrame({
    super.key,
    required this.child,
    this.width = AppDimensions.simulatorScreenWidth,
  });

  final Widget child;
  final double width;

  /// سماكة الإطار حول الشاشة: الحشو زائد الحد.
  static const double bezel = AppSpacing.sm + AppSizes.px2;

  /// ارتفاع هاتف بعرض [width]: الشاشة نسبة إلى عرضها، والإطار يحيط بها.
  static double heightFor(double width) {
    final screenWidth = width - bezel * 2;
    return screenWidth * AppDimensions.simulatorScreenAspect + bezel * 2;
  }

  /// أكبر عرض هاتف يسع [maxWidth] و[maxHeight] معًا.
  ///
  /// لا يكبر الهاتف عن مقاسه الموثّق، بل يصغر فقط حين ضاقت المساحة، فتبقى
  /// الأرقام داخل الشاشة تلك التي يقيسها تطبيق العميل.
  static double widthFitting({
    required double maxWidth,
    required double maxHeight,
  }) {
    if (maxWidth <= 0 || maxHeight <= 0) {
      return AppDimensions.simulatorScreenWidth;
    }
    final screenWidth =
        (maxHeight - bezel * 2) / AppDimensions.simulatorScreenAspect;
    final byHeight = screenWidth + bezel * 2;
    if (byHeight < AppDimensions.simulatorScreenWidth) {
      return byHeight < maxWidth ? byHeight : maxWidth;
    }
    return maxWidth < AppDimensions.simulatorScreenWidth
        ? maxWidth
        : AppDimensions.simulatorScreenWidth;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: heightFor(width),
      decoration: BoxDecoration(
        color: AppColor.blackColor,
        borderRadius: BorderRadius.circular(AppRadius.phoneBody),
        border: Border.all(color: AppColor.borderColor, width: AppSizes.px2),
        boxShadow: const [
          BoxShadow(
            color: AppColor.black20,
            blurRadius: AppSizes.px24,
            offset: Offset(0, AppSizes.px12),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.phoneScreen),
        child: child,
      ),
    );
  }
}
