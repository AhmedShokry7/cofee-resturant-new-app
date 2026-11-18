import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/features/hr/payroll/domain/hr_payroll_models.dart';
import 'package:admin_app/features/hr/payroll/manager/hr_payroll_cubit.dart';
import 'package:admin_app/features/hr/payroll/manager/hr_payroll_state.dart';
import 'package:admin_app/shared/widgets/admin_page_frame.dart';
import 'package:admin_app/shared/widgets/admin_page_header.dart';
import 'package:admin_app/shared/widgets/admin_state_view.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';

class HrPayrollPage extends StatefulWidget {
  const HrPayrollPage({
    super.key,
    required this.canRead,
    required this.canPrepare,
    required this.canApprove,
    required this.canPay,
    this.cubit,
  });

  final bool canRead;
  final bool canPrepare;
  final bool canApprove;
  final bool canPay;
  final HrPayrollCubit? cubit;

  @override
  State<HrPayrollPage> createState() => _HrPayrollPageState();
}

class _HrPayrollPageState extends State<HrPayrollPage> {
  late final HrPayrollCubit _cubit;
  late final bool _ownsCubit;

  @override
  void initState() {
    super.initState();
    _ownsCubit = widget.cubit == null;
    _cubit = widget.cubit ?? HrPayrollCubit();
    if (widget.canRead) _cubit.load();
  }

  @override
  void dispose() {
    if (_ownsCubit) _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocProvider.value(
    value: _cubit,
    child: BlocBuilder<HrPayrollCubit, HrPayrollState>(
      builder: (context, state) {
        if (!widget.canRead) {
          return AdminFailureView(
            message: _txt(
              'لا تملك صلاحية عرض الرواتب',
              'You cannot view payroll',
            ),
          );
        }
        if (state.status == HrPayrollStatus.loading && state.runs.isEmpty) {
          return const AdminLoadingView();
        }
        if (state.status == HrPayrollStatus.failure && state.runs.isEmpty) {
          return AdminFailureView(
            message: state.error ?? '',
            onRetry: _cubit.load,
          );
        }
        return AdminPageFrame(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AdminPageHeader(
                title: _txt('الرواتب', 'Payroll'),
                subtitle: _txt(
                  'مسير شهري موحّد على مستوى الشركة؛ الصرف يُسجّل بعد الدفع الفعلي خارج النظام.',
                  'One consolidated company-wide monthly run. Recording payment follows an external transfer.',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (widget.canPrepare) _periodControls(state),
              if (state.error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Text(
                    state.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (state.preview != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Expanded(child: _preview(state.preview!, state.actionBusy)),
              ] else ...[
                const SizedBox(height: AppSpacing.sm),
                Expanded(child: _runList(state)),
              ],
            ],
          ),
        );
      },
    ),
  );

  Widget _periodControls(HrPayrollState state) {
    final yearNow = DateTime.now().year;
    final years = [for (var year = yearNow; year >= yearNow - 7; year--) year];
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 145,
          child: DropdownButtonFormField<int>(
            initialValue: state.selectedMonth,
            decoration: InputDecoration(
              labelText: _txt('الشهر', 'Month'),
              isDense: true,
            ),
            items: [
              for (var month = 1; month <= 12; month++)
                DropdownMenuItem(value: month, child: Text(_month(month))),
            ],
            onChanged: state.actionBusy
                ? null
                : (value) {
                    if (value != null) _cubit.selectMonth(value);
                  },
          ),
        ),
        SizedBox(
          width: 110,
          child: DropdownButtonFormField<int>(
            initialValue: state.selectedYear,
            decoration: InputDecoration(
              labelText: _txt('السنة', 'Year'),
              isDense: true,
            ),
            items: [
              for (final year in years)
                DropdownMenuItem(value: year, child: Text('$year')),
            ],
            onChanged: state.actionBusy
                ? null
                : (value) {
                    if (value != null) _cubit.selectYear(value);
                  },
          ),
        ),
        FilledButton.icon(
          onPressed: state.actionBusy ? null : _cubit.loadPreview,
          icon: AppIcon(AppIcons.search01, size: 18),
          label: Text(_txt('معاينة المسير', 'Preview run')),
        ),
      ],
    );
  }

