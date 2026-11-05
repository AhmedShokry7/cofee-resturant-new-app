import 'package:flutter/material.dart';

import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/shared/widgets/selection_radio.dart';
import 'package:new_coffee/core/theme/tokens.dart';

/// Lets the customer pick the UI language. The choice is written through
/// [AppLocale.setLanguage], which persists it and notifies the whole app, so
/// every screen — including this one — re-renders in the new language and the
/// choice survives the next start.
///
/// The dialog says how to leave it without choosing: closing it by tapping
/// outside is not a promise a customer can see.
Future<void> showSettingsLanguageDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(S.language),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final language in AppLanguage.values)
            _LanguageOption(
              label: switch (language) {
                AppLanguage.arabic => S.arabicLanguage,
                AppLanguage.english => S.englishLanguage,
              },
              selected: AppLocale.instance.language == language,
              onTap: () {
                AppLocale.instance.setLanguage(language);
                Navigator.of(dialogContext).pop();
              },
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(S.cancel),
        ),
      ],
    ),
  );
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      checked: selected,
      child: Material(
        color: AppColor.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Row(
              children: [
                SelectionRadio(selected: selected),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(label, style: AppFonts.regular16(context)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
