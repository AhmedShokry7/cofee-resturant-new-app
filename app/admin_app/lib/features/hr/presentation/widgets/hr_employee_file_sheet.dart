import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/formatters.dart';
import 'package:admin_app/core/utils/localized_date.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/hr/domain/entities/hr_employee.dart';
import 'package:admin_app/features/hr/domain/entities/hr_employee_file.dart';
import 'package:admin_app/features/hr/domain/entities/hr_refusal.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_cell_text.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_format.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_labels.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_record_card.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_refusal_note.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_status_cell.dart';
import 'package:admin_app/shared/widgets/admin_dialog_chrome.dart';
import 'package:admin_app/shared/widgets/admin_labeled_value.dart';
import 'package:admin_app/shared/widgets/admin_stat_tile.dart';
import 'package:admin_app/shared/widgets/admin_status_badge.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/custom_btn.dart';
import 'package:flutter/material.dart';

/// ملف موظف واحد فوق دليله: سجل ارتباطه، ثم قسم لكل ما سمحت القاعدة بقراءته.
///
/// يفرّق كل قسم بين «لم يُقرأ» و«لا سجل»: حضور `null`means أن صلاحيته انتفت لدى
/// هذا القارئ، وقائمة فارغة تعني أنه لا جلسة له. أما تركيبة الأجر فتُعرض بحرف
/// القاعدة حين كانت خارج الصلاحية، فلا تحجب الشاشة قرارًا لها.
class HrEmployeeFileSheet extends StatelessWidget {
  const HrEmployeeFileSheet({
    super.key,
    required this.file,
    required this.onClose,
    this.onEdit,
    this.onEditCompensation,
    this.onOpenOffboarding,
    this.refusal,
  });

  final HrEmployeeFile file;
  final VoidCallback onClose;

  /// تمرّرها الصفحة لمن يملك كتابة التوظيف فقط؛ السطر يبقى مرئيًا لغيره.
  final VoidCallback? onEdit;

  /// ولمن يملك `hr.compensation.manage` وحده؛ الصلاحيتان منفصلتان في 212،
  /// فلا يُفتح محرّر الأجر لمن يعدّل العقد ولا العكس.
  final VoidCallback? onEditCompensation;

  /// لمن يملك كتابة إنهاء الخدمة: يفتح لوحة الإنهاء من الملف.
  final VoidCallback? onOpenOffboarding;