  Widget _runList(HrPayrollState state) {
    if (state.runs.isEmpty) {
      return Center(
        child: Text(_txt('لا توجد مسيرات رواتب بعد', 'No payroll runs yet')),
      );
    }
    return ListView.separated(
      itemCount: state.runs.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final run = state.runs[index];
        return Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: const AppIcon(AppIcons.calendar01),
            title: Text('${_month(run.month)} ${run.year}'),
            subtitle: Text(
              '${_status(run.status)} · ${run.count} ${_txt('موظف', 'employees')} · ${_money(run.net)} · ${run.scope == 'brand' ? _txt('النطاق الكامل', 'Full company scope') : _txt('النطاق المسموح', 'Your permitted branch scope')}',
            ),
            trailing: const AppIcon(AppIcons.arrowRight01),
            onTap: state.actionBusy ? null : () => _openRun(run),
          ),
        );
      },
    );
  }

  Widget _preview(HrPayrollPreview preview, bool busy) {
    final existing = preview.run;
    final runStatus = '${existing?['status'] ?? ''}';
    final canGenerate =
        widget.canPrepare && runStatus != 'approved' && runStatus != 'paid';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: _txt('العودة للمسيرات', 'Back to runs'),
              onPressed: busy ? null : () => _cubit.clearPreview(),
              icon: const AppIcon(AppIcons.arrowLeft01),
            ),
            Expanded(
              child: Text(
                '${_txt('معاينة مسير', 'Payroll preview')} · ${_month(preview.month)} ${preview.year}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (canGenerate)
              FilledButton.icon(
                onPressed: busy ? null : () => _generate(preview),
                icon: AppIcon(AppIcons.money01, size: 18),
                label: Text(
                  _txt('إنشاء / إعادة احتساب', 'Generate / recalculate'),
                ),
              ),
          ],
        ),
        if (existing != null)
          Text(
            _txt('حالة المسير الحالي: ', 'Existing run: ') + _status(runStatus),
          ),
        if (preview.missing.isNotEmpty)
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                '${_txt('بيانات ناقصة تمنع احتساب بعض الموظفين', 'Missing data excludes employees from calculation')}: ${preview.missing.map((row) => row['staff_name'] ?? row['reason']).join('، ')}',
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            _metric(
              _txt('الإجمالي قبل الخصم', 'Gross'),
              _money(preview.total('gross')),
            ),
            _metric(
              _txt('الخصومات', 'Deductions'),
              _money(
                preview.total('attendance_deduction') +
                    preview.total('other_deductions') +
                    preview.total('advance_planned'),
              ),
            ),
            _metric(
              _txt('صافي المعاينة', 'Preview net'),
              _money(preview.total('net_preview')),
            ),
            _metric(
              _txt('عدد الموظفين', 'Employees'),
              '${preview.employees.length}',
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: preview.employees.isEmpty
              ? Center(
                  child: Text(
                    _txt(
                      'لا يوجد موظفون مؤهلون لهذه الفترة',
                      'No eligible employees for this period',
                    ),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) => constraints.maxWidth < 700
                      ? ListView.separated(
                          itemCount: preview.employees.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: AppSpacing.xs),
                          itemBuilder: (context, index) =>
                              _previewCard(preview.employees[index]),
                        )
                      : _previewTable(preview.employees),
                ),
        ),
      ],
    );
  }

  Widget _previewTable(List<HrJson> employees) => Card(
    margin: EdgeInsets.zero,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          DataColumn(label: Text(_txt('الموظف', 'Employee'))),
          DataColumn(label: Text(_txt('الراتب الأساسي', 'Basic salary'))),
          DataColumn(label: Text(_txt('الخصم للحضور', 'Attendance deduction'))),
          DataColumn(label: Text(_txt('خصم السلفة', 'Advance deduction'))),
          DataColumn(label: Text(_txt('الصافي', 'Net'))),
        ],
        rows: employees
            .map(
              (row) => DataRow(
                cells: [
                  DataCell(Text('${row['staff_name'] ?? '—'}')),
                  DataCell(Text(_money(row['basic_salary']))),
                  DataCell(Text(_money(row['attendance_deduction']))),
                  DataCell(Text(_money(row['advance_planned']))),
                  DataCell(Text(_money(row['net_preview']))),
                ],
              ),
            )
            .toList(growable: false),
      ),
    ),
  );

  Widget _previewCard(HrJson row) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${row['staff_name'] ?? '—'}',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          Text(
            '${_txt('الأساسي', 'Basic')}: ${_money(row['basic_salary'])} · ${_txt('خصم الحضور', 'Attendance')}: ${_money(row['attendance_deduction'])}',
          ),
          Text(
            '${_txt('السلف', 'Advances')}: ${_money(row['advance_planned'])} · ${_txt('الصافي', 'Net')}: ${_money(row['net_preview'])}',
          ),
        ],
      ),
    ),
  );

  Widget _metric(String label, String value) => SizedBox(
    width: 220,
    child: Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label),
            const SizedBox(height: AppSpacing.xs),
            Text(value, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    ),
  );

  Future<void> _generate(HrPayrollPreview preview) async {
    final run = preview.run;
    final existingCalculated = run?['status'] == 'calculated';
    final note = await _noteDialog(
      title: existingCalculated
          ? _txt('إعادة احتساب المسير؟', 'Recalculate this run?')
          : _txt('إنشاء المسير؟', 'Generate this run?'),
      message: existingCalculated
          ? _txt(
              'إعادة الاحتساب تستبدل تفاصيل المسير المحسوب السابق لهذه الفترة، مع تسجيل نسخة الحساب في التدقيق.',
              'Recalculation replaces the current draft statements for this period. The calculation revision remains audited.',
            )
          : _txt(
              'سيُنشأ مسير مركزي واحد لهذه الفترة.',
              'One consolidated company-wide run will be created for this period.',
            ),
      required: false,
    );
    if (note == null) return;
    await _cubit.generate(note.trim().isEmpty ? null : note.trim());
  }

  Future<void> _openRun(HrPayrollRun run) async {
    await _cubit.loadRun(run.id);
    if (!mounted || _cubit.state.detail == null) return;
    await showDialog<void>(
      context: context,
      builder: (context) => _RunDialog(
        detail: _cubit.state.detail!,
        busy: _cubit.state.actionBusy,
        canApprove: widget.canApprove,
        canPay: widget.canPay,
        canPrepare: widget.canPrepare,
        onApprove: (note) => _runAction(() => _cubit.approve(run.id, note)),
        onPay: (note) => _runAction(() => _cubit.markPaid(run.id, note)),
        onCancel: (note) => _runAction(() => _cubit.cancel(run.id, note!)),
        onClose: (note) => _runAction(() => _cubit.closePeriod(run.id, note)),
        onCorrection: (statementId, kind, amount, reason, date) => _runAction(
          () => _cubit.correction(
            statementId: statementId,
            kind: kind,
            amount: amount,
            reason: reason,
            effectiveDate: date,
          ),
        ),
      ),
    );
  }

  Future<void> _runAction(Future<bool> Function() action) async {
    final ok = await action();
    if (ok && mounted) Navigator.of(context, rootNavigator: true).pop();
  }

  Future<String?> _noteDialog({
    required String title,
    required String message,
    required bool required,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: controller,
              maxLength: 500,
              minLines: required ? 2 : 1,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: required
                    ? _txt('السبب (مطلوب)', 'Reason (required)')
                    : _txt('ملاحظة (اختياري)', 'Note (optional)'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_txt('إلغاء', 'Cancel')),
          ),
          FilledButton(
            onPressed: () {
              if (required && controller.text.trim().isEmpty) return;
              Navigator.pop(context, controller.text.trim());
            },
            child: Text(_txt('متابعة', 'Continue')),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  String _money(Object? value) {
    final amount = (value as num?)?.toDouble() ?? 0;
    return '${amount.toStringAsFixed(2)} SAR';
  }

  String _month(int month) {
    const en = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    const ar = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];
    if (month < 1 || month > 12) return '$month';
    return AppLocale.instance.isArabic ? ar[month - 1] : en[month - 1];
  }

  String _status(String value) => switch (value) {
    'draft' => _txt('مسودة', 'Draft'),
    'calculated' => _txt('محسوب', 'Calculated'),
    'approved' => _txt('معتمد', 'Approved'),
    'paid' => _txt('مدفوع', 'Paid'),
    'cancelled' => _txt('ملغى', 'Cancelled'),
    _ => value,
  };
  String _txt(String ar, String en) => AppLocale.instance.isArabic ? ar : en;
}

