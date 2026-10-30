import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/localized_date.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/hr/domain/entities/hr_attendance.dart';
import 'package:admin_app/features/hr/domain/entities/hr_leave.dart';
import 'package:admin_app/features/hr/domain/entities/hr_payroll.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_cell_text.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_format.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_record_card.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_status_cell.dart';
import 'package:admin_app/shared/widgets/admin_stat_tile.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/custom_btn.dart';
import 'package:flutter/material.dart';

/// قوائم «يومي» الثلاث: جلساتي، وقسائمي، وطلبات إجازتي.
///
/// القائمة `null` هنا تعني أن السؤال لم يُرسل أو رُفض، وتُعرض جملة صريحة بدل
/// قائمة فارغة: «لا قسائم لي» و«لم تُقرأ قسائمي» شيئان مختلفان عند الموظف.
class HrMyDaySections extends StatelessWidget {
  const HrMyDaySections({
    super.key,
    required this.sessions,
    required this.payslips,
    required this.leaves,
    required this.search,
    required this.onCancelLeave,
  });

  final List<HrAttendanceSession>? sessions;
  final List<HrPayrollStatement>? payslips;
  final List<HrLeaveRequest>? leaves;

  /// بحث شريط الأدمن: يُصفّي القوائم الثلاث كما تكتبها هي، لا كما تخمّن الصفحة.
  final String search;
  final ValueChanged<String> onCancelLeave;

  List<T> _shown<T>(List<T>? rows, bool Function(T row) matches) => [
    for (final row in rows ?? const <Never>[])
      if (matches(row)) row,
  ];

  @override
  Widget build(BuildContext context) {
    final query = search.trim();
    bool hit(String value) =>
        query.isEmpty || value.toLowerCase().contains(query.toLowerCase());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _section(
          context,
          title: S.hrMySessions,
          loaded: sessions,
          unread: S.hrSessionsUnread,
          empty: S.hrNoSessionsYet,
          rows: [
            for (final item in _shown(
              sessions,
              (row) => hit(hrPersonName(row.branchName)),
            ))
              _session(context, item),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _section(
          context,
          title: S.hrMyPayslips,
          loaded: payslips,
          unread: S.hrPayslipsUnread,
          empty: S.hrNoPayslipsYet,
          rows: [
            for (final item in _shown(
              payslips,
              (row) => hit(
                '${localizedMonthName(row.periodMonth)} ${row.periodYear}',
              ),
            ))
              _payslip(context, item),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _section(
          context,
          title: S.hrMyLeaves,
          loaded: leaves,
          unread: S.hrLeavesUnread,
          empty: S.hrNoLeavesYet,
          rows: [
            for (final item in _shown(leaves, (row) => hit(row.typeName)))
              _leave(context, item),
          ],
        ),
      ],
    );
  }

  Widget _section(
    BuildContext context, {
    required String title,
    required List<Object?>? loaded,
    required String unread,
    required String empty,
    required List<Widget> rows,
  }) => AdminSectionCard(
    title: title,
    count: loaded?.length,
    child: loaded == null
        ? _note(context, unread)
        : loaded.isEmpty
        ? _note(context, empty)
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final row in rows)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: row,
                ),
            ],
          ),
  );

  Widget _note(BuildContext context, String message) => Text(
    message,
    style: TextStyle(
      color: adminMutedColor(Theme.of(context)),
      fontSize: AppFontSizes.size11,
      height: AppTextHeights.line1_5,
    ),
  );

  Widget _session(BuildContext context, HrAttendanceSession session) {
    return HrRecordCard(
      title: hrPersonName(session.branchName),
      subtitle: session.note.isEmpty ? null : session.note,
      badge: HrStatusCell(session.isOpen ? 'open' : 'closed'),
      fields: [
        HrCardField(S.hrColStart, HrCellText(session.clockInLocal)),
        HrCardField(
          S.hrColEnd,
          HrCellText(session.isOpen ? S.hrStatusOpen : session.clockOutLocal),
        ),
        HrCardField(
          S.hrColWorked,
          HrCellText(hrDuration(session.workedMinutes), strong: true),
        ),
      ],
    );
  }

  Widget _payslip(BuildContext context, HrPayrollStatement statement) {
    return HrRecordCard(
      title: localizedMonthName(statement.periodMonth),
      subtitle: localizeDigits('${statement.periodYear}'),
      badge: HrStatusCell(statement.runStatus),
      fields: [
        HrCardField(
          S.hrColNet,
          AdminMoneyText(value: statement.net, fontSize: AppFontSizes.size11_5),
        ),
        HrCardField(
          S.hrColDeductions,
          AdminMoneyText(
            value: statement.deductionsTotal,
            fontSize: AppFontSizes.size11_5,
          ),
        ),
      ],
    );
  }

  Widget _leave(BuildContext context, HrLeaveRequest request) {
    final balance = request.balance;
    return HrRecordCard(
      title: hrPersonName(request.typeName),
      subtitle:
          '${localizedDate(request.startsOn)} → ${localizedDate(request.endsOn)}',
      badge: HrStatusCell(request.status),
      fields: [
        HrCardField(S.hrColDays, HrCellText(localizeDigits('${request.days}'))),
        if (balance != null)
          HrCardField(
            S.hrColBalance,
            HrCellText(localizeDigits('${balance.remainingDays}')),
          ),
      ],
      trailing: request.isPending
          ? CustomBtn(
              text: S.hrBtnCancelRequest,
              variant: BtnVariant.outlined,
              onPressed: () => onCancelLeave(request.id),
            )
          : null,
    );
  }
}
