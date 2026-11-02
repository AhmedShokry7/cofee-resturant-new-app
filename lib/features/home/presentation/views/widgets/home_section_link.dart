import 'package:flutter/material.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/core/theme/tokens.dart';

/// The underlined word at the end of a section heading.
///
/// "See all" and "View more" are the same kind of target with the same voice, so
/// they share one widget instead of restyling the text where each one sits. The
/// underlined word is the whole link, so it is the whole target: a bare gesture
/// over 12px of text is easy to miss and says nothing to a screen reader, which
/// would hear a heading and no action.
class HomeSectionLink extends StatelessWidget {
  const HomeSectionLink({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      link: true,
      label: label,
      child: Material(
        color: AppColor.transparent,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            // The floor every target in the app keeps, on a word that is only
            // 12px of text: the heading row gets the air, and the link gets a
            // thumb that lands.
            constraints: const BoxConstraints(
              minWidth: AppDimensions.tapTargetMin,
              minHeight: AppDimensions.tapTargetMin,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: AppSizes.px8,
              ),
              child: Text(
                label,
                style: AppFonts.medium12(context)
                    .copyWith(decoration: TextDecoration.underline),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
