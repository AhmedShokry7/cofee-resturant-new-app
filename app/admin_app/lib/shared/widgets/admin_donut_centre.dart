import 'package:flutter/material.dart';

import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

/// الرقم وتسميته في فتحة الدونات.
///
/// المركز يُركَّب فوق الحلقة لا داخلها: النسب تُقرأ من الزوايا، والرقم وحده
/// يقول «من أي مجموع» — والتسمية تجيب عن سؤال «مجموع ماذا؟» قبل أن يظنّ
/// القارئ أن الرقم مالٌ وهو عدد طلبات.
class AdminDonutCentre extends StatelessWidget {
  const AdminDonutCentre({super.key, required this.value, this.label});

  /// الرقم المطبوع في الوسط، جاهزًا للنص كما اختارته الصفحة.
  final String value;

  /// معناه تحت الرقم، ويُسقط السطر كله حين لا معنى مُرسل.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          maxLines: 1,
          style: TextStyle(
            color: adminHeadingColor(theme),
            fontSize: AppFontSizes.size18,
            fontWeight: AppFontWeights.semiBold,
            height: AppTextHeights.line1_2,
          ),
        ),
        if (label != null)
          Text(
            label!,
            maxLines: 1,
            style: TextStyle(
              color: adminMutedColor(theme),
              fontSize: AppFontSizes.size9,
              height: AppTextHeights.line1_3,
            ),
          ),
      ],
    );
  }
}
