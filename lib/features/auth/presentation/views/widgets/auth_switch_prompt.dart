import 'package:flutter/material.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';

class AuthSwitchPrompt extends StatelessWidget {
  const AuthSwitchPrompt({
    super.key,
    required this.question,
    required this.actionText,
    required this.onTap,
  });

  final String question;
  final String actionText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          question,
          style: AppFonts.regular14(context).copyWith(color: AppColor.blackColor),
        ),
        GestureDetector(
          onTap: onTap,
          child: Text(
            actionText,
            style: AppFonts.medium14(context).copyWith(
              color: AppColor.primaryColor,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }
}
