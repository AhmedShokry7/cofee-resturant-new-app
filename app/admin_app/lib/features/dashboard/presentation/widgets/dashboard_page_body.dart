import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/features/dashboard/presentation/manager/admin_dashboard_state.dart';
import 'package:admin_app/features/dashboard/presentation/utils/dashboard_visible_rows.dart';
import 'package:admin_app/features/dashboard/presentation/widgets/dashboard_board_panels.dart';
import 'package:admin_app/features/dashboard/presentation/widgets/dashboard_header.dart';
import 'package:admin_app/shared/widgets/admin_inline_error.dart';
import 'package:admin_app/shared/widgets/admin_page_frame.dart';

/// تركيب لوحة التحكم: ترويسة، ثم إنذار القراءة الفاشلة، ثم اللوحات.
///
/// الصفحة تبني ولا تحسب: كل رقم يصل كما جمعته القاعدة، وكل نسبة تأتي من
/// `DashboardInsights`، والبحث يمرّ من `DashboardVisibleRows`. ترتيب اللوحات
/// وظهورها التدريجي مكانهما `DashboardBoardPanels`.
class DashboardPageBody extends StatelessWidget {
  const DashboardPageBody({
    super.key,
    required this.state,
    required this.staffName,
    required this.canManageTarget,
    required this.canAddProduct,
    required this.onRefresh,
    required this.onRangeChanged,
    required this.onEditTarget,
  });

  final AdminDashboardState state;
  final String staffName;
  final bool canManageTarget;
  final bool canAddProduct;
  final VoidCallback onRefresh;
  final ValueChanged<int> onRangeChanged;
  final VoidCallback onEditTarget;

  @override
  Widget build(BuildContext context) {
    return AdminPageFrame(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DashboardHeader(
              staffName: staffName,
              refreshing: state.isLoading,
              canAddProduct: canAddProduct,
              onRefresh: onRefresh,
            ),
            if (state.errorMessage != null) ...[
              const SizedBox(height: AppSizes.px8),
              // الأرقام بقيت على الشاشة والإنذار فوقها: قراءة فاشلة واحدة
              // لا تمحو ما قرئ قبلها، لكنها لا تُترك بلا خبر.
              AdminInlineError(
                message: state.errorMessage!,
                onRetry: onRefresh,
              ),
            ],
            const SizedBox(height: AppSizes.px14),
            DashboardBoardPanels(
              state: state,
              rows: DashboardVisibleRows(state.metrics, state.query),
              canManageTarget: canManageTarget,
              onRangeChanged: onRangeChanged,
              onEditTarget: onEditTarget,
            ),
          ],
        ),
      ),
    );
  }
}
