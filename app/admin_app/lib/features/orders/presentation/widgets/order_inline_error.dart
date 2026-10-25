import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';

class OrderInlineError extends StatelessWidget {
  const OrderInlineError({
    super.key,
    required this.message,
    required this.onRetry,
  });
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: AppDimensions.sm),
    padding: const EdgeInsets.symmetric(
      horizontal: AppDimensions.md,
      vertical: AppDimensions.sm,
    ),
    decoration: BoxDecoration(
      color: AppColor.errorColor.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
    ),
    child: Row(
      children: [
        const HugeIcon(
          icon: HugeIcons.strokeRoundedAlertCircle,
          size: 18,
          color: AppColor.errorColor,
        ),
        const SizedBox(width: AppDimensions.sm),
        Expanded(
          child: Text(message, style: Theme.of(context).textTheme.bodySmall),
        ),
        TextButton(onPressed: onRetry, child: Text(S.ordersRetry)),
      ],
    ),
  );
}
