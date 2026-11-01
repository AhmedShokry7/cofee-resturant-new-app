import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/layout_tokens.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/content/data/model/faq_model.dart';
import 'package:new_coffee/features/content/presentation/views/widgets/faq_card.dart';

/// The questions as a scrolling list under the section heading.
class FaqsList extends StatelessWidget {
  const FaqsList({super.key, required this.faqs});

  final List<FaqModel> faqs;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: LayoutTokens.pageBody(),
      children: [
        Text(S.faqTitle, style: AppFonts.semiBold16(context)),
        SizedBox(height: SpacingTokens.md.h),
        for (final faq in faqs) FaqCard(faq: faq),
      ],
    );
  }
}
