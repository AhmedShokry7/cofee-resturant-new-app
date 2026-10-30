import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/formatters.dart';
import 'package:admin_app/core/utils/localized_date.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/hr/domain/entities/hr_payroll.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_format.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_labels.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_status_cell.dart';
import 'package:admin_app/shared/widgets/admin_page_frame.dart';
import 'package:admin_app/shared/widgets/admin_page_header.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/custom_btn.dart';
import 'package:flutter/material.dart';

/// قسيمة راتب واحدة بأسطرها: قراءةٌ لصورة محفوظة، لا محرّر لرقم.
///
/// الأسطر ومجاميعها كما كتبها الحساب في الصف، فلا يعيد العرض جمعها حتى لا
/// يختلف عن المعتمد؛ والسطر داخل لقطة معتمدة يُقرأ ولا يُعدَّل.
class HrPayrollStatementView extends StatelessWidget {
  const HrPayrollStatementView({
    super.key,
    required this.statement,
    required this.canManage,
    required this.onCorrection,
    required this.onClose,
  });

  final HrPayrollStatement statement;
  final bool canManage;
  final VoidCallback onCorrection;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final period =
        '${localizedMonthName(statement.periodMonth)} ${localizeDigits('${statement.periodYear}')}';
    final immutable =
        statement.runStatus == 'approved' || statement.runStatus == 'paid';
    return AdminPageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminPageHeader(
            title: hrPersonName(statement.staffName),
            subtitle: period,
            actions: [
              CustomBtn(
                text: S.close,
                variant: BtnVariant.outlined,
                onPressed: onClose,
              ),
              if (canManage)
                CustomBtn(
                  text: S.hrBtnStatementCorrection,
                  variant: BtnVariant.outlined,
                  onPressed: onCorrection,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _identity(context, immutable),
                  const SizedBox(height: AppSpacing.md),
                  _lines(
                    context,
                    S.hrKindAddition,
                    statement.lines.where((l) => l.isAddition).toList(),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _lines(
                    context,
                    S.hrKindDeduction,
                    statement.lines.where((l) => !l.isAddition).toList(),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _totals(context),
                  const SizedBox(height: AppSpacing.md),
                  _attendance(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _identity(BuildContext context, bool immutable) => AdminSectionCard(
    title: hrPersonName(statement.staffName),
    subtitle:
        '${S.hrColEmployeeNumber}: ${statement.employeeNumber.isEmpty ? S.hrUnknownPerson : statement.employeeNumber}',
    leading: HrStatusCell(statement.runStatus),
    // التصريح بحروف القاعدة: معتمدة لا تُعدَّل، وغيرُها بعدُ ليست نهائية.
    child: _muted(
      context,
      immutable ? S.hrStatementImmutable : S.hrPayslipNotFinal,
    ),
  );

  Widget _lines(
    BuildContext context,
    String title,
    List<HrPayrollLine> lines,
  ) => AdminSectionCard(
    title: title,
    count: lines.length,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (lines.isEmpty) _muted(context, S.hrEmptyList),
        for (final line in lines)
          _row(
            context,
            '${hrCategoryLabel(line.category)} • ${hrSourceLabel(line.sourceType)}',
            localizeDigits(formatAmount(line.amount)),
          ),
      ],
    ),
  );

  Widget _totals(BuildContext context) => AdminSectionCard(
    title: S.hrColNet,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final pair in <List<String>>[
          <String>[
            S.hrFieldBasicPay,
            localizeDigits(formatAmount(statement.basicSalary)),
          ],
          <String>[
            S.hrKindAllowance,
            localizeDigits(formatAmount(statement.allowancesTotal)),
          ],
          <String>[
            S.hrKindAddition,
            localizeDigits(formatAmount(statement.additionsTotal)),
          ],
          <String>[
            S.hrCategoryAttendance,
            localizeDigits(formatAmount(statement.attendanceDeduction)),
          ],
          <String>[
            S.hrCategoryAdvance,
            localizeDigits(formatAmount(statement.advanceDeduction)),
          ],
          <String>[
            S.hrCategoryManual,
            localizeDigits(formatAmount(statement.otherDeductions)),
          ],
          <String>[
            S.hrColDeductions,
            localizeDigits(formatAmount(statement.deductionsTotal)),
          ],
          <String>[S.hrColGross, localizeDigits(formatAmount(statement.gross))],
          <String>[S.hrColNet, localizeDigits(formatAmount(statement.net))],
        ])
          _row(context, pair[0], pair[1]),
        const SizedBox(height: AppSpacing.xs),
        // إصدار الحساب يُذكر للرجع عند الطعن، لا كرقم قابل للتعديل.
        _muted(context, '${S.hrColSource}: ${statement.calculationVersion}'),
      ],
    ),
  );

  Widget _attendance(BuildContext context) => AdminSectionCard(
    title: S.hrSectionAttendance,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _row(context, S.hrColDays, localizeDigits('${statement.absenceDays}')),
        _row(context, S.hrColLate, hrDuration(statement.lateMinutes)),
        _row(context, S.hrOnBreak, hrDuration(statement.earlyMinutes)),
      ],
    ),
  );

  Widget _row(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xxs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: adminMutedColor(theme),
                fontSize: AppFontSizes.size10_5,
                height: AppTextHeights.line1_5,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            value,
            style: TextStyle(
              color: adminAmountColor(theme),
              fontSize: AppFontSizes.size11_5,
              fontWeight: AppFontWeights.semiBold,
              height: AppTextHeights.line1_5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _muted(BuildContext context, String text) => Text(
    text,
    style: TextStyle(
      color: adminMutedColor(Theme.of(context)),
      fontSize: AppFontSizes.size10_5,
      height: AppTextHeights.line1_5,
    ),
  );
}
