import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/formatters.dart';
import 'package:admin_app/core/utils/localized_date.dart';
import 'package:admin_app/features/hr/domain/entities/hr_finance.dart';
import 'package:admin_app/features/hr/presentation/models/hr_list_state.dart';
import 'package:admin_app/features/hr/presentation/models/hr_person_option.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_cell_text.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_labels.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_page_scaffold.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_record_card.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_row_button.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_status_cell.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_value_segment.dart';
import 'package:admin_app/shared/widgets/admin_stat_tile.dart';
import 'package:admin_app/shared/widgets/custom_btn.dart';
import 'package:flutter/material.dart';

/// قائمة التسويات: ما يُقبل وما يُرفض وما يُعكس، والسبب حين لا ينعكس شيء.
///
/// التسوية المعتمدة التي حفرتها لقطة رواتب لا تُعكس؛ والموضع الذي كان زرّها
/// يطبع سببها، لأن زرًّا ميتًا يخدع وفراغًا بلا سببٍ يترك المدير يسأل القاعدة.
class HrAdjustmentListView extends StatelessWidget {
  const HrAdjustmentListView({
    super.key,
    required this.state,
    required this.search,
    required this.canReview,
    required this.canManage,
    required this.people,
    required this.status,
    required this.staffId,
    required this.source,
    required this.onStatusChanged,
    required this.onStaffChanged,
    required this.onSourceChanged,
    required this.onNewAdjustment,
    required this.onApprove,
    required this.onReject,
    required this.onReverse,
    required this.onRetry,
  });

  final HrListState<HrAdjustment> state;
  final String search;
  final bool canReview;

  /// صلاحية إضافة تسوية؛ تُمرَّر كما تملكها الصفحة.
  final bool canManage;
  final List<HrPersonOption> people;
  final String? status;
  final String? staffId;
  final String? source;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String?> onStaffChanged;
  final ValueChanged<String?> onSourceChanged;
  final VoidCallback onNewAdjustment;
  final ValueChanged<HrAdjustment> onApprove;
  final ValueChanged<HrAdjustment> onReject;
  final ValueChanged<HrAdjustment> onReverse;
  final VoidCallback onRetry;

  static const List<String> _statuses = <String>[
    'pending',
    'approved',
    'reversed',
    'rejected',
    'cancelled',
  ];
  static const List<String> _sources = <String>[
    'manual',
    'cashier_discrepancy',
    'payroll_correction',
    'adjustment_reversal',
  ];

  @override
  Widget build(BuildContext context) => HrPageScaffold<HrAdjustment>(
    title: S.hrSectionAdjustments,
    subtitle: S.hrAdvancesSubtitle,
    state: state,
    search: search,
    emptyLabel: S.hrEmptyAdjustments,
    columns: <String>[
      S.hrColEmployee,
      S.hrColType,
      S.amount,
      S.hrColSource,
      S.status,
    ],
    cellsOf: (context, item) => [
      HrCellText(item.staffName, strong: true),
      HrCellText(hrKindLabel(item.kind)),
      _money(item.amount),
      HrCellText(hrSourceLabel(item.sourceType), muted: true),
      HrStatusCell(item.status),
    ],
    cardOf: (context, item) => _card(context, item),
    actionsOf: (context, item) => _decisions(item),
    searchOf: (item) => '${item.staffName} ${item.reason}',
    onRetry: onRetry,
    actions: canManage
        ? <Widget>[
            CustomBtn(
              text: S.hrBtnNewAdjustment,
              variant: BtnVariant.outlined,
              onPressed: onNewAdjustment,
            ),
          ]
        : const <Widget>[],
    filters: _filters(context),
  );

  Widget _card(BuildContext context, HrAdjustment item) => HrRecordCard(
    title: item.staffName,
    subtitle: hrKindLabel(item.kind),
    badge: HrStatusCell(item.status),
    fields: [
      HrCardField(S.amount, _money(item.amount)),
      if (item.quantity != null)
        HrCardField(S.hrColQuantity, HrCellText(formatAmount(item.quantity!))),
      HrCardField(
        S.hrColSource,
        HrCellText(hrSourceLabel(item.sourceType), muted: true),
      ),
      if (item.effectiveDate != null)
        HrCardField(
          S.hrAdjustmentEffective,
          HrCellText(localizedDate(item.effectiveDate), muted: true),
        ),
      ...hrNoteFields(reason: item.reason, note: item.reviewNote),
      if (item.isApproved && !item.canReverse)
        HrCardField(
          S.hrBtnReverse,
          HrCellText(S.hrAdjustmentInSnapshot, muted: true),
        ),
    ],
    trailing: hrActionsWrap(_decisions(item)),
  );

  List<Widget> _decisions(HrAdjustment item) {
    if (!canReview) return const <Widget>[];
    if (item.isPending) {
      return <Widget>[
        HrRowButton(text: S.hrBtnApprove, onPressed: () => onApprove(item)),
        HrRowButton(
          text: S.hrActionReject,
          danger: true,
          onPressed: () => onReject(item),
        ),
      ];
    }
    if (item.canReverse) {
      return <Widget>[
        HrRowButton(
          text: S.hrBtnReverse,
          danger: true,
          onPressed: () => onReverse(item),
        ),
      ];
    }
    if (item.isApproved) {
      return <Widget>[HrCellText(S.hrAdjustmentInSnapshot, muted: true)];
    }
    return const <Widget>[];
  }

  Widget _filters(BuildContext context) => HrFilterStrip(
    children: [
      HrValueSegment(
        choices: [
          for (final wire in _statuses)
            HrFilterChoice(wire, hrStatusLabel(wire).text),
        ],
        allLabel: S.hrFilterAll,
        selected: status,
        onChanged: onStatusChanged,
      ),
      HrValueSegment(
        choices: [
          for (final wire in _sources)
            HrFilterChoice(wire, hrSourceLabel(wire)),
        ],
        allLabel: S.hrFilterAllSources,
        selected: source,
        onChanged: onSourceChanged,
      ),
      HrValueSegment(
        choices: [for (final p in people) HrFilterChoice(p.id, p.name)],
        allLabel: S.hrFilterAllEmployees,
        selected: staffId,
        onChanged: onStaffChanged,
      ),
    ],
  );

  Widget _money(double value) =>
      AdminMoneyText(value: value, fontSize: AppFontSizes.size11_5);
}
