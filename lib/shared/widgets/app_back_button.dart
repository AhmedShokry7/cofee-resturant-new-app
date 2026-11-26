import 'package:material_ui/material_ui.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/shared/utils/direction_aware_icons.dart';
import 'package:new_coffee/shared/widgets/app_icon.dart';

/// The one back button for app bars. Uses the app's own back glyph (not
/// Material's default arrow), so every page that pops looks the same.
class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Navigator.of(context).canPop()) return const SizedBox.shrink();
    return IconButton(
      tooltip: S.back,
      onPressed: () => Navigator.of(context).maybePop(),
      icon: AppIcon(DirectionAwareIcons.back(context)),
    );
  }
}
