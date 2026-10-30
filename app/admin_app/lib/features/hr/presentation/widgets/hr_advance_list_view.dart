import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/typography.dart';
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
import 'package:flutter/material.dart';

/// قائمة السلف: أزرارها بحالة السلفة في القاعدة لا بحالة الشاشة.
///
/// معلّقةٌ تُراجَع، ومعتمدةٌ تُسلَّم أو تُلغى، ومصروفةٌ تُلغى ما دام الطلب مفتوحًا؛
/// وما بعد الصرف أو الرد أو الإلغاء بلا زرّ. المتبقّي عددٌ أرسلته القاعدة، فلا
/// تطرحه الشاشة من مبلغ.
class HrAdvanceListView extends StatelessWidget {
  const HrAdvanceListView({
    super.key,
    required this.state,
    required this.search,
    required this.canReview,
    required this.people,
    required this.status,
    required this.staffId,
    required this.onStatusChanged,
    required this.onStaffChanged,
    required this.onApprove,
    required this.onReject,
    required this.onDisburse,
    required this.onCancel,
    required this.onRetry,
  });

  final HrListState<HrAdvance> state;
  final String search;
  final bool canReview;
  final List<HrPersonOption> people;
  final String? status;
  final String? staffId;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String?> onStaffChanged;
  final ValueChanged<HrAdvance> onApprove;
  final ValueChanged<HrAdvance> onReject;
  final ValueChanged<HrAdvance> onDisburse;
  final ValueChanged<HrAdvance> onCancel;
  final VoidCallback onRetry;

  static const List<String> _statuses = <String>[
    'pending',
    'approved',
    'disbursed',
    'settled',
    'rejected',
    'cancelled',
  ];

  @override
  Widget build(BuildContext context) => HrPageScaffold<HrAdvance>(
    title: S.hrAdvances,
    subtitle: S.hrAdvancesSubtitle,
    state: state,
    search: search,
    emptyLabel: S.hrEmptyAdvances,
    columns: <String>[
      S.hrColEmployee,
      S.amount,
      S.hrColInstallment,
      S.hrColRemaining,
      S.status,
    ],
    cellsOf: (context, item) => [
      HrCellText(item.staffName, strong: true),
      _money(item.amount),
      _money(item.installmentAmount),
      _money(item.outstanding),
      HrStatusCell(item.status),
    ],
    cardOf: (context, item) => _card(context, item),
    actionsOf: (context, item) => _decisions(item),
    searchOf: (item) => '${item.staffName} ${item.reason}',
    onRetry: onRetry,
    filters: _filters(context),
  );

  Widget _card(BuildContext context, HrAdvance item) => HrRecordCard(
    title: item.staffName,
    subtitle: hrStatusLabel(item.status).text,
    badge: HrStatusCell(item.status),
    fields: [
      HrCardField(S.amount, _money(item.amount)),
      HrCardField(S.hrColInstallment, _money(item.installmentAmount)),
      HrCardField(S.hrColRemaining, _money(item.outstanding)),
      ...hrNoteFields(reason: item.reason, note: item.reviewNote),
      if (item.requestedBy.isNotEmpty)
        HrCardField(S.hrColRequestedBy, HrCellText(item.requestedBy)),
      if (item.reviewedBy.isNotEmpty)
        HrCardField(S.hrColReviewedBy, HrCellText(item.reviewedBy)),
      if (item.disbursedAt != null)
        HrCardField(
          S.hrColDisbursedAt,
          HrCellText(localizedDate(item.disbursedAt), muted: true),
        ),
    ],
    trailing: hrActionsWrap(_decisions(item)),
  );

  List<Widget> _decisions(HrAdvance item) {
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
    if (item.isApproved) {
      return <Widget>[
        HrRowButton(text: S.hrBtnDisburse, onPressed: () => onDisburse(item)),
        HrRowButton(
          text: S.hrBtnCancelRequest,
          onPressed: () => onCancel(item),
        ),
      ];
    }
    if (item.isDisbursed && item.isOpen) {
      return <Widget>[
        HrRowButton(
          text: S.hrBtnCancelRequest,
          onPressed: () => onCancel(item),
        ),
      ];
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
