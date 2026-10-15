import 'package:flutter/material.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';

class WelcomeViewTextBody extends StatelessWidget {
  const WelcomeViewTextBody({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      textAlign: TextAlign.center,
      "Discover your favorite coffee and make every moment a little more special, one cup at a time.",
      style: AppFonts.regular16(context).copyWith(color: AppColor.greyColor),
    );
  }
}
