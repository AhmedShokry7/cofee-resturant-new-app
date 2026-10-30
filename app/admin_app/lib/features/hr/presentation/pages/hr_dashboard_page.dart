import 'package:admin_app/features/hr/presentation/manager/hr_dashboard_cubit.dart';
import 'package:admin_app/features/hr/presentation/manager/hr_dashboard_state.dart';
import 'package:admin_app/features/hr/presentation/manager/hr_reference_cubit.dart';
import 'package:admin_app/features/hr/presentation/manager/hr_reference_state.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_dashboard_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// لوحة القوى العاملة: سؤال واحد للقاعدة، وفرعٌ اختياريٌّ يُضيّقه.
///
/// الفرع لا يُفتَرش على الجهاز ولا يُشتق من أي مكان آخر: من يملك كل الفروع يسأل
/// عنها دفعة واحدة، ومن يملك فرعًا واحدًا لا يرى بابًا لا يفتح شيئًا.
class HrDashboardPage extends StatefulWidget {
  const HrDashboardPage({super.key, this.cubit, this.reference});

  final HrDashboardCubit? cubit;
  final HrReferenceCubit? reference;

  @override
  State<HrDashboardPage> createState() => _HrDashboardPageState();
}

class _HrDashboardPageState extends State<HrDashboardPage> {
  late final HrDashboardCubit _cubit;
  late final HrReferenceCubit _reference;
  late final bool _ownsCubit;

  @override
  void initState() {
    super.initState();
    _ownsCubit = widget.cubit == null;
    _cubit = widget.cubit ?? HrDashboardCubit();
    _reference = widget.reference ?? HrReferenceCubit();
    if (_ownsCubit) {
      _cubit.load();
      _reference.load();
    }
  }

  @override
  void dispose() {
    if (_ownsCubit) {
      _cubit.close();
      _reference.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<HrDashboardCubit>.value(
      value: _cubit,
      child: BlocBuilder<HrDashboardCubit, HrDashboardState>(
        builder: (context, state) => BlocProvider<HrReferenceCubit>.value(
          value: _reference,
          child: BlocBuilder<HrReferenceCubit, HrReferenceState>(
            builder: (context, reference) => HrDashboardView(
              state: state,
              branches: reference.reference?.branches ?? const [],
              branchesFailure: reference.failure,
              onBranchChanged: _cubit.selectBranch,
              onRetry: () => _cubit.load(branchId: state.branchId),
            ),
          ),
        ),
      ),
    );
  }
}
