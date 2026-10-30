import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/search/admin_search_controller.dart';
import 'package:admin_app/features/hr/domain/entities/hr_leave.dart';
import 'package:admin_app/features/hr/presentation/manager/hr_leave_cubit.dart';
import 'package:admin_app/features/hr/presentation/manager/hr_reference_cubit.dart';
import 'package:admin_app/features/hr/presentation/manager/hr_reference_state.dart';
import 'package:admin_app/features/hr/presentation/models/hr_list_state.dart';
import 'package:admin_app/features/hr/presentation/models/hr_person_option.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_balance_dialog.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_leave_view.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_note_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// شاشة الإجازات: قائمة الطلبات وقراران ورصيد السنة.
///
/// القرار لا يُرسل بلا سبب، لأن 212 ترفض السطر الفارغ؛ فالحوار يسأل قبل أن
/// يضغط المدير، ومن لا يملك `hr.leave.review` يرى السطور بلا أزرار.
class HrLeavePage extends StatefulWidget {
  const HrLeavePage({
    super.key,
    required this.searchController,
    required this.canReview,
    this.cubit,
    this.reference,
  });

  final AdminSearchController searchController;
  final bool canReview;
  final HrLeaveCubit? cubit;
  final HrReferenceCubit? reference;

  @override
  State<HrLeavePage> createState() => _HrLeavePageState();
}

class _HrLeavePageState extends State<HrLeavePage> {
  late final HrLeaveCubit _cubit;
  late final HrReferenceCubit _reference;
  late final bool _ownsCubit;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _ownsCubit = widget.cubit == null;
    _cubit = widget.cubit ?? HrLeaveCubit();
    _reference = widget.reference ?? HrReferenceCubit();
    if (_ownsCubit) {
      _cubit.reload();
      _reference.load();
    }
    widget.searchController.bind(_onSearch);
  }

  @override
  void dispose() {
    widget.searchController.bind(null);
    if (_ownsCubit) {
      _cubit.close();
      _reference.close();
    }
    super.dispose();
  }

  void _onSearch(String query) => setState(() => _search = query.trim());

  Future<void> _decide(HrLeaveRequest request, {required bool approve}) async {
    final note = await showHrNoteDialog(
      context,
      title: approve ? S.hrBtnApprove : S.hrActionReject,
      question: '${request.staffName} • ${request.typeName}',
      saveLabel: approve ? S.hrBtnApprove : S.hrActionReject,
    );
    if (note == null) return;
    await _cubit.review(requestId: request.id, approve: approve, note: note);
  }

  /// المرشَّحون من دليل الموظفين لا من طلبات مقروءة: أول رصيد سنة على قاعدةٍ بلا
  /// طلبات لا يُنشأ من قائمة مبنية على تلك الطلبات الفارغة.
  List<HrPersonOption>? get _people => _reference.state.people;

  Future<void> _setBalance() async {
    final draft = await showHrBalanceDialog(
      context,
      people: _people,
      leaveTypes: _reference.state.reference?.leaveTypes ?? const [],
    );
    if (draft == null) return;
    await _cubit.setBalance(
      staffId: draft.staffId,
      leaveTypeId: draft.leaveTypeId,
      year: draft.year,
      entitledDays: draft.entitledDays,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<HrLeaveCubit>.value(value: _cubit),
        BlocProvider<HrReferenceCubit>.value(value: _reference),
      ],
      // المرجع يبني معها: الحوار يقرأ أنواع الإجازة من الحالة عينها، فبناء
      // الشاشة بلا Builder عليها يتركها على مرجعٍ قديم إلى الأبد.
      child: BlocBuilder<HrLeaveCubit, HrListState<HrLeaveRequest>>(
        builder: (context, state) =>
            BlocBuilder<HrReferenceCubit, HrReferenceState>(
              builder: (context, reference) => HrLeaveView(
                state: state,
                search: _search,
                status: _cubit.status,
                canReview: widget.canReview,
                onStatusChanged: _cubit.setStatus,
                onApprove: (request) => _decide(request, approve: true),
                onReject: (request) => _decide(request, approve: false),
                onSetBalance: _setBalance,
                onRetry: () {
                  _cubit.reload();
                  _reference.load();
                },
              ),
            ),
      ),
    );
  }
}
