import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:admin_app/core/config/app_config.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/spacing_tokens.dart';

class StartupPage extends StatelessWidget {
  const StartupPage({super.key});

  static const String routeName = '/';

  @override
  Widget build(BuildContext context) {
    final configured = AppConfig.isSupabaseConfigured;
    return Scaffold(
      backgroundColor: AppColor.whiteColor,
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(SpacingTokens.xl.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Admin',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              SizedBox(height: SpacingTokens.md.h),
              Text(
                configured
                    ? 'Supabase configuration detected.'
                    : AppConfig.missingConfigurationMessage,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
