import 'package:flutter/material.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/dashboard/presentation/manager/admin_dashboard_cubit.dart';
import 'package:admin_app/features/dashboard/presentation/widgets/dashboard_target_dialog.dart';

/// يفتح حوار هدف الشهر ويعيد `true` حين تكون القاعدة هي التي كتبت الرقم.
///
/// النجاح هنا ليس «الزر اشتغل» بل «السطر انكتب»: الحوار لا يُغلق إلا بعد أن
/// ترجع الكتابة بلا خطأ، وخطؤها يبقى معروضًا داخله حتى يقرّر الأدمن غيره.
Future<bool> promptDashboardTarget({
  required BuildContext context,
  required AdminDashboardCubit cubit,
}) async {
  var saved = false;
  await showDashboardTargetDialog(
    context: context,
    current: cubit.state.metrics.monthlyRevenueTarget,
    onSubmit: (value) async {
      final ok = await cubit.saveRevenueTarget(value);
      if (ok) saved = true;
      return ok ? null : (cubit.state.targetError ?? S.couldNotLoadDashboard);
    },
  );
  return saved;
}
