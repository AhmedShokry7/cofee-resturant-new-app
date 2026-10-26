import 'package:flutter/material.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';

/// A quiet inline error with an optional retry action.
class AdminInlineError extends StatelessWidget {
  const AdminInlineError({
    super.key,
    required this.message,
    this.onRetry,
    this.retryLabel,
  });

  final String message;
  final VoidCallback? onRetry;
  final String? retryLabel;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: AppSpacing.sm),
    padding: const EdgeInsetsDirectional.fromSTEB(12, 6, 6, 6),
    decoration: BoxDecoration(
      color: AppColor.errorColor.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
    child: Row(
      children: [
        const AppIcon(AppIcons.alert, size: 18, color: AppColor.errorColor),
        const SizedBox(width: AppSizes.px8),
        Expanded(
          child: Text(
            message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        if (onRetry != null)
          TextButton(onPressed: onRetry, child: Text(retryLabel ?? S.tryAgain)),
      ],
    ),
  );
}
