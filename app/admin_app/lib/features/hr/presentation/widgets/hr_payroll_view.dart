import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/localized_date.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/hr/domain/entities/hr_payroll.dart';
import 'package:admin_app/features/hr/domain/entities/hr_refusal.dart';
import 'package:admin_app/features/hr/presentation/manager/hr_payroll_state.dart';
import 'package:admin_app/features/hr/presentation/models/hr_load_status.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_cell_text.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_directory.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_labels.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_record_card.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_refusal_note.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_row_button.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_status_cell.dart';
import 'package:admin_app/shared/widgets/admin_directory_panel.dart';
import 'package:admin_app/shared/widgets/admin_page_frame.dart';
import 'package:admin_app/shared/widgets/admin_page_header.dart';
import 'package:admin_app/shared/widgets/admin_stat_tile.dart';
import 'package:admin_app/shared/widgets/admin_state_view.dart';
import 'package:admin_app/shared/widgets/custom_btn.dart';
import 'package:flutter/material.dart';

/// قائمة دورات الرواتب: لقطةٌ لكل شهر، والانتقال يُطلب من الدورة نفسها لا من هنا.
///
/// الدورة لم تُقرأ تُترك فارغة بلا صفر، والسطر الذي يملك المدير قراره وحده
/// يُظهر زرّه؛ فالصف موجود دائمًا والرأي محكومٌ بالصلاحية والحالة.
class HrPayrollView extends StatelessWidget {
  const HrPayrollView({
    super.key,
    required this.state,
    required this.search,
    required this.canManage,
    required this.canApprove,
    required this.canPay,
    required this.onGenerate,
    required this.onOpenRun,
    required this.onApprove,
    required this.onPay,
    required this.onCancel,
    required this.onRetry,
  });

  final HrPayrollState state;
  final String search;

  /// يولّد ويلغي: `hr.payroll.manage`.
  final bool canManage;

  /// يعتمد الدورة المحسوبة: `hr.payroll.approve`، وهو دورٌ آخر في القاعدة.
  final bool canApprove;

  /// يصرف المعتمدة: `hr.payroll.pay`.
  final bool canPay;
  final VoidCallback onGenerate;
  final ValueChanged<HrPayrollRun> onOpenRun;
  final ValueChanged<HrPayrollRun> onApprove;
  final ValueChanged<HrPayrollRun> onPay;
  final ValueChanged<HrPayrollRun> onCancel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final last = state.runs.isEmpty ? null : state.runs.first;
    return AdminPageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminPageHeader(
            title: S.hrPayroll,
            // لا يُذكر آخر دورة إلا إن قرأتها القاعدة فعلًا، لا فترة مخمينة.
            subtitle: last == null
                ? S.hrPayrollSubtitle
                : '${S.hrPayrollSubtitle} • ${S.hrLatestRun}: ${_period(last)}',
            progress: state.isWriting ? 0 : null,
            progressLabel: state.isWriting ? S.saving : null,
            actions: [
              if (canManage)
                CustomBtn(
                  text: S.hrBtnGeneratePayroll,
                  variant: BtnVariant.outlined,
                  onPressed: onGenerate,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          HrRefusalNote(refusal: state.failure),
          if (state.receipt != null) ...[
            const SizedBox(height: AppSpacing.xs),
            HrReceiptNote(receipt: state.receipt!),
          ],
          const SizedBox(height: AppSpacing.sm),
          Expanded(child: _body(context)),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    final failure = state.failure;
    if (state.status == HrLoadStatus.loading && state.runs.isEmpty) {
      return const AdminLoadingView();
    }
    if (state.status == HrLoadStatus.failure && state.runs.isEmpty) {
      return AdminFailureView(
        message: failure == null ? null : hrRefusalMessage(failure),
        onRetry: onRetry,
      );
    }
    return AdminDirectoryPanel(
      child: HrDirectory<HrPayrollRun>(
        items: state.runs,
        search: search,
        emptyLabel: S.hrEmptyPayroll,
        searchOf: (run) => _period(run),
        columns: <String>[
          S.hrColPeriod,
          S.hrColStatements,
          S.hrColGross,
          S.hrColDeductions,
          S.hrColNet,
          S.status,
        ],
        cellsOf: (context, run) => [
          HrCellText(_period(run), strong: true),
          HrCellText(localizeDigits('${run.statementCount}')),
          _money(context, run.totalGross),
          _money(context, run.totalDeductions),
          _money(context, run.totalNet),
          HrStatusCell(run.status),
        ],
        cardOf: (context, run) => _card(context, run),
        actionsOf: (context, run) => _decisions(run),
        onTap: onOpenRun,
      ),
    );
  }

  Widget _card(BuildContext context, HrPayrollRun run) => HrRecordCard(
    title: _period(run),
    subtitle: hrStatusLabel(run.status).text,
    badge: HrStatusCell(run.status),
    onTap: () => onOpenRun(run),
    fields: [
      HrCardField(
        S.hrColStatements,
        HrCellText(localizeDigits('${run.statementCount}')),
      ),
      HrCardField(S.hrColNet, _money(context, run.totalNet)),
      if (run.note.isNotEmpty)
        HrCardField(S.hrFieldNote, HrCellText(run.note, muted: true)),
      if (run.calculatedAt != null)
        HrCardField(
          S.hrStatusCalculated,
          HrCellText(localizedDate(run.calculatedAt), muted: true),
        ),
      if (run.approvedAt != null)
        HrCardField(
          S.hrStatusApproved,
          HrCellText(localizedDate(run.approvedAt), muted: true),
        ),
      if (run.paidAt != null)
        HrCardField(
          S.hrStatusPaid,
          HrCellText(localizedDate(run.paidAt), muted: true),
        ),
    ],
    trailing: _actions(run),
  );

  Widget? _actions(HrPayrollRun run) {
    final buttons = _decisions(run);
    if (buttons.isEmpty) return null;
    return Wrap(spacing: AppSpacing.sm, children: buttons);
  }

  /// قرارات السطر التي يملكها الدور وحده: اعتمادٌ لغير المعتمد لا يُعرض.
  List<Widget> _decisions(HrPayrollRun run) => [
    if (canApprove && run.isCalculated)
      HrRowButton(text: S.hrBtnApprove, onPressed: () => onApprove(run)),
    if (canPay && run.isApproved)
      HrRowButton(text: S.hrBtnPay, onPressed: () => onPay(run)),
    if (canManage && run.isCancellable)
      HrRowButton(
        text: S.hrBtnCancelRequest,
        danger: true,
        onPressed: () => onCancel(run),
      ),
  ];

  Widget _money(BuildContext context, double value) =>
      AdminMoneyText(value: value, fontSize: AppFontSizes.size11_5);

  String _period(HrPayrollRun run) =>
      '${localizedMonthName(run.periodMonth)} ${localizeDigits('${run.periodYear}')}';
}
