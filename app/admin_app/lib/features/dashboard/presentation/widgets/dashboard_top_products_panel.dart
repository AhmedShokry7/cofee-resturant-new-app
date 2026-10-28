import 'package:flutter/material.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/features/dashboard/domain/entities/admin_dashboard_metrics.dart';
import 'package:admin_app/features/dashboard/domain/entities/admin_dashboard_top_product.dart';
import 'package:admin_app/features/dashboard/domain/entities/dashboard_insights.dart';
import 'package:admin_app/features/dashboard/presentation/widgets/dashboard_top_product_row.dart';
import 'package:admin_app/shared/widgets/admin_empty_state.dart';
import 'package:admin_app/shared/widgets/admin_section_link.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

/// الأكثر بيعًا خلال آخر سبعة أيام، بخمسة صفوف تضعها القاعدة.
///
/// العدد من أسطر الطلبات لا من المخزون: هذا ما بيع فعلًا. والاسم كما كُتب على
/// السطر وقت البيع، فيبقى منتج غيّر اسمه أو حُذف معروفًا في التقرير.
class DashboardTopProductsPanel extends StatelessWidget {
  const DashboardTopProductsPanel({
    super.key,
    required this.products,
    required this.metrics,
    required this.emptyMessage,
  });

  final List<AdminDashboardTopProduct> products;
  final AdminDashboardMetrics metrics;

  /// سبب الفراغ: لا سطر بيع في المدى، أو أن البحث لم يترك صفًّا.
  final String emptyMessage;

  @override
  Widget build(BuildContext context) => AdminSectionCard(
    title: S.dashboardBestSellersTitle,
    subtitle: S.dashboardBestSellersSubtitle,
    trailing: AdminSectionLink(
      destinationId: 'products',
      label: S.dashboardViewAllProducts,
      icon: AppIcons.arrowLeft01,
    ),
    // بلا شارة عدد: أرقام الصفوف نفسها تنتهي بعدّهم، فشارة «٥» فوق خمسة مزدحمة.
    child: products.isEmpty
        ? AdminEmptyState(icon: AppIcons.coffee01, message: emptyMessage)
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (index, product) in products.indexed)
                DashboardTopProductRow(
                  product: product,
                  rank: index + 1,
                  share: metrics.topProductShare(product),
                ),
            ],
          ),
  );
}
