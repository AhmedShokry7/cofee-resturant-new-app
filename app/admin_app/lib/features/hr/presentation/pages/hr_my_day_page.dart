import 'package:admin_app/core/search/admin_search_controller.dart';
import 'package:admin_app/features/hr/domain/entities/hr_refusal.dart';
import 'package:admin_app/features/hr/presentation/manager/hr_my_day_cubit.dart';
import 'package:admin_app/features/hr/presentation/manager/hr_my_day_state.dart';
import 'package:admin_app/features/hr/presentation/models/hr_load_status.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_advance_request_dialog.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_leave_request_dialog.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_my_day_body.dart';
import 'package:admin_app/shared/widgets/admin_state_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// شاشة «يومي» للموظف الكاشير نفسه: توفر الـ Cubit وتجمع العرض.
///
/// لا صلاحية تُسأل هنا: كل ما تعرضه ملك الهوية التي تقرأها القاعدة من الجلسة،
/// ولو فشل سؤالٌ بقي غائبًا لا صفرًا، ويُعرض رفضه كما رفعته `212`.
class HrMyDayPage extends StatefulWidget {
  const HrMyDayPage({super.key, required this.searchController, this.cubit});

  final AdminSearchController searchController;

  /// يُحقن في الاختبار؛ وإلا بنت الشاشة عقدها من `HrDependencies`.
  final HrMyDayCubit? cubit;

  @override
  State<HrMyDayPage> createState() => _HrMyDayPageState();
}

class _HrMyDayPageState extends State<HrMyDayPage> {
  late final HrMyDayCubit _cubit;
  late final bool _ownsCubit;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _ownsCubit = widget.cubit == null;
    _cubit = widget.cubit ?? HrMyDayCubit();
    if (_ownsCubit) _cubit.load();
    widget.searchController.bind(_onSearch);
  }

  @override
  void dispose() {
    widget.searchController.bind(null);
    if (_ownsCubit) _cubit.close();
    super.dispose();
  }

  void _onSearch(String query) => setState(() => _search = query.trim());

  Future<void> _requestLeave() async {
    final draft = await showHrLeaveDialog(
      context,
      types: _cubit.state.reference?.leaveTypes ?? const [],
    );
    if (draft == null) return;
    await _cubit.requestLeave(
      leaveTypeId: draft.leaveTypeId,
      startsOn: draft.startsOn,
      endsOn: draft.endsOn,
      reason: draft.reason,
      supportingDocument: draft.document,
    );
  }

  Future<void> _requestAdvance() async {
    final draft = await showHrAdvanceDialog(context);
    if (draft == null) return;
    await _cubit.requestAdvance(
      amount: draft.amount,
      reason: draft.reason,
      installment: draft.installment,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<HrMyDayCubit>.value(
      value: _cubit,
      child: BlocBuilder<HrMyDayCubit, HrMyDayState>(
        builder: (context, state) {
          if (state.isLoading && state.reference == null) {
            return const AdminLoadingView();
          }
          if (state.status == HrLoadStatus.failure && state.reference == null) {
            return AdminFailureView(
              message: state.failure == null
                  ? null
                  : hrRefusalMessage(state.failure!),
              onRetry: _cubit.load,
            );
          }
          return HrMyDayBody(
            state: state,
            search: _search,
            onClockIn: _cubit.clockIn,
            onClockOut: _cubit.clockOut,
            onBreakStart: _cubit.breakStart,
            onBreakEnd: _cubit.breakEnd,
            onCancelLeave: _cubit.cancelLeave,
            onRequestLeave: _requestLeave,
            onRequestAdvance: _requestAdvance,
          );
        },
      ),
    );
  }
}
