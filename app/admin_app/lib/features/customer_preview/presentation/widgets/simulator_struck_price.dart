import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/formatters.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/currency_icon.dart';

/// سعر مشطوب عليه، مع علامة الريال: الرقم وحده لا يقول وحدة المبلغ.
///
/// العميل يطبع السعر القديم بنفس بادئة السعر الجديد، واللوحة تعرضه بحرف العملة
/// نفسه، فلا يظهر مبلغ بغير وحدة في بطاقة.
class SimulatorStruckPrice extends StatelessWidget {
  const SimulatorStruckPrice({
    super.key,
    required this.value,
    this.fontSize = AppFontSizes.size12,
    this.iconSize = AppSizes.px12,
  });

  final double value;
  final double fontSize;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = adminMutedColor(theme);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            localizeDigits(formatAmount(value)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: muted,
              fontSize: fontSize,
              decoration: TextDecoration.lineThrough,
              height: AppTextHeights.line1_4,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        CurrencyIcon(size: iconSize, color: muted),
      ],
    );
  }
}
