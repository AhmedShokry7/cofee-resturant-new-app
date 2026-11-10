import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/utils/localized_date.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/hr/domain/entities/hr_attendance.dart';
import 'package:admin_app/features/hr/domain/entities/hr_reference.dart';
import 'package:admin_app/features/hr/domain/entities/hr_refusal.dart';
import 'package:admin_app/features/hr/presentation/manager/hr_attendance_state.dart';
import 'package:admin_app/features/hr/presentation/models/hr_load_status.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_cell_text.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_date_field.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_directory.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_format.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_labels.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_record_card.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_refusal_note.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_row_button.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_status_cell.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_value_segment.dart';
import 'package:admin_app/shared/widgets/admin_directory_panel.dart';
import 'package:admin_app/shared/widgets/admin_page_frame.dart';
import 'package:admin_app/shared/widgets/admin_page_header.dart';
import 'package:admin_app/shared/widgets/admin_segmented_control.dart';
import 'package:admin_app/shared/widgets/admin_state_view.dart';
import 'package:admin_app/shared/widgets/custom_btn.dart';
import 'package:flutter/material.dart';

/// الحضور بصفحيتين لحالة واحدة: جلسات البصمة، ثم تصحيحاتها المعلّقة.
///
/// `HrAttendanceState` ليست `HrListState`، لهذا يُركّب الهيكل هنا كما يركّبه
/// `HrPageScaffold` داخله: الرأس، ثم رفض القاعدة وإيصالها، ثم الترشيحات، ثم
/// اللوحة. والعدد المعلّق لا يُعرض صفرًا قبل أن تُقرأ التصحيحات.
class HrAttendanceView extends StatefulWidget {
  const HrAttendanceView({
    super.key,
    required this.state,
    required this.search,
    required this.canReview,
    required this.branches,
    required this.from,
    required this.to,
    required this.branchId,
    required this.correctionStatus,
    required this.onBranchChanged,
    required this.onCorrectionStatusChanged,
    required this.onFromChanged,
    required this.onToChanged,
    required this.onRequestCorrection,
    required this.onApprove,
    required this.onReject,
    required this.onRetry,
  });

  final HrAttendanceState state;
  final String search;
  final bool canReview;

  /// `null` أن المرجع لم يُقرأ، و`[]` أن قرئ ولا فرع في النطاق: لا يُعرضان واحدًا.
  final List<HrBranch>? branches;
  final DateTime from;
  final DateTime to;
  final String? branchId;
  final String? correctionStatus;
  final ValueChanged<String?> onBranchChanged;
  final ValueChanged<String?> onCorrectionStatusChanged;
  final ValueChanged<DateTime> onFromChanged;
  final ValueChanged<DateTime> onToChanged;

  /// `null` أن الطلب من رأس الشاشة على جلسة لم تُحدَّد بعد.
  final ValueChanged<HrAttendanceRow?> onRequestCorrection;
  final ValueChanged<HrAttendanceCorrection> onApprove;
  final ValueChanged<HrAttendanceCorrection> onReject;
  final VoidCallback onRetry;

  @override
  State<HrAttendanceView> createState() => _HrAttendanceViewState();
}

