import 'package:flutter/material.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/reviews/presentation/widgets/review_format.dart';

/// Five rating stars. A half value such as 4.6 fills four stars plus a half.
class ReviewStars extends StatelessWidget {
  const ReviewStars({
    super.key,
    required this.rating,
    this.size = 16,
    this.showValue = false,
  });

  final double rating;
  final double size;
  final bool showValue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: S.reviewsStarsCount(rating.round()),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var position = 1; position <= 5; position++) ...[
              Icon(
                _iconFor(position),
                size: size,
                color: AppColor.adminWarning,
              ),
              if (position < 5) SizedBox(width: size * .08),
            ],
            if (showValue) ...[
              SizedBox(width: size * .42),
              Text(
                reviewAverageValue(rating),
                textDirection: TextDirection.ltr,
                style: TextStyle(
                  color: theme.brightness == Brightness.dark
                      ? AppColor.darkText
                      : AppColor.adminAmount,
                  fontSize: size * .82,
                  fontWeight: AppFontWeights.bold,
                  height: AppTextHeights.line1_4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _iconFor(int position) {
    final value = rating - (position - 1);
    if (value >= .75) return Icons.star_rounded;
    if (value >= .25) return Icons.star_half_rounded;
    return Icons.star_outline_rounded;
  }
}
