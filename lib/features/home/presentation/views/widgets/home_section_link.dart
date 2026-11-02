import 'package:flutter/material.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';

/// Bordered action link used at the end of home section headings.
class HomeSectionLink extends StatelessWidget {
  const HomeSectionLink({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      link: true,
      label: label,
      child: Material(
        color: AppColor.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 4,
              vertical: 3,
            ),
            decoration: BoxDecoration(
              border: Border.all(
                color: AppColor.greyColor,
                width: 1,
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              label,
              style: AppFonts.medium12(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}