import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:flutter/material.dart';

import 'package:admin_app/core/locale/app_locale.dart';

/// The language switch shared by the app bar and the sign-in screen.
///
/// The brand secondary tone is reserved for the dark appearance; light mode
/// keeps the primary accent so the control stays readable on white.
class AdminLanguageButton extends StatelessWidget {
  const AdminLanguageButton({super.key, this.icon = AppIcons.translate});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final locale = AppLocale.instance;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = theme.brightness == Brightness.dark
        ? scheme.secondary
        : scheme.primary;

    return ListenableBuilder(
      listenable: locale,
      builder: (context, _) {
        return ActionChip(
          avatar: Icon(icon, size: 18, color: accent),
          side: BorderSide(color: AppColor.adminAccentSurface),
          label: Text(
            locale.isArabic ? 'EN' : 'عربي',
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(color: accent),
          ),
          onPressed: locale.toggle,
        );
      },
    );
  }
}
