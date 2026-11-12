import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/localized_date.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/hr/domain/entities/hr_payroll_preview.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_cell_text.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_directory.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_record_card.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_status_cell.dart';
import 'package:admin_app/shared/widgets/admin_directory_panel.dart';
import 'package:admin_app/shared/widgets/admin_page_frame.dart';
import 'package:admin_app/shared/widgets/admin_page_header.dart';
import 'package:admin_app/shared/widgets/admin_stat_tile.dart';
import 'package:admin_app/shared/widgets/custom_btn.dart';
import 'package:flutter/material.dart';

/// لوحة المعاينة: ما تردّه `admin_hr_preview_payroll` لا ما تحسبه الشاشة.
///
/// ثلاث كتل من مصدر واحد: الموظفون وصافيهم المتوقع بأسطر مصدره، النواقص
/// التي يُحذف صاحبها من التوليد بصمت اليوم، والتسويات المستحقة على الفترة
/// بعلم الترحيل. الشهر السابق المصروف يظهر لمقارنة الصافي حيث وُجد.
class HrPayrollPreviewPanel extends StatelessWidget {
  const HrPayrollPreviewPanel({
    super.key,
    required this.preview,
    required this.onClose,
  });

  final HrPayrollPreview preview;
  final VoidCallback onClose;

  String get _period =>
      '${localizedMonthName(preview.periodMonth)} '
      '${localizeDigits('${preview.periodYear}')}';

  @override
  Widget build(BuildContext context) {
    return AdminPageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminPageHeader(
            title: S.hrPayrollPreviewTitle,
            subtitle: '$_period • ${S.hrPayrollPreviewHint}',
            actions: [
              CustomBtn(
                text: S.hrActionClose,
                variant: BtnVariant.outlined,
                onPressed: onClose,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _previous(context),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              children: [
                if (preview.missingData.isNotEmpty) _missing(context),
                if (preview.adjustmentsDue.isNotEmpty) _due(context),
                _employees(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _previous(BuildContext context) {
    final previous = preview.previousMonth;
    if (previous == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          HrCellText(
            '${S.hrPreviewPrevious}: '
            '${localizedMonthName(previous.periodMonth)} '
            '${localizeDigits('${previous.periodYear}')} '
            '(${S.hrLatestRun}: ${localizeDigits('${previous.statementCount}')})',
            strong: true,
          ),
          AdminMoneyText(value: previous.totalNet),
        ],
      ),
    );
  }

  Widget _missing(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HrCellText(S.hrPreviewMissingData, strong: true),
          const SizedBox(height: AppSpacing.xs),
          for (final item in preview.missingData)
            HrCellText('${item.staffName} — ${S.hrPreviewMissingReason}'),
        ],
      ),
    );
  }

  Widget _due(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HrCellText(S.hrPreviewAdjustmentsDue, strong: true),
          const SizedBox(height: AppSpacing.xs),
          for (final item in preview.adjustmentsDue)
            HrCellText(
              '${item.staffName} • ${item.reason} • '
              '${localizeDigits(item.amount.toStringAsFixed(2))}'
              '${item.deferred ? ' • ${S.hrPreviewDeferred}' : ''}',
            ),
        ],
      ),
    );
  }

  Widget _employees(BuildContext context) {
    return AdminDirectoryPanel(
      child: HrDirectory<HrPayrollPreviewEmployee>(
        items: preview.employees,
        search: '',
        emptyLabel: S.hrEmptyPayroll,
        searchOf: (e) => e.staffName,
        columns: <String>[
          S.hrColEmployee,
          S.hrColGross,
          S.hrColDeductions,
          S.hrPreviewNet,
          S.status,
        ],
        cellsOf: (context, e) => [
          HrCellText(e.staffName, strong: true),
          _money(context, e.gross),
          _money(
            context,
            e.attendanceDeduction + e.otherDeductions + e.advancePlanned,
          ),
          _money(context, e.netPreview),
          HrStatusCell(
            e.previousNet == null
                ? 'new'
                : (e.netPreview >= (e.previousNet ?? 0) ? 'approved' : 'rejected'),
          ),
        ],
        cardOf: (context, e) => HrRecordCard(
          title: e.staffName,
          subtitle: S.hrPreviewNet,
          fields: [
            HrCardField(S.hrColGross, _money(context, e.gross)),
            HrCardField(S.hrPreviewNet, _money(context, e.netPreview)),
            if (e.absenceDays > 0)
              HrCardField(
                S.hrColLate,
                HrCellText(localizeDigits('${e.absenceDays}')),
              ),
            if (e.paidLeaveDays > 0)
              HrCardField(
                S.hrLeavePaidDays,
                HrCellText(localizeDigits('${e.paidLeaveDays}')),
              ),
            if (e.unpaidLeaveDays > 0)
              HrCardField(
                S.hrLeaveUnpaidDays,
                HrCellText(localizeDigits('${e.unpaidLeaveDays}')),
              ),
            if (e.unpaidLeaveDeduction > 0)
              HrCardField(
                S.hrUnpaidLeaveDeduction,
                _money(context, e.unpaidLeaveDeduction),
              ),
            if (e.advancePlanned > 0)
              HrCardField(S.hrPreviewAdvance, _money(context, e.advancePlanned)),
            if (e.previousNet != null)
              HrCardField(
                S.hrPreviewChangeNet,
                _money(context, e.netPreview - e.previousNet!),
              ),
            for (final line in e.lines.take(6))
              HrCardField(
                line.label.isEmpty ? line.state : line.label,
                HrCellText('${line.state} • ${localizeDigits('${line.amount}')}'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _money(BuildContext context, double value) =>
      AdminMoneyText(value: value, fontSize: AppFontSizes.size11_5);
}
