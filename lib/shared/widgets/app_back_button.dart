import 'package:material_ui/material_ui.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/theme/tokens.dart';
import 'package:new_coffee/shared/widgets/app_icon.dart';

/// The one back button for app bars: a transparent circle with a hairline
/// border in the design-system border colour and the back glyph centred in it.
///
/// The visible circle is [AppSizes.px40] wide; the tap area is the larger
/// [AppDimensions.tapTargetMin] square around it, so the circle itself never
/// grows to meet the touch floor.
class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key, this.onPressed});

  /// Overrides the default pop, for headers that own their back action.
  /// When set, the button is always shown.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    if (onPressed == null && !Navigator.of(context).canPop()) {
      return const SizedBox.shrink();
    }
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Tooltip(
      message: S.back,
      child: Semantics(
        button: true,
        label: S.back,
        child: SizedBox(
          width: AppDimensions.tapTargetMin,
          height: AppDimensions.tapTargetMin,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed ?? () => Navigator.of(context).maybePop(),
              child: Center(
                child: Container(
                  width: AppSizes.px40,
                  height: AppSizes.px40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColor.borderColor,
                      width: AppSizes.px1,
                    ),
                  ),
                  child: AppIcon(
                    rtl ? AppIcons.forwardLine : AppIcons.backLine,
                    color: AppColor.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
