import 'package:flutter/material.dart';

import 'package:admin_app/core/config/app_config.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/constants/app_images.dart';
import 'package:admin_app/core/theme/typography.dart';

class StartupPage extends StatelessWidget {
  const StartupPage({super.key});

  static const String routeName = '/';

  @override
  Widget build(BuildContext context) {
    final configured = AppConfig.isSupabaseConfigured;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.pageHorizontalPadding,
            vertical: AppDimensions.pageVerticalPadding,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipOval(
                child: Image.asset(
                  AppImages.logo,
                  width: AppDimensions.logoMedium,
                  height: AppDimensions.logoMedium,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: AppDimensions.lg),
              Text(
                S.admin,
                style: Theme.of(context).textTheme.headlineMedium
                    ?.copyWith(fontWeight: AppFontWeights.bold),
              ),
              const SizedBox(height: AppDimensions.lg),
              if (!configured)
                Text(S.supabaseNotConfigured, textAlign: TextAlign.center)
              else
                const SizedBox(
                  width: AppDimensions.indicatorSize,
                  height: AppDimensions.indicatorSize,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
