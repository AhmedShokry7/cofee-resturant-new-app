import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';

/// One "Label: value" line, as the subscription pages list their figures.
class SubscriptionDetailRow extends StatelessWidget {
  const SubscriptionDetailRow({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: SpacingTokens.xs.h),
      child: Text('$label: $value', style: AppFonts.regular14(context)),
    );
  }
}
