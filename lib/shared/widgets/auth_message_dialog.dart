import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';

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
        return HugeIcons.strokeRoundedCheckmarkCircle01;
      case AuthMessageType.error:
        return HugeIcons.strokeRoundedAlert02;
      case AuthMessageType.info:
        return HugeIcons.strokeRoundedInformationCircle;
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
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Padding(
        padding: EdgeInsets.all(SpacingTokens.lg.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56.w,
              height: 56.w,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(_icon, size: 28.w, color: color),
            ),
            SizedBox(height: SpacingTokens.md.h),
            if (title != null) ...[
              Text(
                title!,
                textAlign: TextAlign.center,
                style: AppFonts.semiBold16(context),
              ),
              SizedBox(height: SpacingTokens.xs.h),
            ],
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppFonts.regular14(context),
            ),
            SizedBox(height: SpacingTokens.md.h),
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