class _RunDialog extends StatelessWidget {
  const _RunDialog({
    required this.detail,
    required this.busy,
    required this.canApprove,
    required this.canPay,
    required this.canPrepare,
    required this.onApprove,
    required this.onPay,
    required this.onCancel,
    required this.onClose,
    required this.onCorrection,
  });
  final HrJson detail;
  final bool busy;
  final bool canApprove;
  final bool canPay;
  final bool canPrepare;
  final ValueChanged<String?> onApprove;
  final ValueChanged<String?> onPay;
  final ValueChanged<String?> onCancel;
  final ValueChanged<String?> onClose;
  final void Function(String, String, double, String, DateTime?) onCorrection;

  @override
  Widget build(BuildContext context) {
    final ar = AppLocale.instance.isArabic;
    final statements = hrJsonList(detail['statements']);
    final status = '${detail['status'] ?? 'draft'}';
    final closed = detail['closed_at'] != null;
    final actions = <Widget>[
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(ar ? 'إغلاق' : 'Close'),
      ),
      if (canPrepare && (status == 'draft' || status == 'calculated'))
        TextButton(
          onPressed: busy
              ? null
              : () async {
                  final note = await _PayrollNoteDialog.ask(
                    context,
                    title: ar ? 'إلغاء المسير' : 'Cancel run',
                    required: true,
                  );
                  if (note != null) onCancel(note);
                },
          child: Text(ar ? 'إلغاء المسير' : 'Cancel run'),
        ),
      if (canApprove && status == 'calculated')
        FilledButton(
          onPressed: busy
              ? null
              : () async {
                  final note = await _PayrollNoteDialog.ask(
                    context,
                    title: ar ? 'اعتماد المسير' : 'Approve run',
                    required: false,
                  );
                  if (note != null) onApprove(note.isEmpty ? null : note);
                },
          child: Text(ar ? 'اعتماد' : 'Approve'),
        ),
      if (canPay && status == 'approved')
        FilledButton(
          onPressed: busy
              ? null
              : () async {
                  final note = await _PayrollNoteDialog.ask(
                    context,
                    title: ar ? 'تسجيل الصرف' : 'Record payment',
                    required: true,
                    payment: true,
                  );
                  if (note != null) onPay(note);
                },
          child: Text(ar ? 'تسجيل الصرف' : 'Record payment'),
        ),
      if (canPay && status == 'paid' && !closed)
        FilledButton(
          onPressed: busy
              ? null
              : () async {
                  final note = await _PayrollNoteDialog.ask(
                    context,
                    title: ar ? 'إغلاق فترة الرواتب' : 'Close payroll period',
                    required: false,
                  );
                  if (note != null) onClose(note.isEmpty ? null : note);
                },
          child: Text(ar ? 'إغلاق الفترة' : 'Close period'),
        ),
    ];
    return AlertDialog(
      title: Text(
        '${_month(ar, (detail['period_month'] as num?)?.toInt() ?? 0)} ${detail['period_year'] ?? ''} · ${_status(ar, status)}',
      ),
      content: SizedBox(
        width: 820,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${ar ? 'رقم نسخة الاحتساب' : 'Calculation revision'}: ${detail['calc_seq'] ?? '—'} · ${ar ? 'الموظفون' : 'Employees'}: ${detail['statement_count'] ?? 0}',
            ),
            Text(
              '${ar ? 'الإجمالي' : 'Gross'}: ${_money(detail['total_gross'])} · ${ar ? 'الخصومات' : 'Deductions'}: ${_money(detail['total_deductions'])} · ${ar ? 'الصافي' : 'Net'}: ${_money(detail['total_net'])}',
            ),
            if (status == 'paid')
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  ar
                      ? 'تم تسجيل المسير كمدفوع؛ لا ينفذ التطبيق تحويلًا ماليًا.'
                      : 'The run is marked paid; the app does not initiate a transfer.',
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            Flexible(
              child: statements.isEmpty
                  ? Center(child: Text(ar ? 'لا توجد كشوف' : 'No statements'))
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: statements.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final row = statements[index];
                        return ListTile(
                          dense: true,
                          title: Text('${row['staff_name'] ?? '—'}'),
                          subtitle: Text(
                            '${ar ? 'أساسي' : 'Basic'} ${_money(row['basic_salary'])} · ${ar ? 'خصومات' : 'Deductions'} ${_money(row['deductions_total'])}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${ar ? 'الصافي' : 'Net'} ${_money(row['net'])}',
                              ),
                              if (canPrepare &&
                                  (status == 'approved' || status == 'paid') &&
                                  !closed)
                                IconButton(
                                  tooltip: ar
                                      ? 'إنشاء تسوية'
                                      : 'Create correction',
                                  icon: const AppIcon(AppIcons.edit01),
                                  onPressed: busy
                                      ? null
                                      : () async {
                                          final draft =
                                              await _PayrollCorrectionDialog.ask(
                                                context,
                                                ar: ar,
                                                periodYear:
                                                    (detail['period_year']
                                                            as num?)
                                                        ?.toInt() ??
                                                    DateTime.now().year,
                                                periodMonth:
                                                    (detail['period_month']
                                                            as num?)
                                                        ?.toInt() ??
                                                    DateTime.now().month,
                                              );
                                          if (draft != null) {
                                            onCorrection(
                                              '${row['statement_id']}',
                                              draft.kind,
                                              draft.amount,
                                              draft.reason,
                                              draft.effectiveDate,
                                            );
                                          }
                                        },
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: actions,
    );
  }

  static String _money(Object? value) =>
      '${((value as num?)?.toDouble() ?? 0).toStringAsFixed(2)} SAR';
  static String _month(bool ar, int month) {
    const en = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    const aa = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];
    if (month < 1 || month > 12) return '$month';
    return ar ? aa[month - 1] : en[month - 1];
  }

  static String _status(bool ar, String value) => switch (value) {
    'draft' => ar ? 'مسودة' : 'Draft',
    'calculated' => ar ? 'محسوب' : 'Calculated',
    'approved' => ar ? 'معتمد' : 'Approved',
    'paid' => ar ? 'مدفوع' : 'Paid',
    'cancelled' => ar ? 'ملغى' : 'Cancelled',
    _ => value,
  };
}

class _PayrollNoteDialog extends StatefulWidget {
  const _PayrollNoteDialog({
    required this.title,
    required this.required,
    this.payment = false,
  });
  final String title;
  final bool required;
  final bool payment;
  static Future<String?> ask(
    BuildContext context, {
    required String title,
    required bool required,
    bool payment = false,
  }) => showDialog<String>(
    context: context,
    builder: (_) =>
        _PayrollNoteDialog(title: title, required: required, payment: payment),
  );
  @override
  State<_PayrollNoteDialog> createState() => _PayrollNoteDialogState();
}

class _PayrollNoteDialogState extends State<_PayrollNoteDialog> {
  final _controller = TextEditingController();
  bool _invalid = false;
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ar = AppLocale.instance.isArabic;
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.payment)
            Text(
              ar
                  ? 'سجّل مرجع التحويل الخارجي أو إثبات الدفع. هذا الإجراء لا يحوّل الأموال.'
                  : 'Enter the external transfer reference or proof. This action does not move money.',
            ),
          TextField(
            controller: _controller,
            maxLength: 500,
            minLines: widget.required ? 2 : 1,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: widget.required
                  ? (ar
                        ? 'السبب أو المرجع مطلوب'
                        : 'Reason or reference required')
                  : (ar ? 'ملاحظة اختيارية' : 'Optional note'),
              errorText: _invalid
                  ? (ar ? 'أدخل قيمة مطلوبة' : 'A value is required')
                  : null,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(ar ? 'إلغاء' : 'Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (widget.required && _controller.text.trim().isEmpty) {
              setState(() => _invalid = true);
              return;
            }
            Navigator.pop(context, _controller.text.trim());
          },
          child: Text(ar ? 'متابعة' : 'Continue'),
        ),
      ],
    );
  }
}

