import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';

/// شريط خطأ موحد يشرح سبب فشل عملية دون أن يقطع تدفق الصفحة.
class AdminErrorBanner extends StatelessWidget {
  const AdminErrorBanner({
    super.key,
    required this.message,
    required this.icon,
  });

  final String message;

  /// أيقونة HugeIcons من [AppIcons]، وتُعرض عبر [AppIcon] الموحد.
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.error;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: color.withValues(alpha: .35),
          width: AppDimensions.fieldBorderWidth,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIcon(icon, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
