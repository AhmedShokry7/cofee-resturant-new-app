import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/constants/app_images.dart';
import 'package:admin_app/core/theme/app_theme.dart';

/// The theme switch shared by the app bar and the sign-in screen.
///
/// It shows the brand sun and moon artwork inside a circular outline and
/// simply switches between the light and the dark appearance. The brand
/// secondary tone is reserved for the dark appearance; light mode keeps the
/// primary accent.
class AdminThemeButton extends StatelessWidget {
  const AdminThemeButton({super.key});

  @override
  Widget build(BuildContext context) {
    final appTheme = AppTheme.instance;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = theme.brightness == Brightness.dark
        ? scheme.secondary
        : scheme.primary;

    return ListenableBuilder(
      listenable: appTheme,
      builder: (context, _) {
        final isDark = appTheme.mode == AppThemeMode.dark;

        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: accent),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => appTheme.setMode(
                isDark ? AppThemeMode.light : AppThemeMode.dark,
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Image.asset(
                  isDark ? AppImages.moon : AppImages.sun,
                  width: AppDimensions.iconSizeSm,
                  height: AppDimensions.iconSizeSm,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
