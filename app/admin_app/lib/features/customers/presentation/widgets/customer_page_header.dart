import 'package:flutter/material.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';

class CustomerPageHeader extends StatelessWidget {
  const CustomerPageHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.customers,
          textAlign: TextAlign.start,
          style: theme.textTheme.headlineMedium?.copyWith(
            color: dark ? AppColor.darkText : AppColor.adminHeading,
            fontSize: AppFontSizes.size23,
            fontWeight: AppFontWeights.bold,
            height: 1.5,
            letterSpacing: -0.4,
          ),
        ),
        Text(
          S.customersDescription,
          textAlign: TextAlign.start,
          style: theme.textTheme.bodySmall?.copyWith(
            color: dark ? AppColor.darkTextSecondary : AppColor.adminMuted,
            fontSize: AppFontSizes.size12_5,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
