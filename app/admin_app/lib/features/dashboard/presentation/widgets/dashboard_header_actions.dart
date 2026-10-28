import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/navigation/admin_navigator.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';

/// زر العمل الأخضر في زاوية ترويسة اللوحة.
///
/// يذهب إلى قسم المنتجات حيث يُضاف المنتج فعلًا، لا يفتح نافذة من اللوحة:
/// القشرة تملك قائمة الأقسام، فاللوحة تعير يدها `AdminNavigator` بدل أن
/// تخترع مسارًا. وخارج القشرة لا يد تُستعار، فيختفي الزر — زرٌّ لا يفتح
/// شيئًا أسوأ من غيابه.
class DashboardAddProductButton extends StatelessWidget {
  const DashboardAddProductButton({super.key});

  @override
  Widget build(BuildContext context) {
    final select = AdminNavigator.maybeOf(context);
    if (select == null) return const SizedBox.shrink();
    return FilledButton.icon(
      key: const Key('dashboard-add-product'),
      onPressed: () => select('products'),
      style: FilledButton.styleFrom(
        backgroundColor: AppColor.adminAccent,
        foregroundColor: AppColor.whiteColor,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.px16,
          vertical: AppSizes.px10,
        ),
      ),
      icon: const AppIcon(AppIcons.add01, size: AppSizes.px16),
      label: Text(S.addProduct),
    );
  }
}

/// إعادة قراءة اللوحة، بأيقونة لا بزرٍّ ممتلئ.
///
/// التحديث فعلٌ ثانوي واحد، فلا يستحق أن ينافس أرقام اللوحة على النظر؛ ودوّارة
/// الاستبدال تخبر أن القراءة جارية بدل أن تُعطَّل اليد بلا خبر.
class DashboardRefreshButton extends StatelessWidget {
  const DashboardRefreshButton({
    super.key,
    required this.refreshing,
    required this.onRefresh,
  });

  final bool refreshing;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IconButton(
      key: const Key('dashboard-refresh'),
      tooltip: S.refresh,
      onPressed: refreshing ? null : onRefresh,
      style: IconButton.styleFrom(
        fixedSize: const Size(AppSizes.px36, AppSizes.px36),
        backgroundColor: adminTintedSurfaceColor(theme),
      ),
      icon: refreshing
          ? const SizedBox(
              width: AppSizes.px16,
              height: AppSizes.px16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : AppIcon(
              AppIcons.refresh,
              size: AppSizes.px18,
              color: adminBodyColor(theme),
            ),
    );
  }
}
