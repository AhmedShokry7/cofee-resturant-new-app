import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/navigation/admin_navigator.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';

/// رابط في زاوية بطاقة ينقل الأدمن إلى القسم الذي يعرضه كاملًا.
///
/// القسم يُختار بمعرّف عند القشرة لا بمسار، فيستعير الرابط اليد من
/// `AdminNavigator` بدل أن يخترع تنقّلًا. وخارج القشرة — في اختبار صفحة مفردة
/// مثلًا — لا يد تُستعار، فيختفي الرابط: زرٌّ لا يفتح شيئًا أسوأ من غيابه.
class AdminSectionLink extends StatelessWidget {
  const AdminSectionLink({
    super.key,
    required this.destinationId,
    required this.label,
    required this.icon,
  });

  /// معرّف `AdminDestination` المقصود، كما في قائمة الفروع.
  final String destinationId;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final select = AdminNavigator.maybeOf(context);
    if (select == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return TextButton(
      key: Key('admin-section-link-$destinationId'),
      onPressed: () => select(destinationId),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.px6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: AppColor.adminAccent,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: adminFlagForeground(theme, AppColor.adminAccent),
              fontSize: AppFontSizes.size11,
              fontWeight: AppFontWeights.semiBold,
              height: AppTextHeights.line1_4,
            ),
          ),
          const SizedBox(width: AppSizes.px4),
          AppIcon(
            icon,
            size: AppSizes.px16,
            color: adminFlagForeground(theme, AppColor.adminAccent),
          ),
        ],
      ),
    );
  }
}
