import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_toxens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/profile/data/faqs_list.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  static const routeName = "helpRoute";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Help")),
      body: ListView(
        padding: EdgeInsets.all(SpacingTokens.lg.w),
        children: [
          Text("Frequently asked questions", style: AppFonts.semiBold16(context)),
          SizedBox(height: SpacingTokens.md.h),
          ...getFaqsList().map(
            (faq) => Container(
              margin: EdgeInsets.only(bottom: SpacingTokens.md.h),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColor.whiteColor,
                borderRadius: BorderRadius.circular(12.r),
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
                    style: AppFonts.regular14(context).copyWith(
                      color: AppColor.greyColor,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
