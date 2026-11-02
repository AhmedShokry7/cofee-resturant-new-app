import 'package:flutter/material.dart';

import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/core/theme/tokens.dart';

class HomeSectionTitle extends StatelessWidget {
  const HomeSectionTitle({
    super.key,
    required this.title,
    this.trailing,
    this.titleStyle,
  });

  final String title;
  final Widget? trailing;

  /// The heading's own style. Sections share the row, not the size: the
  /// catalogue heading still reads one step heavier than the strips below it,
  /// and settling the scale is the page-by-page pass's job, not this row's.
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            style: titleStyle ?? AppFonts.semiBold16(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (trailing != null) ...[
          SizedBox(width: AppSpacing.sm),
          Flexible(child: trailing!),
        ],
      ],
    );
  }
}
