import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/dashboard/domain/entities/admin_dashboard_top_product.dart';
import 'package:admin_app/features/dashboard/presentation/utils/dashboard_display.dart';
import 'package:admin_app/features/dashboard/presentation/widgets/dashboard_top_product_figure.dart';
import 'package:admin_app/shared/widgets/admin_network_thumb.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

/// صف منتج الأكثر مبيعًا: رتبته، صورته كما بيعت، اسمه وحدّته، ثم ماله وحصّته.
///
/// الصورة سنابوت السطر وقت البيع لا صورة الكتالوج اليوم: منتج غيّر صورته أو
/// حُذف يبقى معروفًا بما بيع به. والحصّة رقمٌ لا شريط، لأن ترتيب الصفوف نفسه
/// يقول أيها أكثر.
class DashboardTopProductRow extends StatelessWidget {
  const DashboardTopProductRow({
    super.key,
    required this.product,
    required this.rank,
    required this.share,
  });

  final AdminDashboardTopProduct product;
  final int rank;

  /// حصة المنتج من إيراد الأسبوع، من `topProductShare`.
  final double share;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.px10),
      decoration: BoxDecoration(
        border: rank == 1
            ? null
            : Border(top: BorderSide(color: adminRowBorderColor(theme))),
      ),
      child: Row(
        children: [
          Text(
            localizeDigits(rank.toString().padLeft(2, '0')),
            style: TextStyle(
              color: adminSubtleColor(theme),
              fontSize: AppFontSizes.size9,
              height: AppTextHeights.line1_5,
            ),
          ),
          const SizedBox(width: AppSizes.px10),
          AdminNetworkThumb(
            imageUrl: product.imageUrl,
            size: AppSizes.px36,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          const SizedBox(width: AppSizes.px10),
          Expanded(child: _identity(theme)),
          const SizedBox(width: AppSpacing.md),
          DashboardTopProductFigure(revenue: product.revenue, share: share),
        ],
      ),
    );
  }

  Widget _identity(ThemeData theme) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        dashboardProductName(product),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: adminBodyColor(theme),
          fontSize: AppFontSizes.size9,
          fontWeight: AppFontWeights.bold,
          height: AppTextHeights.line1_5,
        ),
      ),
      Text(
        localizeDigits(S.dashboardPiecesSold(product.quantity)),
        style: TextStyle(
          color: adminMutedColor(theme),
          fontSize: AppFontSizes.size8,
          height: AppTextHeights.line1_5,
        ),
      ),
    ],
  );
}
