import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/constants/app_images.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/typography.dart';

/// اللوحة الجانبية الخضراء التي تعرّف بالعلامة على الشاشات الواسعة.
class LoginBrandPanel extends StatelessWidget {
  const LoginBrandPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onBrand = theme.colorScheme.onPrimary;
    final muted = onBrand.withValues(alpha: .72);

    return ColoredBox(
      color: theme.colorScheme.primary,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.huge),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipOval(
                child: Image.asset(
                  AppImages.logo,
                  width: AppDimensions.logoMedium * 2,
                  height: AppDimensions.logoMedium * 2,
                  fit: BoxFit.fill,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Text(
                S.appName,
                textAlign: TextAlign.center,
                style: AppFonts.bold36(context).copyWith(color: onBrand),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                S.brandTitle,
                textAlign: TextAlign.center,
                style: AppFonts.semiBold16(context).copyWith(color: onBrand),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                S.brandDescription,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
