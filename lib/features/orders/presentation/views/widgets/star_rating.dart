import 'package:flutter/material.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/theme/tokens.dart';

class StarRating extends StatelessWidget {
  const StarRating({
    super.key,
    required this.rating,
    required this.onChanged,
    this.count = 5,
  });

  final int rating;
  final ValueChanged<int> onChanged;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final value = index + 1;
        final isActive = value <= rating;
        return Semantics(
          button: true,
          label: S.rateStars(value),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onChanged(value),
              customBorder: const CircleBorder(),
              // The glyph is 36 tall, so the hit box needs the rest of the
              // minimum before a thumb can be expected to land on it.
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSizes.px5,
                  vertical: AppSpacing.xs,
                ),
                child: Icon(
                  isActive ? AppIcons.star : AppIcons.starOff,
                  size: AppSizes.px36,
                  color: isActive
                      ? AppColor.primaryColor
                      : AppColor.borderColor,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
