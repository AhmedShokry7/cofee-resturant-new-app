import 'package:flutter/material.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/content/data/model/faq_model.dart';
import 'package:new_coffee/core/theme/tokens.dart';

/// One published question with its answer folded behind the chevron.
class FaqCard extends StatelessWidget {
  const FaqCard({super.key, required this.faq});

  final FaqModel faq;

  /// Leading for a paragraph the customer reads once, so the answer stays
  /// legible without eating the tile.
  static const double answerLineHeight = 1.5;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.md),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColor.cardSurface,
        borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
        border: Border.all(color: AppColor.borderColor),
      ),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        iconColor: AppColor.primaryColor,
        collapsedIconColor: AppColor.greyColor,
        title: Text(faq.question, style: AppFonts.medium16(context)),
        childrenPadding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        children: [
          Text(
            faq.answer,
            style: AppFonts.regular14(context)
                .copyWith(color: AppColor.greyColor, height: answerLineHeight),
          ),
        ],
      ),
    );
  }
}
