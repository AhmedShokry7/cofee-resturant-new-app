import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/search/admin_search_controller.dart';
import 'package:admin_app/core/utils/localized_date.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/hr/domain/entities/hr_payroll.dart';
import 'package:admin_app/features/hr/presentation/manager/hr_payroll_cubit.dart';
import 'package:admin_app/features/hr/presentation/manager/hr_payroll_state.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_generate_payroll_dialog.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_note_dialog.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_payroll_run_detail.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_payroll_statement_view.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_payroll_view.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_statement_correction_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// شاشة الرواتب: الدورات، ثم دورةٌ مفتوحة بقسيماتها، ثم قسيمةٌ بأسطرها.
///
/// الأدوار الثلاثة منفصلة كما في 212 — من يولّد لا يعتمد، ومن يعتمد لا يصرف —
/// فتُبنى الأزرار على الرمز الذي يملكه السائل فعلًا. ولا انتقال يُرسل بلا سبب
/// مكتوب حين يكون السبب مطلوبًا، لأن القاعدة ترفض الفراغ.
class HrPayrollPage extends StatefulWidget {
  const HrPayrollPage({
    super.key,
    required this.searchController,
    required this.canManage,
    required this.canApprove,
    required this.canPay,
    this.cubit,
  });

  final AdminSearchController searchController;
  final bool canManage;
  final bool canApprove;
  final bool canPay;
  final HrPayrollCubit? cubit;

  @override
  State<HrPayrollPage> createState() => _HrPayrollPageState();
}

class _HrPayrollPageState extends State<HrPayrollPage> {
  late final HrPayrollCubit _cubit;
  late final bool _ownsCubit;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _ownsCubit = widget.cubit == null;
    _cubit = widget.cubit ?? HrPayrollCubit();
    if (_ownsCubit) _cubit.reload();
    widget.searchController.bind(_onSearch);
  }

  @override
  void dispose() {
    widget.searchController.bind(null);
    if (_ownsCubit) _cubit.close();
    super.dispose();
  }

  void _onSearch(String query) => setState(() => _search = query.trim());

  Future<void> _generate() async {
    final draft = await showHrGeneratePayrollDialog(context);
    if (draft == null) return;
    await _cubit.generate(
      periodYear: draft.periodYear,
      periodMonth: draft.periodMonth,
      note: draft.note,
    );
  }

  /// انتقالٌ واحد بعد سببٍ مكتوب: اعتمادٌ أو صرفٌ أو إلغاء.
  Future<void> _transition(
    HrPayrollRun run,
    String label,
    Future<bool> Function(String? note) send,
  ) async {
    final note = await showHrNoteDialog(
      context,
      title: label,
      question: '${S.hrColPeriod} ${_period(run)}',
      saveLabel: label,
      // السبب اختياريًا هنا: `approve|pay|cancel` في 212 تقبل `note` بلا إلزام،
      // فإجبارها على الشاشة يبيع المدير حوارًا لا تطلبه القاعدة.
      noteRequired: false,
    );
    if (note == null) return;
    await send(note.trim().isEmpty ? null : note.trim());
  }

  Future<void> _correct(HrPayrollStatement statement) async {
    final draft = await showHrStatementCorrectionDialog(
      context,
      statementId: statement.statementId,
      staffName: statement.staffName,
    );
    if (draft == null) return;
    await _cubit.correction(
      statementId: statement.statementId,
      kind: draft.kind,
      amount: draft.amount,
      reason: draft.reason,
      effectiveDate: draft.effectiveDate,
    );
  }

  String _period(HrPayrollRun run) =>
      '${localizedMonthName(run.periodMonth)} '
      '${localizeDigits('${run.periodYear}')}';

  @override
  Widget build(BuildContext context) {
    return BlocProvider<HrPayrollCubit>.value(
      value: _cubit,
      child: BlocBuilder<HrPayrollCubit, HrPayrollState>(
        builder: (context, state) {
          final statement = state.statement;
          if (statement != null) {
            return HrPayrollStatementView(
              statement: statement,
              canManage: widget.canManage,
              onCorrection: () => _correct(statement),
              onClose: _cubit.closeStatement,
            );
          }
          final run = state.run;
          if (run != null) {
            return HrPayrollRunDetail(
              run: run,
              canManage: widget.canManage,
              canApprove: widget.canApprove,
              canPay: widget.canPay,
              onOpenStatement: _cubit.openStatement,
              onClose: _cubit.closeRun,
              onApprove: () => _transition(
                run,
                S.hrBtnApprove,
                (note) => _cubit.approve(runId: run.runId, note: note),
              ),
              onPay: () => _transition(
                run,
                S.hrBtnPay,
                (note) => _cubit.pay(runId: run.runId, note: note),
              ),
              onCancel: () => _transition(
                run,
                S.hrBtnCancelRequest,
                (note) => _cubit.cancel(runId: run.runId, note: note),
              ),
            );
          }
          return HrPayrollView(
            state: state,
            search: _search,
            canManage: widget.canManage,
            canApprove: widget.canApprove,
            canPay: widget.canPay,
            onGenerate: _generate,
            onOpenRun: (run) => _cubit.openRun(run.runId),
            onApprove: (run) => _transition(
              run,
              S.hrBtnApprove,
              (note) => _cubit.approve(runId: run.runId, note: note),
            ),
            onPay: (run) => _transition(
              run,
              S.hrBtnPay,
              (note) => _cubit.pay(runId: run.runId, note: note),
            ),
            onCancel: (run) => _transition(
              run,
              S.hrBtnCancelRequest,
              (note) => _cubit.cancel(runId: run.runId, note: note),
            ),
            onRetry: _cubit.reload,
          );
        },
      ),
    );
  }
}
