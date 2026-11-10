import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/formatters.dart';
import 'package:admin_app/features/hr/domain/entities/hr_discrepancy.dart';
import 'package:admin_app/features/hr/domain/entities/hr_reference.dart';
import 'package:admin_app/features/hr/presentation/models/hr_list_state.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_cell_text.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_format.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_labels.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_page_scaffold.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_record_card.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_row_button.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_status_cell.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_value_segment.dart';
import 'package:admin_app/shared/widgets/admin_stat_tile.dart';
import 'package:flutter/material.dart';

/// فروق صناديق الكاشير كما حسبها إغلاق الوردية، مع دليلها لا مع تهمة.
///
/// العجز ليس سوء سلوك: الشاشة تعرض أدلة الوردية ومَن نُسب إليه، والقرار وحده
/// — توضيح أو تسوية أو خصم — يُفتح في حواره. ولا زرّ مراجعة لسطر أُغلق قراره.
class HrDiscrepancyView extends StatelessWidget {
  const HrDiscrepancyView({
    super.key,
    required this.state,
    required this.search,
    required this.status,
    required this.branchId,
    required this.branches,
    required this.canReview,
    required this.onStatusChanged,
    required this.onBranchChanged,
    required this.onReview,
    required this.onRetry,
  });

  final HrListState<HrDiscrepancy> state;
  final String search;

  /// حالة الترشيح المرسلة للقاعدة (`null` تعني كل الحالات).
  final String? status;
  final String? branchId;

  /// `null` أن المرجع لم يُقرأ بعد، و`[]` أنه قرئ ولا فرع داخل النطاق: الاثنان
  /// لا يُقرآن «كل الفروع» أمام المدير، فتُقال جملة الغياب بدل شريط ترشيح أجوّف.
  final List<HrBranch>? branches;
  final bool canReview;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String?> onBranchChanged;
  final ValueChanged<HrDiscrepancy> onReview;
  final VoidCallback onRetry;

  static const List<String> _statuses = <String>[
    'pending_review',
    'explained',
    'reconciliation_required',
    'confirmed',
    'rejected',
    'deduction_approved',
    'closed',
  ];

  @override
  Widget build(BuildContext context) {
    return HrPageScaffold<HrDiscrepancy>(
      title: S.hrDiscrepancies,
      subtitle: S.hrDiscrepanciesSubtitle,
      state: state,
      search: search,
      emptyLabel: S.hrEmptyDiscrepancies,
      emptyHint: S.hrEmptyFilterHint,
      emptyIcon: AppIcons.cashier,
      columns: <String>[
        S.hrColEmployee,
        S.hrColBranch,
        S.hrColVariance,
        S.amount,
        S.status,
      ],
      cellsOf: (context, item) => [
        HrCellText(hrPersonName(item.drawerCashierName), strong: true),
        HrCellText(item.branchName, muted: true),
        HrCellText(_variance(item), danger: item.hasShortage),
        AdminMoneyText(value: item.amount, fontSize: AppFontSizes.size11_5),
        HrStatusCell(item.status),
      ],
      cardOf: (context, item) => _card(context, item),
      actionsOf: (context, item) => _decisions(context, item),
      searchOf: (item) =>
          '${item.drawerCashierName} ${item.branchName} ${item.attributedStaffName}',
      onRetry: onRetry,
      filters: _filters(context),
    );
  }

  /// الفرق الموقّع بعلامته: سالبة عند العجز، موجبة عند الزيادة.
  String _variance(HrDiscrepancy item) =>
      '${item.signedVariance < 0 ? '-' : '+'}${formatAmount(item.signedVariance.abs())}';

  Widget _filters(BuildContext context) {
    final options = branches ?? const <HrBranch>[];
    final unread = branches == null;
    return HrFilterStrip(
      children: [
        // An unread reference is never represented as an empty/all-branches filter.
        if (unread)
          HrCellText(S.hrNoBranchesForMe, muted: true)
        else
          HrValueSegment(
            label: S.hrColBranch,
            allLabel: S.hrFilterAllBranches,
            choices: [
              for (final branch in options)
                HrFilterChoice(branch.id, hrBranchName(branch)),
            ],
            selected: branchId,
            onChanged: onBranchChanged,
          ),
        HrValueSegment(
          label: S.hrFilterStatus,
          allLabel: S.hrFilterAll,
          choices: [
            for (final wire in _statuses)
              HrFilterChoice(wire, hrStatusLabel(wire).text),
          ],
          selected: status,
          onChanged: onStatusChanged,
        ),
      ],
    );
  }

  Widget _card(BuildContext context, HrDiscrepancy item) => HrRecordCard(
    title: hrPersonName(item.drawerCashierName),
    subtitle: item.branchName,
    badge: HrStatusCell(item.status),
    fields: [
      HrCardField(S.posShiftOpenedAt, HrCellText(item.openedAtLocal)),
      HrCardField(S.posShiftClosedAt, HrCellText(item.closedAtLocal)),
      HrCardField(
        S.posShiftExpectedCash,
        AdminMoneyText(
          value: item.expectedCash,
          fontSize: AppFontSizes.size11_5,
        ),
      ),
      HrCardField(
        S.posShiftCountedCash,
        AdminMoneyText(
          value: item.countedCash,
          fontSize: AppFontSizes.size11_5,
        ),
      ),
      HrCardField(
        S.hrColVariance,
        HrCellText(_variance(item), danger: item.hasShortage),
      ),
      if (item.evidence.isNotEmpty)
        HrCardField(S.hrFieldEvidence, HrCellText(item.evidence, muted: true)),
      HrCardField(
        S.hrColAttributed,
        HrCellText(
          item.attributedStaffName.isEmpty
              ? S.hrNoOneAttributed
              : item.attributedStaffName,
        ),
      ),
      if (item.hasDeduction)
        HrCardField(
          S.hrDiscrepancyDeduction,
          HrCellText(item.deductionAdjustmentId ?? '', muted: true),
        ),
    ],
    trailing: _trailing(context, item),
  );

  /// قرار واحد لا غير: مراجعة سطر لم يُحسم. سطر أُغلق قراره بلا زرّ.
  List<Widget> _decisions(BuildContext context, HrDiscrepancy item) {
    if (!canReview || !_isReviewable(item)) return const <Widget>[];
    return <Widget>[
      HrRowButton(text: S.hrBtnReview, onPressed: () => onReview(item)),
    ];
  }

  Widget? _trailing(BuildContext context, HrDiscrepancy item) =>
      hrActionsWrap(_decisions(context, item));

  bool _isReviewable(HrDiscrepancy item) =>
      item.isPendingReview || item.status == 'reconciliation_required';
}