class _PayrollCorrectionDraft {
  const _PayrollCorrectionDraft(
    this.kind,
    this.amount,
    this.reason,
    this.effectiveDate,
  );
  final String kind;
  final double amount;
  final String reason;
  final DateTime effectiveDate;
}

class _PayrollCorrectionDialog extends StatefulWidget {
  const _PayrollCorrectionDialog({
    required this.ar,
    required this.periodYear,
    required this.periodMonth,
  });
  final bool ar;
  final int periodYear;
  final int periodMonth;
  static Future<_PayrollCorrectionDraft?> ask(
    BuildContext context, {
    required bool ar,
    required int periodYear,
    required int periodMonth,
  }) => showDialog<_PayrollCorrectionDraft>(
    context: context,
    builder: (_) => _PayrollCorrectionDialog(
      ar: ar,
      periodYear: periodYear,
      periodMonth: periodMonth,
    ),
  );
  @override
  State<_PayrollCorrectionDialog> createState() =>
      _PayrollCorrectionDialogState();
}

class _PayrollCorrectionDialogState extends State<_PayrollCorrectionDialog> {
  final _amount = TextEditingController();
  final _reason = TextEditingController();
  String _kind = 'allowance';
  late DateTime _effectiveDate;
  String? _error;
  @override
  void initState() {
    super.initState();
    _effectiveDate = DateTime(widget.periodYear, widget.periodMonth + 1, 1);
  }

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ar = widget.ar;
    return AlertDialog(
      title: Text(ar ? 'تسوية على كشف الراتب' : 'Payroll statement correction'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _kind,
              decoration: InputDecoration(
                labelText: ar ? 'نوع التسوية' : 'Correction type',
              ),
              items: [
                DropdownMenuItem(
                  value: 'allowance',
                  child: Text(ar ? 'بدل' : 'Allowance'),
                ),
                DropdownMenuItem(
                  value: 'bonus',
                  child: Text(ar ? 'مكافأة' : 'Bonus'),
                ),
                DropdownMenuItem(
                  value: 'commission',
                  child: Text(ar ? 'عمولة' : 'Commission'),
                ),
                DropdownMenuItem(
                  value: 'overtime',
                  child: Text(ar ? 'عمل إضافي' : 'Overtime'),
                ),
                DropdownMenuItem(
                  value: 'deduction',
                  child: Text(ar ? 'خصم' : 'Deduction'),
                ),
              ],
              onChanged: (value) => setState(() => _kind = value ?? _kind),
            ),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(labelText: ar ? 'المبلغ' : 'Amount'),
            ),
            TextField(
              controller: _reason,
              maxLength: 500,
              minLines: 2,
              maxLines: 3,
              decoration: InputDecoration(labelText: ar ? 'السبب' : 'Reason'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(ar ? 'تاريخ السريان' : 'Effective date'),
              subtitle: Text(
                '${_effectiveDate.year}-${_effectiveDate.month.toString().padLeft(2, '0')}-${_effectiveDate.day.toString().padLeft(2, '0')}',
              ),
              trailing: IconButton(
                tooltip: ar ? 'اختيار التاريخ' : 'Choose date',
                icon: const AppIcon(AppIcons.calendar01),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _effectiveDate,
                    firstDate: DateTime(
                      widget.periodYear,
                      widget.periodMonth,
                      2,
                    ),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => _effectiveDate = picked);
                },
              ),
            ),
            if (_error != null)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(ar ? 'إلغاء' : 'Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final amount = double.tryParse(_amount.text.trim());
            if (amount == null || amount <= 0 || _reason.text.trim().isEmpty) {
              setState(
                () => _error = ar
                    ? 'أدخل مبلغًا موجبًا وسببًا للتسوية'
                    : 'Enter a positive amount and a reason',
              );
              return;
            }
            Navigator.pop(
              context,
              _PayrollCorrectionDraft(
                _kind,
                amount,
                _reason.text.trim(),
                _effectiveDate,
              ),
            );
          },
          child: Text(ar ? 'إرسال للتسوية' : 'Submit correction'),
        ),
      ],
    );
  }
}