  /// رفض القاعدة بعد كتابة من هذا الملف: الغطاء يحجب الدليل الذي تحته، فالحرف
  /// الذي قالته `42501` أو `23514` يُعرض هنا لا خلفه.
  final HrRefusal? refusal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final job = file.employee.employment;
    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: AppDimensions.dialogBodyWidthExtra,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: adminCardBorderColor(theme)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AdminDialogHeader(
                title: hrPersonName(file.employee.fullName),
                subtitle:
                    '${localizedDate(job.hiredOn)} • ${hrEmploymentTypeLabel(job.employmentType)}',
                onClose: onClose,
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      HrRefusalNote(refusal: refusal),
                      _identity(context),
                      if (onEdit != null) _editButton(),
                      ..._sections(context),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

/// أقسام الملف الستة التي تُقرأ قوائمها، ثم الأجر لأنه قسم بحالة خاصة.
  List<Widget> _sections(BuildContext context) {
    final f = file;
    return <Widget>[
      _section(context, S.hrFileAttendance, f.attendance, S.hrEmptyAttendance, [
        for (final s in f.attendance ?? const <HrAttendanceBrief>[])
          _row(hrPersonName(s.branchName), s.isOpen ? 'open' : 'closed', [
            (S.hrColStart, _text(s.clockInLocal)),
            (S.hrColEnd, _text(s.clockOutLocal)),
          ]),
      ]),
      _section(context, S.hrFileLeave, f.leave, S.hrEmptyLeave, [
        for (final l in f.leave ?? const <HrLeaveBrief>[])
          _row(hrPersonName(l.typeName), l.status, [
            (
              S.hrColDay,
              _text(
                '${localizedDate(l.startsOn)} → ${localizedDate(l.endsOn)}',
              ),
            ),
            (S.hrColDays, _text(localizeDigits('${l.days}'))),
          ]),
      ]),
      _section(context, S.hrFilePayroll, f.payslips, S.hrEmptyPayroll, [
        for (final p in f.payslips ?? const <HrPayslipSummary>[])
          _row(
            '${localizedMonthName(p.periodMonth)} ${localizeDigits('${p.periodYear}')}',
            p.status,
            [
              (S.hrColGross, _money(p.gross)),
              (S.hrColDeductions, _money(p.deductionsTotal)),
              (S.hrColNet, _money(p.net)),
            ],
          ),
      ]),
      _section(context, S.hrFileAdvances, f.advances, S.hrEmptyAdvances, [
        for (final a in f.advances ?? const <HrAdvanceBrief>[])
          _row(localizedDate(a.createdAt), a.status, [
            (S.amount, _money(a.amount)),
            (S.hrColRemaining, _money(a.outstanding)),
          ]),
      ]),
      _section(
        context,
        S.hrFileAdjustments,
        f.adjustments,
        S.hrEmptyAdjustments,
        [
          for (final j in f.adjustments ?? const <HrAdjustmentBrief>[])
            _row(hrKindLabel(j.kind), j.status, [
              (S.amount, _money(j.amount)),
              (S.hrColSource, _text(hrSourceLabel(j.sourceType))),
              (S.hrAdjustmentEffective, _text(localizedDate(j.effectiveDate))),
            ]),
        ],
      ),
      _section(context, S.hrFileShifts, f.cashierShifts, S.hrEmptyList, [
        for (final s in f.cashierShifts ?? const <HrCashierShift>[])
          HrRecordCard(
            title: s.openedAtLocal,
            subtitle: s.closedAtLocal.isEmpty ? null : s.closedAtLocal,
            badge: HrStatusCell(s.status),
            fields: [
              // العجز سالب: لونه يقولها قبل أن يقرأ المدير الرمز.
              HrCardField(
                S.hrColVariance,
                HrCellText(formatAmount(s.variance), danger: s.hasShortage),
              ),
            ],
          ),
      ]),
      if (onOpenOffboarding != null) _offboardingButton(),
      _compensation(context),
    ];
  }

  /// سجل الارتباط والأدوار: الرقم والقسم والمسمى، ورمز كل دور كما أرسلته القاعدة.
  Widget _identity(BuildContext context) {
    final job = file.employee.employment;
    return AdminSectionCard(
      title: S.hrEmploymentHistory,
      trailing: HrStatusCell(job.employmentStatus),
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.sm,
        children: [
          AdminLabeledValue(
            label: S.hrColEmployeeNumber,
            child: HrCellText(job.employeeNumber),
          ),
          AdminLabeledValue(
            label: S.hrColDepartment,
            child: HrCellText(job.department),
          ),
          AdminLabeledValue(
            label: S.hrColJobTitle,
            child: HrCellText(job.jobTitle),
          ),
          for (final role in file.employee.roles)
            AdminStatusBadge(
              label: role.code.isEmpty
                  ? hrBilingualName(nameAr: role.nameAr, nameEn: role.nameEn)
                  : role.code,
              color: AppColor.adminInfo,
            ),
        ],
      ),
    );
  }

