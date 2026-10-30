import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/localized_date.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/hr/domain/entities/hr_payroll.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_cell_text.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_directory.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_labels.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_record_card.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_status_cell.dart';
import 'package:admin_app/shared/widgets/admin_directory_panel.dart';
import 'package:admin_app/shared/widgets/admin_page_frame.dart';
import 'package:admin_app/shared/widgets/admin_page_header.dart';
import 'package:admin_app/shared/widgets/admin_stat_tile.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/custom_btn.dart';
import 'package:flutter/material.dart';

/// دورة رواتب مفتوحة بقسيماتها: انتقالٌ مسموح وحده، وأسطرُها صورة محفوظة.
///
/// الزرّ لا يظهر إلا حين تسمح به القاعدة (`calculated → approve`, `approved →
/// pay`)، وحيث غاب يُذكر سببه حرفيًا للمدير الذي يملك النظر، فتغيب المحاكمة
/// الصامتة التي تخفي سبب رفض الزرّ.
class HrPayrollRunDetail extends StatelessWidget {
  const HrPayrollRunDetail({
    super.key,
    required this.run,
    required this.canManage,
    required this.canApprove,
    required this.canPay,
    required this.onOpenStatement,
    required this.onClose,
    required this.onApprove,
    required this.onPay,
    required this.onCancel,
  });

  final HrPayrollRun run;

  /// يُلغي ويُصدر التصحيحات: `hr.payroll.manage`.
  final bool canManage;

  /// يعتمد الدورة: `hr.payroll.approve`، وهو دورٌ منفصل في 212.
  final bool canApprove;

  /// يصرف المعتمدة: `hr.payroll.pay`.
  final bool canPay;
  final ValueChanged<String> onOpenStatement;
  final VoidCallback onClose;
  final VoidCallback onApprove;
  final VoidCallback onPay;
  final VoidCallback onCancel;

  String get _period =>
      '${localizedMonthName(run.periodMonth)} ${localizeDigits('${run.periodYear}')}';

  @override
  Widget build(BuildContext context) {
    return AdminPageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminPageHeader(
            title: _period,
            subtitle: hrStatusLabel(run.status).text,
            actions: [
              CustomBtn(
                text: S.hrActionClose,
                variant: BtnVariant.outlined,
                onPressed: onClose,
              ),
              if (canApprove && run.isCalculated)
                CustomBtn(text: S.hrBtnApprove, onPressed: onApprove),
              if (canPay && run.isApproved)
                CustomBtn(text: S.hrBtnPay, onPressed: onPay),
              if (canManage && run.isCancellable)
                CustomBtn(
                  text: S.hrBtnCancelRequest,
                  variant: BtnVariant.destructive,
                  onPressed: onCancel,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _totals(context),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: AdminDirectoryPanel(
              child: HrDirectory<HrPayrollStatement>(
                items: run.statements,
                search: '',
                emptyLabel: S.hrEmptyPayroll,
                searchOf: (s) => s.staffName,
                columns: <String>[
                  S.hrColEmployee,
                  S.hrColEmployeeNumber,
                  S.hrColGross,
                  S.hrColDeductions,
                  S.hrColNet,
                  S.status,
                ],
                cellsOf: (context, s) => [
                  HrCellText(s.staffName, strong: true),
                  HrCellText(s.employeeNumber, muted: true),
                  _money(context, s.gross),
                  _money(context, s.deductionsTotal),
                  _money(context, s.net),
                  HrStatusCell(s.runStatus),
                ],
                cardOf: (context, s) => HrRecordCard(
                  title: s.staffName,
                  subtitle: s.employeeNumber,
                  badge: HrStatusCell(s.runStatus),
                  onTap: () => onOpenStatement(s.statementId),
                  fields: [
                    HrCardField(S.hrColGross, _money(context, s.gross)),
                    HrCardField(
                      S.hrColDeductions,
                      _money(context, s.deductionsTotal),
                    ),
                    HrCardField(S.hrColNet, _money(context, s.net)),
                  ],
                ),
                onTap: (s) => onOpenStatement(s.statementId),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// شريط المجاميع الثلاثة بأرقام الدورة نفسها، لا بجمع الشاشة لقسائمها.
  Widget _totals(BuildContext context) {
    final reasons = _blockedReasons();
    return AdminSectionCard(
      title: S.hrColGross,
      subtitle: run.note.isEmpty ? null : run.note,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xs,
            children: [
              _band(context, S.hrColGross, run.totalGross),
              _band(context, S.hrColDeductions, run.totalDeductions),
              _band(context, S.hrColNet, run.totalNet),
            ],
          ),
          if (reasons.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            for (final reason in reasons)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xxs),
                child: Text(
                  reason,
                  style: TextStyle(
                    color: adminMutedColor(Theme.of(context)),
                    fontSize: AppFontSizes.size10_5,
                    height: AppTextHeights.line1_5,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  /// سبب كل انتقالٍ غاب، معروضًا للمدير الذي يملك النظر فقط.
  List<String> _blockedReasons() => <String>[
    if (canApprove && !run.isCalculated) S.hrOnlyCalculatedApprovable,
    if (canPay && !run.isApproved) S.hrOnlyApprovedPayable,
    if (canManage && !run.isCancellable) S.hrRunNotCancellable,
  ];

  Widget _band(BuildContext context, String label, double value) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        '$label: ',
        style: TextStyle(
          color: adminMutedColor(Theme.of(context)),
          fontSize: AppFontSizes.size10_5,
        ),
      ),
      AdminMoneyText(value: value),
    ],
  );

  Widget _money(BuildContext context, double value) =>
      AdminMoneyText(value: value, fontSize: AppFontSizes.size11_5);
}
