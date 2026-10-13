
import 'package:flutter/material.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';

class WelcomeViewTextTitle extends StatelessWidget {
  const WelcomeViewTextTitle({super.key});

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      textAlign: TextAlign.center,
      TextSpan(
        children: [
          TextSpan(
            text: "Your Coffee",
            style: AppFonts.bold24(
              context,
            ).copyWith(color: AppColor.primaryColor),
          ),
          const TextSpan(text: " "),
          TextSpan(
            text: "Your Moment, Your Way",
            style: AppFonts.semiBold24(context),
          ),
        ],
      ),
    );
  }
}
