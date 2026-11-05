import 'package:flutter/material.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/shared/utils/direction_aware_icons.dart';
import 'package:new_coffee/shared/widgets/app_icon.dart';
import 'package:new_coffee/core/theme/tokens.dart';

class ProfileMenuTile extends StatelessWidget {
  const ProfileMenuTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.opensPage = true,
  });

  final IconData icon;
  final String label;

  /// Secondary line under [label], e.g. the currently selected value.
  final String? subtitle;
  final VoidCallback onTap;

  /// True when the tap pushes a screen, false when it opens a sheet or a
  /// dialog. The chevron means "there is a page behind this", so it must not
  /// promise one for a control that closes again on the same screen.
  final bool opensPage;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Semantics(
          button: true,
          // The label is announced once, from here, so the row's own text is
          // kept out of the reading and a screen reader says the destination
          // and "button" rather than the glyph and the chevron.
          label: subtitle == null ? label : '$label. ${subtitle!}',
          child: Material(
            color: AppColor.transparent,
            child: InkWell(
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: AppDimensions.tapTargetMin,
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  child: Row(
                    children: [
                      AppIcon(
                        icon,
                        size: AppIconSize.xxl,
                        color: AppColor.primaryColor,
                      ),
                      SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ExcludeSemantics(
                              child: Text(
                                label,
                                style: AppFonts.regular16(context),
                              ),
                            ),
                            if (subtitle != null) ...[
                              SizedBox(height: AppSpacing.xxs),
                              ExcludeSemantics(
                                child: Text(
                                  subtitle!,
                                  style: AppFonts.regular12(context)
                                      .copyWith(color: AppColor.greyColor),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (opensPage)
                        ExcludeSemantics(
                          child: AppIcon(
                            DirectionAwareIcons.forward(context),
                            muted: true,
                            size: AppSizes.px20,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}
