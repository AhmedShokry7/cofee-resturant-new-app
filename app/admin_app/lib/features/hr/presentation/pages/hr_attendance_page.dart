import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/search/admin_search_controller.dart';
import 'package:admin_app/features/hr/domain/entities/hr_attendance.dart';
import 'package:admin_app/features/hr/presentation/manager/hr_attendance_cubit.dart';
import 'package:admin_app/features/hr/presentation/manager/hr_attendance_state.dart';
import 'package:admin_app/features/hr/presentation/manager/hr_reference_cubit.dart';
import 'package:admin_app/features/hr/presentation/manager/hr_reference_state.dart';
import 'package:admin_app/features/hr/presentation/models/hr_person_option.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_attendance_view.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_correction_request_dialog.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_format.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_note_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// شاشة الحضور: جلسات المدى وتصحيحاتها المعلّقة في مسار واحد.
///
/// الصفحة تملك عقديها وتربط بحث الدرج وتفتح الحوارات، أما القرار فلا يُرسل
/// بلا سبب لأن `hr.review_correction` ترفض الفراغ؛ ومن لا يملك `hr.attendance`
/// للمراجعة يرى السطور بلا أزرار.
class HrAttendancePage extends StatefulWidget {
  const HrAttendancePage({
    super.key,
    required this.searchController,
    required this.canReview,
    this.cubit,
    this.reference,
  });

  final AdminSearchController searchController;
  final bool canReview;

  /// يُحقنان في الاختبار؛ وإلا بنت الصفحة عقديها من `HrDependencies`.
  final HrAttendanceCubit? cubit;
  final HrReferenceCubit? reference;

  @override
  State<HrAttendancePage> createState() => _HrAttendancePageState();
}

class _HrAttendancePageState extends State<HrAttendancePage> {
  late final HrAttendanceCubit _cubit;
  late final HrReferenceCubit _reference;
  late final bool _ownsCubit;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _ownsCubit = widget.cubit == null;
    _cubit = widget.cubit ?? HrAttendanceCubit();
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

  /// المرشحون من دليل الموظفين لا من الجلسات: تصحيح حضور لموظفٍ لا جلسة له اليوم
  /// لا يُلتمس من قائمة بُنيت على جلسات مقروءة خالية.
  List<HrPersonOption>? get _people => _reference.state.people;

  Future<void> _requestCorrection(HrAttendanceRow? row) async {
    final draft = await showHrCorrectionRequestDialog(
      context,
      people: _people,
      row: row,
    );
    if (draft == null) return;
    await _cubit.requestCorrection(
      staff: draft.staffId,
      sessionId: draft.sessionId,
      clockInAt: draft.clockInAt,
      clockOutAt: draft.clockOutAt,
      reason: draft.reason,
    );
  }

  Future<void> _decide(
    HrAttendanceCorrection correction, {
    required bool approve,
  }) async {
    final note = await showHrNoteDialog(
      context,
      title: approve ? S.hrBtnApprove : S.hrActionReject,
      question: '${hrPersonName(correction.staffName)} • ${correction.reason}',
      saveLabel: approve ? S.hrBtnApprove : S.hrActionReject,
    );
    if (note == null) return;
    await _cubit.review(
      correctionId: correction.id,
      approve: approve,
      note: note,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<HrAttendanceCubit>.value(value: _cubit),
        BlocProvider<HrReferenceCubit>.value(value: _reference),
      ],
      child: BlocBuilder<HrAttendanceCubit, HrAttendanceState>(
        builder: (context, state) =>
            BlocBuilder<HrReferenceCubit, HrReferenceState>(
              // المرجع يُبنى مع السطور: عاد بعد القائمة فله أن يغيّر صفحتها،
              // لا أن تُقرأ حالته أمرًا واحدًا عند الفتح.
              builder: (context, reference) => HrAttendanceView(
                state: state,
                search: _search,
                canReview: widget.canReview,
                branches: reference.reference?.branches,
                from: _cubit.from,
                to: _cubit.to,
                branchId: _cubit.branchId,
                correctionStatus: _cubit.correctionStatus,
                onBranchChanged: _cubit.setBranch,
                onCorrectionStatusChanged: _cubit.setCorrectionStatus,
                onFromChanged: (value) =>
                    _cubit.setRange(newFrom: value, newTo: _cubit.to),
                onToChanged: (value) =>
                    _cubit.setRange(newFrom: _cubit.from, newTo: value),
                onRequestCorrection: _requestCorrection,
                onApprove: (value) => _decide(value, approve: true),
                onReject: (value) => _decide(value, approve: false),
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
