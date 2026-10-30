import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/utils/localized_date.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/hr/domain/entities/hr_reference.dart';
import 'package:admin_app/features/hr/domain/entities/hr_schedule.dart';
import 'package:admin_app/features/hr/presentation/models/hr_list_state.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_cell_text.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_date_field.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_filter_scroll.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_format.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_page_scaffold.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_record_card.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_row_button.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_status_cell.dart';
import 'package:admin_app/shared/widgets/admin_segmented_control.dart';
import 'package:admin_app/shared/widgets/custom_btn.dart';
import 'package:flutter/material.dart';

/// جداول العمل: وردية لكل يوم، تُعدَّل ثم تُنشر أو تُلغى.
///
/// النشر والإلغاء لا يُعرضان إلا حيث تسمح بهما حالة السطر، لأن `212` ترفض
/// الانتقال الممنوع برمز `23514`؛ والفرع الذي لم يُقرأ مرجعه يبقى غائبًا عن
/// الترشيح بدل أن يُعرض «كل الفروع» على لا شيء.
class HrScheduleView extends StatelessWidget {
  const HrScheduleView({
    super.key,
    required this.state,
    required this.search,
    required this.canManage,
    required this.branches,
    required this.branchId,
    required this.from,
    required this.to,
    required this.onBranchChanged,
    required this.onFromChanged,
    required this.onToChanged,
    required this.onNew,
    required this.onEdit,
    required this.onPublish,
    required this.onCancel,
    required this.onRetry,
  });

  final HrListState<HrWorkSchedule> state;
  final String search;
  final bool canManage;

  /// `null` أن المرجع لم يُقرأ بعد، و`[]` أن قرئ ولا فرع داخل النطاق.
  final List<HrBranch>? branches;
  final String? branchId;
  final DateTime from;
  final DateTime to;
  final ValueChanged<String?> onBranchChanged;
  final ValueChanged<DateTime> onFromChanged;
  final ValueChanged<DateTime> onToChanged;
  final VoidCallback onNew;
  final ValueChanged<HrWorkSchedule> onEdit;
  final ValueChanged<HrWorkSchedule> onPublish;
  final ValueChanged<HrWorkSchedule> onCancel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return HrPageScaffold<HrWorkSchedule>(
      title: S.hrSchedules,
      subtitle: S.hrSchedulesSubtitle,
      state: state,
      search: search,
      emptyLabel: S.hrEmptySchedules,
      columns: <String>[
        S.hrColEmployee,
        S.hrColBranch,
        S.hrColDay,
        S.hrColStart,
        S.hrColEnd,
        S.hrColWorked,
        S.hrFilterStatus,
      ],
      cellsOf: _cells,
      cardOf: _card,
      actionsOf: (context, schedule) => _decisions(schedule),
      searchOf: (item) => '${item.staffName} ${item.branchName} ${item.day}',
      // الجدول بلا صلاحية إدارة لا يُفتح عليه محرّر: السطر يبقى مقروءًا.
      onTap: canManage ? onEdit : null,
      onRetry: onRetry,
      actions: canManage
          ? [
              CustomBtn(
                text: S.hrBtnNewSchedule,
                variant: BtnVariant.outlined,
                onPressed: onNew,
              ),
            ]
          : const <Widget>[],
      filters: _filters(context),
    );
  }

  List<Widget> _cells(BuildContext context, HrWorkSchedule schedule) => [
    HrCellText(hrPersonName(schedule.staffName), strong: true),
    HrCellText(schedule.branchName),
    // `day` لا `dayLocal`: ردّ الحفظ قد لا يرسل اليوم، والاحتياطية من الطابع.
    HrCellText(_dayOf(schedule.day), muted: true),
    HrCellText(schedule.startLocal),
    HrCellText(schedule.endLocal),
    HrCellText(localizeDigits('${schedule.hours}')),
    HrStatusCell(schedule.status),
  ];

  Widget _card(BuildContext context, HrWorkSchedule schedule) => HrRecordCard(
    title: hrPersonName(schedule.staffName),
    subtitle: schedule.branchName,
    badge: HrStatusCell(schedule.status),
    fields: [
      HrCardField(S.hrColDay, HrCellText(_dayOf(schedule.day))),
      HrCardField(S.hrColStart, HrCellText(schedule.startLocal)),
      HrCardField(S.hrColEnd, HrCellText(schedule.endLocal)),
      HrCardField(
        S.hrColWorked,
        HrCellText(localizeDigits('${schedule.hours}'), strong: true),
      ),
      if (schedule.breakMinutes > 0)
        HrCardField(
          S.hrScheduleBreak,
          HrCellText(hrDuration(schedule.breakMinutes)),
        ),
      if (schedule.note.isNotEmpty)
        HrCardField(S.hrFieldNote, HrCellText(schedule.note, muted: true)),
    ],
    trailing: _transitions(schedule),
    onTap: canManage ? () => onEdit(schedule) : null,
  );

  /// قرارات السطر: مسودةٌ تُنشر أو تُلغى، ومنشورةٌ تُلغى وحدها.
  ///
  /// لا زرّ يبيع محاولة ترفضها القاعدة، ولا صفٌّ على المكتب بلا قرار وهو القرار
  /// نفسه الذي يُضغط على الهاتف.
  List<Widget> _decisions(HrWorkSchedule schedule) => [
    if (canManage && schedule.isDraft)
      HrRowButton(text: S.hrBtnPublish, onPressed: () => onPublish(schedule)),
    if (canManage && (schedule.isDraft || schedule.isPublished))
      HrRowButton(
        text: S.cancel,
        danger: true,
        onPressed: () => onCancel(schedule),
      ),
  ];

  Widget? _transitions(HrWorkSchedule schedule) {
    final decisions = _decisions(schedule);
    if (decisions.isEmpty) return null;
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: decisions,
    );
  }

  Widget _filters(BuildContext context) {
    final options = branches;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (options == null)
          HrCellText(S.hrNoBranchesForMe, muted: true)
        else
          _branchRow(options),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: HrDateField(
                label: S.hrFilterRange,
                value: from,
                onChanged: onFromChanged,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: HrDateField(
                label: S.hrFieldTo,
                value: to,
                onChanged: onToChanged,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _branchRow(List<HrBranch> options) {
    final labels = <String>[
      S.hrFilterAllBranches,
      for (final branch in options) hrBranchName(branch),
    ];
    final found = options.indexWhere((branch) => branch.id == branchId);
    final index = found < 0 ? 0 : found + 1;
    return HrFilterScroll(
      control: AdminSegmentedControl(
        options: labels,
        selected: labels[index],
        onChanged: (label) {
          final next = labels.indexOf(label);
          if (next == index) return;
          onBranchChanged(next == 0 ? null : options[next - 1].id);
        },
      ),
    );
  }

  /// اليوم بالحسابة المعروضة: ما لم يُفهم تاريخًا يُعرض بحرفه كما جاء.
  String _dayOf(String day) => localizedDate(DateTime.tryParse(day));
}
