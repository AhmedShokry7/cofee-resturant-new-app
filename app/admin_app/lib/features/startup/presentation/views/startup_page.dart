import 'package:flutter/material.dart';

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
          padding: const EdgeInsets.all(SpacingTokens.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColor.primaryColor,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.local_cafe,
                  color: Colors.white,
                  size: 34,
                ),
              ),
              const SizedBox(height: SpacingTokens.lg),
              Text(
                'Admin',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: SpacingTokens.lg),
              if (!configured)
                Text(
                  AppConfig.missingConfigurationMessage,
                  textAlign: TextAlign.center,
                )
              else
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