  /// زرّ تعديل الارتباط: لا يُمرَّر إلا لمن يملك كتابته، والسطر يبقى مرئيًا.
  Widget _editButton() => Align(
    alignment: AlignmentDirectional.centerEnd,
    child: Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: CustomBtn(
        text: S.edit,
        variant: BtnVariant.outlined,
        onPressed: onEdit,
      ),
    ),
  );

  /// قسم بحالتيه: لم يُقرأ بحرف قارئه، وخالٍ بسجلّاته لا بأصفار.
  Widget _section(
    BuildContext context,
    String title,
    List<Object?>? loaded,
    String empty,
    List<Widget> rows,
  ) => _card(
    title,
    loaded?.length,
    loaded == null
        ? _note(context, S.hrFileUnread)
        : loaded.isEmpty
        ? _note(context, empty)
        : _stacked(rows),
  );

  /// تركيبة الأجر وتاريخها، أو حرف القاعدة حين كانت خارج الصلاحية.
  Widget _compensation(BuildContext context) {
    if (!file.canSeeCompensation) {
      return _card(
        S.hrFileCompensation,
        null,
        _note(context, S.hrFileCompensationHidden),
      );
    }
    final current = file.currentCompensation;
    final rows = <Widget>[
      if (current != null) _payRow(current),
      for (final past in file.compensationHistory)
        if (past.id != current?.id) _payRow(past),
    ];
    // محرّر التركيبة بيد صاحبه وحده، وفوق السطور لا بدلها: من يقرأ لا يُمنع لأن
    // أحدًا لم يكتب له صلاحية الكتابة، ومن يكتب يرى ما كُتب قبله.
    return _card(
      S.hrFileCompensation,
      rows.isEmpty ? null : rows.length,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (onEditCompensation != null) _compensationButton(),
          if (rows.isEmpty) _note(context, S.hrEmptyList) else _stacked(rows),
        ],
      ),
    );
  }

  /// زرّ ضبط الأجر: الحوار يحفظ، والقاعدة ترفض بتاريخ يرجع قبل الساري.
  Widget _compensationButton() => Align(
    alignment: AlignmentDirectional.centerEnd,
    child: Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: CustomBtn(
        text: S.hrBtnSetCompensation,
        variant: BtnVariant.outlined,
        onPressed: onEditCompensation,
      ),
    ),
  );

  /// زرّ إنهاء الخدمة: يفتح لوحة الإنهاء للموظف.
  Widget _offboardingButton() => Align(
    alignment: AlignmentDirectional.centerEnd,
    child: Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: CustomBtn(
        text: S.hrOffboarding,
        variant: BtnVariant.outlined,
        onPressed: onOpenOffboarding,
      ),
    ),
  );

  /// سطر أجر: الأساسي والبدلات التي أرسلتها القاعدة فقط، وفترة سريانه.
  Widget _payRow(HrCompensation entry) =>
      _row(S.hrCompensationTitle, entry.isCurrent ? 'active' : 'closed', [
        (S.hrFieldBasicPay, _money(entry.basicSalary)),
        (
          S.hrCompensationEffectiveFrom,
          _text(localizedDate(entry.effectiveFrom)),
        ),
        if (entry.effectiveTo != null)
          (S.hrFieldTo, _text(localizedDate(entry.effectiveTo))),
        if (entry.housingAllowance != null)
          (S.hrCompensationHousing, _money(entry.housingAllowance!)),
        if (entry.transportAllowance != null)
          (S.hrCompensationTransport, _money(entry.transportAllowance!)),
        if (entry.otherAllowance != null)
          (S.hrCompensationOther, _money(entry.otherAllowance!)),
      ]);

  /// سطر قسم: عنوانه وحالته وحقوله بترتيب قراءتها.
  Widget _row(String title, String? status, List<(String, Widget)> fields) =>
      HrRecordCard(
        title: title,
        badge: status == null ? null : HrStatusCell(status),
        fields: [
          for (final (label, value) in fields) HrCardField(label, value),
        ],
      );

  /// رقم بمعلَم الريال، لا نصّ: الأجر والبدلات والسلف كلُّها تُقرأ كذلك.
  Widget _money(double value) =>
      AdminMoneyText(value: value, fontSize: AppFontSizes.size11_5);

  Widget _text(String value, {bool muted = false}) =>
      HrCellText(value, muted: muted);

  Widget _card(String title, int? count, Widget child) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.md),
    child: AdminSectionCard(title: title, count: count, child: child),
  );

  Widget _stacked(List<Widget> rows) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final row in rows)
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: row,
        ),
    ],
  );

  Widget _note(BuildContext context, String message) => Text(
    message,
    style: TextStyle(
      color: adminMutedColor(Theme.of(context)),
      fontSize: AppFontSizes.size11,
      height: AppTextHeights.line1_5,
    ),
  );
}
