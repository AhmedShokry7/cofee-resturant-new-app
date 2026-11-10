import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/utils/localized_date.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/hr/domain/entities/hr_leave.dart';
import 'package:admin_app/features/hr/presentation/models/hr_list_state.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_cell_text.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_labels.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_page_scaffold.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_record_card.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_row_button.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_status_cell.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_value_segment.dart';
import 'package:admin_app/shared/widgets/custom_btn.dart';
import 'package:flutter/material.dart';

/// قائمة طلبات الإجازة: قراران فقط، اعتماد أو رفض، ولا يُرسل واحد بلا سبب.
///
/// الأزرار تظهر لسطر `pending` وحده: سطر مراجعة قراره مغلق في القاعدة، وزرّ
/// يفتح عليه محاولة رفضها `212` هو واجهة تكذب على مديرها.
class HrLeaveView extends StatelessWidget {
  const HrLeaveView({
    super.key,
    required this.state,
    required this.search,
    required this.status,
    required this.canReview,
    required this.onStatusChanged,
    required this.onApprove,
    required this.onReject,
    required this.onSetBalance,
    required this.onRetry,
  });

  final HrListState<HrLeaveRequest> state;
  final String search;

  /// حالة الترشيح المرسلة للقاعدة (`null` تعني كل الحالات).
  final String? status;
  final bool canReview;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<HrLeaveRequest> onApprove;
  final ValueChanged<HrLeaveRequest> onReject;
  final VoidCallback onSetBalance;
  final VoidCallback onRetry;

  static const List<String> _statuses = <String>[
    'pending',
    'approved',
    'rejected',
    'cancelled',
  ];

  @override
  Widget build(BuildContext context) {
    return HrPageScaffold<HrLeaveRequest>(
      title: S.hrLeave,
      subtitle: S.hrLeaveSubtitle,
      state: state,
      search: search,
      emptyLabel: S.hrEmptyLeave,
      emptyHint: S.hrEmptyFilterHint,
      emptyIcon: AppIcons.calendarAdd01,
      columns: <String>[
        S.hrColEmployee,
        S.hrColType,
        S.hrColDay,
        S.hrColDays,
        S.status,
      ],
      cellsOf: (context, request) => [
        HrCellText(request.staffName, strong: true),
        HrCellText(request.typeName),
        HrCellText(
          '${localizedDate(request.startsOn)} → ${localizedDate(request.endsOn)}',
          muted: true,
        ),
        HrCellText(localizeDigits('${request.days}')),
        HrStatusCell(request.status),
      ],
      cardOf: (context, request) => _card(context, request),
      searchOf: (request) => '${request.staffName} ${request.typeName}',
      onRetry: onRetry,
      actionsOf: _decisions,
      actions: [
        CustomBtn(
          text: S.hrBtnSetBalance,
          variant: BtnVariant.outlined,
          onPressed: onSetBalance,
        ),
      ],
      filters: _filters(context),
    );
  }

  Widget _filters(BuildContext context) {
    return HrFilterStrip(
      children: [
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

  /// قرارا السطر: اعتماد ورفض لسطر `pending` لمالك صلاحية المراجعة، ولا شيء غيره.
  List<Widget> _decisions(BuildContext context, HrLeaveRequest request) =>
      canReview && request.isPending
      ? [
          HrRowButton(
            text: S.hrBtnApprove,
            onPressed: () => onApprove(request),
          ),
          HrRowButton(
            text: S.hrActionReject,
            danger: true,
            onPressed: () => onReject(request),
          ),
        ]
      : const <Widget>[];

  Widget _card(BuildContext context, HrLeaveRequest request) => HrRecordCard(
    title: request.staffName,
    subtitle: request.typeName,
    badge: HrStatusCell(request.status),
    fields: [
      HrCardField(
        S.hrColDay,
        HrCellText(
          '${localizedDate(request.startsOn)} → ${localizedDate(request.endsOn)}',
        ),
      ),
      HrCardField(S.hrColDays, HrCellText(localizeDigits('${request.days}'))),
      if (request.reason.isNotEmpty)
        HrCardField(S.hrReasonLabel, HrCellText(request.reason, muted: true)),
    ],
    trailing: hrActionsWrap(_decisions(context, request)),
  );
}
