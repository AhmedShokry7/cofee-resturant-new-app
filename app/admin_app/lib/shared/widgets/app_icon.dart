import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';

/// أيقونة موحدة: اللون والحجم الافتراضيان من الثيم.
///
/// الاسم الدلالي يأتي من `AppIcons`، فلا تستورد أي شاشة حزمة الأيقونات.
class AppIcon extends StatelessWidget {
  const AppIcon(this.icon, {super.key, this.color, this.size});

  /// قيمة أيقونة من `AppIcons`.
  final IconData icon;

  final Color? color;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return HugeIcon(
      icon: icon,
      color: color ?? theme.iconTheme.color ?? theme.colorScheme.onSurface,
      size: size ?? AppDimensions.iconSizeSm,
    );
  }
}
