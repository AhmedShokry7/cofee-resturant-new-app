import 'package:flutter/material.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';

/// The line under the headline, written by the copy in [S].
class WelcomeViewTextBody extends StatelessWidget {
  const WelcomeViewTextBody({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      textAlign: TextAlign.center,
      S.welcomeDescription,
      style: AppFonts.regular16(context).copyWith(color: AppColor.greyColor),
    );
  }
}
