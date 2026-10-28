import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/search/admin_search_controller.dart';
import 'package:admin_app/features/dashboard/presentation/manager/admin_dashboard_cubit.dart';
import 'package:admin_app/features/dashboard/presentation/manager/admin_dashboard_state.dart';
import 'package:admin_app/features/dashboard/presentation/widgets/dashboard_page_body.dart';
import 'package:admin_app/features/dashboard/presentation/widgets/dashboard_target_prompt.dart';
import 'package:admin_app/shared/widgets/admin_state_view.dart';

/// صفحة لوحة التحكم: مسار وحياتها فقط.
///
/// تقرأ الأرقام مرة عند الفتح ومرة عند التحديث، وتمرّر اسم الموظف وقرار من
/// يملك كتابة الهدف من الترويسة التي تعرف الجلسة: لا الصفحة تسأل القاعدة عن
/// صلاحية، ولا بطاقة تقرأ حالة الدخول.
class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.searchController,
    required this.staffName,
    required this.canManageTarget,
    this.cubit,
  });

  static const String routeName = '/dashboard';

  final AdminSearchController searchController;

  /// اسم الموظف من جلسته، و`canManageTarget` صدقه على كتابة هدف الشهر.
  final String staffName;
  final bool canManageTarget;
  final AdminDashboardCubit? cubit;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late final AdminDashboardCubit _cubit;
  late final bool _ownsCubit;

  @override
  void initState() {
    super.initState();
    _ownsCubit = widget.cubit == null;
    _cubit = widget.cubit ?? AdminDashboardCubit();
    if (_ownsCubit) _cubit.load();
    widget.searchController.bind(_cubit.search);
  }

  @override
  void dispose() {
    widget.searchController.bind(null);
    if (_ownsCubit) _cubit.close();
    super.dispose();
  }

  /// يفتح حوار الهدف ويخبر الأدمن حين تكون القاعدة هي التي كتبت الرقم.
  Future<void> _editTarget() async {
    final messenger = ScaffoldMessenger.of(context);
    if (!await promptDashboardTarget(context: context, cubit: _cubit)) return;
    if (!mounted) return;
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(S.dashboardTargetSaved)));
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AdminDashboardCubit>.value(
      value: _cubit,
      child: BlocBuilder<AdminDashboardCubit, AdminDashboardState>(
        builder: (_, state) {
          if (state.isLoading && !state.hasMetrics) {
            return const AdminLoadingView();
          }
          if (state.isFailure && !state.hasMetrics) {
            return AdminFailureView(
              message: state.errorMessage ?? S.couldNotLoadDashboard,
              onRetry: _cubit.load,
            );
          }
          return DashboardPageBody(
            state: state,
            staffName: widget.staffName,
            canManageTarget: widget.canManageTarget,
            onRefresh: _cubit.load,
            onRangeChanged: _cubit.setSalesRange,
            onEditTarget: _editTarget,
          );
        },
      ),
    );
  }
}