class _HrAttendanceViewState extends State<HrAttendanceView> {
  static const List<String> _corrections = <String>[
    'pending',
    'approved',
    'rejected',
    'cancelled',
  ];
  bool _onCorrections = false;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return AdminPageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminPageHeader(
            title: S.hrAttendance,
            subtitle: S.hrAttendanceSubtitle,
            progress: state.isWriting || state.isLoading ? 0 : null,
            progressLabel: state.isWriting ? S.saving : null,
            actions: [
              CustomBtn(
                text: S.hrBtnRequestCorrection,
                variant: BtnVariant.outlined,
                onPressed: () => widget.onRequestCorrection(null),
              ),
            ],
          ),
          HrRefusalNote(refusal: state.failure),
          if (state.receipt != null) ...[
            const SizedBox(height: AppSpacing.xs),
            HrReceiptNote(receipt: state.receipt!),
          ],
          const SizedBox(height: AppSpacing.sm),
          AdminSegmentedControl(
            options: _tabs,
            selected: _tabs[_onCorrections ? 1 : 0],
            onChanged: (label) =>
                setState(() => _onCorrections = _tabs.indexOf(label) == 1),
          ),
          const SizedBox(height: AppSpacing.sm),
          _filters(),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: _onCorrections ? _correctionsPage() : _sessionsPage(),
          ),
        ],
      ),
    );
  }

  /// عدّاد المعلّقات بعد القراءة فقط: رقمٌ لم تقله القاعدة غائب لا صفر.
  List<String> get _tabs {
    final count = widget.state.pendingCorrections;
    final corrections = widget.state.status == HrLoadStatus.ready
        ? '${S.hrSectionCorrections} ${localizeDigits('$count')}'
        : S.hrSectionCorrections;
    return <String>[S.hrSectionAttendance, corrections];
  }

  Widget _filters() {
    final branches = widget.branches;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (branches == null)
          HrCellText(S.hrNoBranchesForMe, muted: true)
        else
          HrFilterStrip(
            children: [
              HrValueSegment(
                label: S.hrColBranch,
                allLabel: S.hrFilterAllBranches,
                choices: [
                  for (final branch in branches)
                    HrFilterChoice(branch.id, hrBranchName(branch)),
                ],
                selected: widget.branchId,
                onChanged: widget.onBranchChanged,
              ),
            ],
          ),
        const SizedBox(height: AppSpacing.sm),
        if (_onCorrections)
          HrFilterStrip(
            children: [
              HrValueSegment(
                label: S.hrFilterStatus,
                allLabel: S.hrFilterAll,
                choices: [
                  for (final wire in _corrections)
                    HrFilterChoice(wire, hrStatusLabel(wire).text),
                ],
                selected: widget.correctionStatus,
                onChanged: widget.onCorrectionStatusChanged,
              ),
            ],
          )
        else
          Row(
            children: [
              Expanded(
                child: HrDateField(
                  label: S.hrFilterRange,
                  value: widget.from,
                  onChanged: widget.onFromChanged,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: HrDateField(
                  label: S.hrFieldTo,
                  value: widget.to,
                  onChanged: widget.onToChanged,
                ),
              ),
            ],
          ),
      ],
    );
  }

  /// لوحة الصفحتين: ما لم يُقرأ بعد لا يُعرض قائمة فارغة، والرفض يُعاد بسببه.
  Widget _directory<X>({
    required List<X> items,
    required List<String> columns,
    required List<Widget> Function(BuildContext, X) cellsOf,
    required Widget Function(BuildContext, X) cardOf,
    required String Function(X) searchOf,
    required String emptyLabel,
    List<Widget> Function(BuildContext, X)? actionsOf,
    ValueChanged<X>? onTap,
  }) {
    final state = widget.state;
    if (state.isLoading && items.isEmpty) return const AdminLoadingView();
    if (state.status == HrLoadStatus.failure && items.isEmpty) {
      return AdminFailureView(
        message: state.failure == null
            ? null
            : hrRefusalMessage(state.failure!),
        onRetry: widget.onRetry,
      );
    }
    return AdminDirectoryPanel(
      child: HrDirectory<X>(
        items: items,
        columns: columns,
        cellsOf: cellsOf,
        cardOf: cardOf,
        actionsOf: actionsOf,
        searchOf: searchOf,
        search: widget.search,
        emptyLabel: emptyLabel,
        emptyHint: S.hrEmptyFilterHint,
        emptyIcon: AppIcons.clock01,
        onTap: onTap,
      ),
    );
  }

  Widget _sessionsPage() => _directory<HrAttendanceRow>(
    items: widget.state.rows,
    emptyLabel: S.hrEmptyAttendance,
    columns: <String>[
      S.hrColEmployee,
      S.hrColBranch,
      S.hrColDay,
      S.hrColStart,
      S.hrColEnd,
      S.hrColWorked,
      S.hrColLate,
      S.hrColSession,
    ],
    cellsOf: _sessionCells,
    cardOf: _sessionCard,
    searchOf: (row) => '${row.staffName} ${row.branchName} ${row.dayLocal}',
    onTap: (row) => widget.onRequestCorrection(row),
  );

  List<Widget> _sessionCells(BuildContext context, HrAttendanceRow row) => [
    HrCellText(hrPersonName(row.staffName), strong: true),
    HrCellText(row.branchName),
    HrCellText(localizedDate(DateTime.tryParse(row.dayLocal)), muted: true),
    HrCellText(row.clockInLocal),
    HrCellText(row.isOpen ? S.hrStatusOpen : row.clockOutLocal),
    HrCellText(hrDuration(row.workedMinutes)),
    HrCellText(hrDuration(row.lateMinutes), danger: row.lateMinutes > 0),
    _missingClockOut(row),
  ];

  /// علامة الانصراف الناقص: لون الخطأ على «مفتوح»، لأن الجلسة لم تُغلق.
  Widget _missingClockOut(HrAttendanceRow row) => HrCellText(
    row.isOpen ? S.hrStatusOpen : S.hrStatusClosed,
    danger: row.isMissingClockOut,
    muted: !row.isMissingClockOut,
  );

  Widget _sessionCard(BuildContext context, HrAttendanceRow row) =>
      HrRecordCard(
        title: hrPersonName(row.staffName),
        subtitle: row.branchName,
        badge: HrStatusCell(row.isOpen ? 'open' : 'closed'),
        fields: [
          HrCardField(
            S.hrColDay,
            HrCellText(localizedDate(DateTime.tryParse(row.dayLocal))),
          ),
          HrCardField(S.hrColStart, HrCellText(row.clockInLocal)),
          HrCardField(
            S.hrColEnd,
            HrCellText(row.isOpen ? S.hrStatusOpen : row.clockOutLocal),
          ),
          HrCardField(
            S.hrColWorked,
            HrCellText(hrDuration(row.workedMinutes), strong: true),
          ),
          if (row.lateMinutes > 0)
            HrCardField(
              S.hrColLate,
              HrCellText(hrDuration(row.lateMinutes), danger: true),
            ),
        ],
        onTap: () => widget.onRequestCorrection(row),
      );

  Widget _correctionsPage() => _directory<HrAttendanceCorrection>(
    items: widget.state.corrections,
    emptyLabel: S.hrEmptyCorrections,
    columns: <String>[
      S.hrColEmployee,
      S.hrColBranch,
      S.hrColSession,
      S.hrColStart,
      S.hrColEnd,
      S.hrReasonLabel,
      S.hrFilterStatus,
    ],
    cellsOf: _correctionCells,
    cardOf: _correctionCard,
    actionsOf: (context, item) => _decisions(item),
    searchOf: (item) => '${item.staffName} ${item.branchName} ${item.reason}',
  );

  List<Widget> _correctionCells(
    BuildContext context,
    HrAttendanceCorrection correction,
  ) => [
    HrCellText(hrPersonName(correction.staffName), strong: true),
    // الفرع عمودٌ مستقل: صفّ التصحيح يُقرأ بلا فرع مثلما يُقرأ الجلسة.
    HrCellText(correction.branchName),
    // لا يوم في entity التصحيح، فيُقرأ طابع الطلب وكيلًا عن جلسته.
    HrCellText(correction.createdAtLocal, muted: true),
    HrCellText(_stamp(correction.proposedClockInLocal)),
    HrCellText(_stamp(correction.proposedClockOutLocal)),
    HrCellText(correction.reason, muted: true),
    HrStatusCell(correction.status),
  ];

  Widget _correctionCard(
    BuildContext context,
    HrAttendanceCorrection correction,
  ) => HrRecordCard(
    title: hrPersonName(correction.staffName),
    subtitle: correction.branchName,
    badge: HrStatusCell(correction.status),
    fields: [
      HrCardField(S.hrColSession, HrCellText(correction.createdAtLocal)),
      HrCardField(
        S.hrColStart,
        HrCellText(_stamp(correction.proposedClockInLocal)),
      ),
      HrCardField(
        S.hrColEnd,
        HrCellText(_stamp(correction.proposedClockOutLocal)),
      ),
      if (correction.reason.isNotEmpty)
        HrCardField(
          S.hrReasonLabel,
          HrCellText(correction.reason, muted: true),
        ),
    ],
    trailing: _trailing(_decisions(correction)),
  );

  /// قرارٌ لا يُعرض إلا على معلّق وبيد صاحبه: سطر حُسم قراره مغلق في القاعدة.
  List<Widget> _decisions(HrAttendanceCorrection correction) {
    if (!widget.canReview || !correction.isPending) return const <Widget>[];
    return <Widget>[
      HrRowButton(
        text: S.hrBtnApprove,
        onPressed: () => widget.onApprove(correction),
      ),
      HrRowButton(
        text: S.hrActionReject,
        danger: true,
        onPressed: () => widget.onReject(correction),
      ),
    ];
  }

  Widget? _trailing(List<Widget> actions) => hrActionsWrap(actions);

  /// بصمة مقترحة لم تُكتب تُلفظ «لم تُختَر»: الخلية الفارغة تُقرأ نسيانًا.
  String _stamp(String value) => value.isEmpty ? S.hrNotSelected : value;
}
