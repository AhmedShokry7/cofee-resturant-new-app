import 'package:flutter/material.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/constants/app_images.dart';
import 'package:admin_app/core/theme/app_color.dart';

class LoginBrandPanel extends StatelessWidget {
  const LoginBrandPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColor.primaryColor,
      padding: const EdgeInsets.all(AppDimensions.xxxl),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipOval(
              child: Image.asset(
                AppImages.logo,
                width: AppDimensions.logoMedium,
                height: AppDimensions.logoMedium,
                fit: BoxFit.fill,
              ),
            ),
            const SizedBox(height: AppDimensions.xl),
            Text(
              S.appName,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: AppColor.whiteColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppDimensions.md),
            Text(
              S.brandTitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColor.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppDimensions.sm),
            Text(
              S.brandDescription,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: AppColor.white70),
            ),
          ],
        ),
      ),
    );
  }
}
