import 'package:material_ui/material_ui.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';

/// A compact, keyboard- and screen-reader-accessible help affordance for
/// settings whose effects need a little more context.
class AdminHelpButton extends StatelessWidget {
  const AdminHelpButton({
    super.key,
    required this.title,
    required this.message,
    this.iconSize = 17,
  });

  final String title;
  final String message;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: ValueKey('admin-help-$title'),
      tooltip: S.adminHelpTooltip,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(
        minWidth: AppSizes.px28,
        minHeight: AppSizes.px28,
      ),
      padding: EdgeInsets.zero,
      onPressed: () => showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(child: SelectableText(message)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(S.close),
            ),
          ],
        ),
      ),
      icon: AppIcon(AppIcons.helpCircle, size: iconSize),
    );
  }
}
