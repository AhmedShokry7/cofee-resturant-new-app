import 'package:flutter/material.dart';

import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';
import 'package:new_coffee/core/theme/tokens.dart';

enum AuthMessageType { success, error, info }

class AuthMessageDialog extends StatelessWidget {
  const AuthMessageDialog({
    super.key,
    required this.type,
    required this.message,
    this.title,
    this.actionLabel,
    this.onAction,
  });

  final AuthMessageType type;
  final String message;
  final String? title;
  final String? actionLabel;
  final VoidCallback? onAction;

  static Future<void> show(
    BuildContext context, {
    required AuthMessageType type,
    required String message,
    String? title,
    String? actionLabel,
    VoidCallback? onAction,
    bool barrierDismissible = true,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (dialogContext) => AuthMessageDialog(
        type: type,
        message: message,
        title: title,
        actionLabel: actionLabel ?? S.ok,
        onAction: onAction,
      ),
    );
  }

  IconData get _icon {
    switch (type) {
      case AuthMessageType.success:
        return AppIcons.checkmarkCircle;
      case AuthMessageType.error:
        return AppIcons.alert;
      case AuthMessageType.info:
        return AppIcons.information;
    }
  }

  Color _color(BuildContext context) {
    switch (type) {
      case AuthMessageType.success:
        return AppColor.greenColor;
      case AuthMessageType.error:
        return AppColor.errorColor;
      case AuthMessageType.info:
        return AppColor.primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color(context);
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.r16),
      ),
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: AppSizes.px56,
              height: AppSizes.px56,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(_icon, size: AppSizes.px28, color: color),
            ),
            SizedBox(height: AppSpacing.md),
            if (title != null) ...[
              Text(
                title!,
                textAlign: TextAlign.center,
                style: AppFonts.semiBold16(context),
              ),
              SizedBox(height: AppSpacing.xs),
            ],
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppFonts.regular14(context),
            ),
            SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: CustomBtn(
                text: actionLabel ?? S.ok,
                onPressed: () {
                  Navigator.of(context).pop();
                  onAction?.call();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
