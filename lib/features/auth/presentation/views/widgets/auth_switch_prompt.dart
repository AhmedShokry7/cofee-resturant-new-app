import 'package:flutter/material.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/tokens.dart';
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
          style: AppFonts.regular14(context)
              .copyWith(color: AppColor.blackColor),
        ),
        // The underlined word is the whole link, so it is the whole target:
        // a bare gesture over 14px of text is easy to miss and says nothing to
        // a screen reader, which hears two sentences with no action in them.
        Semantics(
          link: true,
          label: '$question $actionText',
          child: Material(
            color: AppColor.transparent,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: AppSizes.px8,
                ),
                child: Text(
                  actionText,
                  style: AppFonts.medium14(context).copyWith(
                    color: AppColor.primaryColor,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
