import 'package:flutter/material.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/utils/localized_date.dart';
import 'package:admin_app/features/dashboard/presentation/widgets/dashboard_header_actions.dart';
import 'package:admin_app/shared/widgets/admin_page_header.dart';

/// ترويسة اللوحة: من يقرأها وأي يوم اليوم، مع يدٍ واحدة تبدأ العمل.
///
/// الترحيب عنوان الصفحة لا بطاقة: الاسم يطبعه الشريط الجانبي فعلًا، فسطران
/// هنا يكفيان. والتحية تعرف الساعة لأن «صباح الخير» تُقرأ مساءً كذبًا صغيرًا،
/// والتاريخ من `localizedDate` وحده فلا تنسخ اللوحة تقويمًا ثانيًا.
class DashboardHeader extends StatelessWidget {
  const DashboardHeader({
    super.key,
    required this.staffName,
    required this.refreshing,
    required this.canAddProduct,
    required this.onRefresh,
  });

  final String staffName;
  final bool refreshing;
  final bool canAddProduct;
  final VoidCallback onRefresh;

  /// التحية باسم أول الكلمة: الاسم يصل كاملًا من الحساب، والمطلع يكتفي بما
  /// يُنادى به فعلًا. وبلا اسم تُترك التحية مبهمة بدل نقطة انتظار فارغة.
  String get _greeting {
    final name = staffName.trim().split(RegExp(r'\s+')).first;
    if (name.isEmpty) return S.dashboardGreeting;
    return (DateTime.now().hour < 12
        ? S.dashboardMorningGreeting
        : S.dashboardEveningGreeting)(name);
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageHeader(
      title: _greeting,
      subtitle: S.dashboardGreetingCaption(localizedDate(DateTime.now())),
      actions: [
        DashboardAddProductButton(canAdd: canAddProduct),
        DashboardRefreshButton(refreshing: refreshing, onRefresh: onRefresh),
      ],
    );
  }
}
