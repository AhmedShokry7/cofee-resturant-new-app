import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/layout_tokens.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/content/data/model/faq_model.dart';

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
      margin: EdgeInsets.only(bottom: SpacingTokens.md.h),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColor.whiteColor,
        borderRadius: BorderRadius.circular(LayoutTokens.cardRadius.r),
        border: Border.all(color: AppColor.borderColor),
      ),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        iconColor: AppColor.primaryColor,
        collapsedIconColor: AppColor.greyColor,
        title: Text(faq.question, style: AppFonts.medium16(context)),
        childrenPadding: EdgeInsets.fromLTRB(
          SpacingTokens.lg.w,
          0,
          SpacingTokens.lg.w,
          SpacingTokens.lg.h,
        ),
        children: [
          Text(
            faq.answer,
            style: AppFonts.regular14(
              context,
            ).copyWith(color: AppColor.greyColor, height: answerLineHeight),
          ),
        ],
      ),
    );
  }
}
