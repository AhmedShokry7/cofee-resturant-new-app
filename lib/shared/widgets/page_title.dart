import 'package:material_ui/material_ui.dart';
import 'package:new_coffee/shared/widgets/design_text.dart';

import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/core/theme/tokens.dart';

class PageTitle extends StatelessWidget {
  const PageTitle({super.key, required this.title, this.page, this.label});

  final String title;
  final String? page;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: page != null && label != null
          ? DesignText(
              title,
              page: page!,
              label: label!,
              textAlign: TextAlign.center,
              style: AppFonts.semiBold20(context),
            )
          : Text(
              title,
              textAlign: TextAlign.center,
              style: AppFonts.semiBold20(context),
            ),
    );
  }
}
