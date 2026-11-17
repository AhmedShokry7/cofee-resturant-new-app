import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/features/hr/finance/domain/models/hr_finance_models.dart';
import 'package:admin_app/features/hr/finance/presentation/hr_finance_strings.dart';
import 'package:admin_app/features/hr/finance/presentation/manager/hr_finance_cubit.dart';
import 'package:admin_app/features/hr/finance/presentation/manager/hr_finance_state.dart';
import 'package:admin_app/shared/widgets/admin_directory_panel.dart';
import 'package:admin_app/shared/widgets/admin_empty_state.dart';
import 'package:admin_app/shared/widgets/admin_page_frame.dart';
import 'package:admin_app/shared/widgets/admin_page_header.dart';
import 'package:admin_app/shared/widgets/admin_state_view.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';

class HrFinancePage extends StatefulWidget {
  const HrFinancePage({
    super.key,
    required this.canManage,
    this.canReadEmployees = false,
    this.cubit,
  });
  final bool canManage;
  final bool canReadEmployees;
  final HrFinanceCubit? cubit;
  @override
  State<HrFinancePage> createState() => _HrFinancePageState();
}

class _HrFinancePageState extends State<HrFinancePage> {
  late final HrFinanceCubit _cubit;
  late final bool _ownsCubit;
  String _advanceFilter = '', _adjustmentFilter = '', _discrepancyFilter = '';

  @override
  void initState() {
    super.initState();
    _ownsCubit = widget.cubit == null;
    _cubit = widget.cubit ?? HrFinanceCubit();
    if (_ownsCubit) _cubit.load(loadEmployees: widget.canReadEmployees);
  }

  @override
  void dispose() {
    if (_ownsCubit) _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocProvider.value(
    value: _cubit,
    child: BlocBuilder<HrFinanceCubit, HrFinanceState>(
      builder: (context, state) {
        if (state.status == HrFinanceStatus.loading &&
            state.advances.isEmpty &&
            state.adjustments.isEmpty &&
            state.discrepancies.isEmpty) {
          return const AdminLoadingView();
        }
        if (state.status == HrFinanceStatus.failure &&
            state.advances.isEmpty &&
            state.adjustments.isEmpty &&
            state.discrepancies.isEmpty) {
          return AdminFailureView(
            message: state.error,
            onRetry: () => _cubit.load(loadEmployees: widget.canReadEmployees),
          );
        }
        return AdminPageFrame(
          child: DefaultTabController(
            length: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AdminPageHeader(
                  title: HrFinanceStrings.title,
                  subtitle: HrFinanceStrings.subtitle,
                  actions: [
                    if (widget.canManage && widget.canReadEmployees)
                      OutlinedButton.icon(
                        onPressed: () =>
                            _createAdjustment(context, state.employees),
                        icon: const AppIcon(AppIcons.add01, size: 18),
                        label: Text(HrFinanceStrings.create),
                      ),
                    IconButton(
                      tooltip: HrFinanceStrings.title,
                      onPressed: () =>
                          _cubit.load(loadEmployees: widget.canReadEmployees),
                      icon: const AppIcon(AppIcons.refresh, size: 18),
                    ),
                  ],
                ),
                if (state.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text(
                      state.error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: AppSpacing.md),
                TabBar(
                  isScrollable: true,
                  tabs: [
                    Tab(text: HrFinanceStrings.advances),
                    Tab(text: HrFinanceStrings.adjustments),
                    Tab(text: HrFinanceStrings.discrepancies),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Expanded(
                  child: TabBarView(
                    children: [
                      _advancesView(state),
                      _adjustmentsView(state),
                      _discrepanciesView(state),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );

  Widget _advancesView(HrFinanceState state) {
    final records = state.advances
        .where((e) => _advanceFilter.isEmpty || e.status == _advanceFilter)
        .toList();
    return Column(
      children: [
        _filter(_advanceFilter, const [
          '',
          'pending',
          'approved',
          'disbursed',
          'settled',
          'rejected',
          'cancelled',
        ], (v) => setState(() => _advanceFilter = v ?? '')),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: records.isEmpty
              ? _empty(HrFinanceStrings.advances)
              : ListView.separated(
                  itemCount: records.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) =>
                      _advanceCard(context, records[index]),
                ),
        ),
      ],
    );
  }

  Widget _adjustmentsView(HrFinanceState state) {
    final records = state.adjustments
        .where(
          (e) => _adjustmentFilter.isEmpty || e.status == _adjustmentFilter,
        )
        .toList();
    return Column(
      children: [
        _filter(_adjustmentFilter, const [
          '',
          'pending',
          'approved',
          'rejected',
          'reversed',
          'cancelled',
        ], (v) => setState(() => _adjustmentFilter = v ?? '')),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: records.isEmpty
              ? _empty(HrFinanceStrings.adjustments)
              : ListView.separated(
                  itemCount: records.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) =>
                      _adjustmentCard(context, records[index]),
                ),
        ),
      ],
    );
  }

  Widget _discrepanciesView(HrFinanceState state) {
    final records = state.discrepancies
        .where(
          (e) => _discrepancyFilter.isEmpty || e.status == _discrepancyFilter,
        )
        .toList();
    return Column(
      children: [
        _filter(_discrepancyFilter, const [
          '',
          'pending_review',
          'explained',
          'reconciliation_required',
          'confirmed',
          'rejected',
          'deduction_approved',
          'closed',
        ], (v) => setState(() => _discrepancyFilter = v ?? '')),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: records.isEmpty
              ? _empty(HrFinanceStrings.discrepancies)
              : ListView.separated(
                  itemCount: records.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) => _discrepancyCard(
                    context,
                    records[index],
                    state.employees,
                    state.cashierDeductionAllowed,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _filter(
    String selected,
    List<String> statuses,
    ValueChanged<String?> onChanged,
  ) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: SizedBox(
      width: 260,
      child: DropdownButtonFormField<String>(
        initialValue: selected,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: HrFinanceStrings.status,
          isDense: true,
        ),
        items: [
          for (final value in statuses)
            DropdownMenuItem(
              value: value,
              child: Text(
                value.isEmpty
                    ? HrFinanceStrings.all
                    : HrFinanceStrings.statusName(value),
              ),
            ),
        ],
        onChanged: onChanged,
      ),
    ),
  );

  Widget _empty(String title) => AdminEmptyState(
    icon: AppIcons.coins01,
    message: '${HrFinanceStrings.noRecords} · $title',
  );

  Widget _advanceCard(BuildContext context, HrAdvance advance) => _RecordCard(
    title: advance.staffName,
    status: advance.status,
    children: [
      _value(HrFinanceStrings.amount, _money(advance.amount, advance.currency)),
      _value(
        HrFinanceStrings.installment,
        _money(advance.installmentAmount, advance.currency),
      ),
      _value(
        HrFinanceStrings.settledAmount,
        _money(advance.settledAmount, advance.currency),
      ),
      _value(
        HrFinanceStrings.outstanding,
        _money(advance.outstanding, advance.currency),
      ),
      _value(HrFinanceStrings.reason, advance.reason),
      if (advance.reviewNote != null)
        _value(HrFinanceStrings.note, advance.reviewNote!),
    ],
    actions: [
      if (widget.canManage && advance.status == 'pending') ...[
        _action(
          HrFinanceStrings.reject,
          () => _reviewAdvance(context, advance, false),
          outline: true,
        ),
        _action(
          HrFinanceStrings.approve,
          () => _reviewAdvance(context, advance, true),
        ),
      ],
      if (widget.canManage && advance.status == 'approved')
        _action(HrFinanceStrings.disburse, () => _disburse(context, advance)),
      if (widget.canManage &&
          !const {
            'settled',
            'cancelled',
            'rejected',
          }.contains(advance.status) &&
          advance.settledAmount == 0)
        _action(
          HrFinanceStrings.cancel,
          () => _cancelAdvance(context, advance),
          outline: true,
        ),
    ],
  );

  Widget _adjustmentCard(BuildContext context, HrAdjustment adjustment) =>
      _RecordCard(
        title: adjustment.staffName,
        status: adjustment.status,
        children: [
          _value(
            HrFinanceStrings.kind,
            HrFinanceStrings.kindName(adjustment.kind),
          ),
          _value(
            HrFinanceStrings.amount,
            _money(adjustment.amount, HrFinanceStrings.currency),
          ),
          _value(HrFinanceStrings.effectiveDate, adjustment.effectiveDate),
          _value(HrFinanceStrings.reason, adjustment.reason),
          if (adjustment.claimed)
            _value(HrFinanceStrings.status, HrFinanceStrings.claimed),
          if (adjustment.reviewNote != null)
            _value(HrFinanceStrings.note, adjustment.reviewNote!),
        ],
        actions: [
          if (widget.canManage && adjustment.status == 'pending') ...[
            _action(
              HrFinanceStrings.reject,
              () => _reviewAdjustment(context, adjustment, false),
              outline: true,
            ),
            _action(
              HrFinanceStrings.approve,
              () => _reviewAdjustment(context, adjustment, true),
            ),
          ],
          if (widget.canManage &&
              adjustment.status == 'approved' &&
              !adjustment.claimed)
            _action(
              HrFinanceStrings.reverse,
              () => _reverseAdjustment(context, adjustment),
              outline: true,
            ),
        ],
      );

  Widget _discrepancyCard(
    BuildContext context,
    HrDiscrepancy d,
    List<HrFinanceEmployee> employees,
    bool cashierDeductionAllowed,
  ) {
    final available = employees
        .where((e) => e.branchIds.contains(d.branchId))
        .toList();
    if (d.drawerCashierId.isNotEmpty &&
        !available.any((employee) => employee.id == d.drawerCashierId)) {
      available.add(
        HrFinanceEmployee(
          id: d.drawerCashierId,
          name: d.drawerCashierName,
          branchIds: [d.branchId],
        ),
      );
    }
    final actions = <Widget>[];
    if (widget.canManage &&
        const {
          'pending_review',
          'confirmed',
          'reconciliation_required',
        }.contains(d.status)) {
      actions.add(
        _action(
          HrFinanceStrings.explain,
          () => _reviewDiscrepancy(context, d, 'explain'),
        ),
      );
    }
    if (widget.canManage &&
        const {'pending_review', 'explained'}.contains(d.status)) {
      actions.add(
        _action(
          HrFinanceStrings.reconcile,
          () => _reviewDiscrepancy(context, d, 'reconcile'),
          outline: true,
        ),
      );
    }
    if (widget.canManage &&
        const {
          'pending_review',
          'explained',
          'reconciliation_required',
        }.contains(d.status) &&
        available.isNotEmpty) {
      actions.add(
        _action(
          HrFinanceStrings.confirm,
          () => _reviewDiscrepancy(context, d, 'confirm', employees: available),
        ),
      );
    }
    if (widget.canManage &&
        cashierDeductionAllowed &&
        d.status == 'confirmed' &&
        d.attributedStaffId.isNotEmpty) {
      actions.add(
        _action(
          HrFinanceStrings.deduct,
          () => _reviewDiscrepancy(context, d, 'deduct'),
        ),
      );
    }
    if (widget.canManage &&
        !const {'closed', 'deduction_approved'}.contains(d.status)) {
      actions.add(
        _action(
          HrFinanceStrings.reject,
          () => _reviewDiscrepancy(context, d, 'reject'),
          outline: true,
        ),
      );
    }
    if (widget.canManage &&
        const {
          'explained',
          'reconciliation_required',
          'confirmed',
          'rejected',
          'deduction_approved',
        }.contains(d.status)) {
      actions.add(
        _action(
          HrFinanceStrings.close,
          () => _reviewDiscrepancy(context, d, 'close'),
          outline: true,
        ),
      );
    }
    return _RecordCard(
      title: '${_branchName(d)} · ${d.drawerCashierName}',
      status: d.status,
      children: [
        _value(
          HrFinanceStrings.signedVariance,
          _money(d.signedVariance, d.currency),
        ),
        _value(HrFinanceStrings.amount, _money(d.amount, d.currency)),
        if (d.attributedStaffName.isNotEmpty)
          _value(HrFinanceStrings.attributedEmployee, d.attributedStaffName),
        if (d.evidence.isNotEmpty)
          _value(HrFinanceStrings.evidence, d.evidence),
        if (d.reviewNote.isNotEmpty)
          _value(HrFinanceStrings.note, d.reviewNote),
      ],
      actions: actions,
    );
  }

  String _branchName(HrDiscrepancy d) {
    final value = AppLocale.instance.isArabic ? d.branchNameAr : d.branchNameEn;
    return value.isNotEmpty ? value : HrFinanceStrings.branch;
  }

  Widget _value(String label, String value) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.xs),
    child: _LabeledValue(label, value),
  );

  Widget _action(
    String label,
    VoidCallback onPressed, {
    bool outline = false,
  }) => outline
      ? OutlinedButton(onPressed: onPressed, child: Text(label))
      : FilledButton(onPressed: onPressed, child: Text(label));

  String _money(double amount, String currency) =>
      '${amount.toStringAsFixed(2)} ${currency.isEmpty ? HrFinanceStrings.currency : currency}';

  Future<void> _reviewAdvance(
    BuildContext context,
    HrAdvance a,
    bool approve,
  ) async {
    final result = await showDialog<_AdvanceReviewResult>(
      context: context,
      builder: (_) => _AdvanceReviewDialog(advance: a, approve: approve),
    );
    if (result == null || !context.mounted) return;
    await _cubit.reviewAdvance(a, approve, result.installment, result.note);
  }

  Future<void> _disburse(BuildContext context, HrAdvance a) async {
    final note = await _noteDialog(context, HrFinanceStrings.disburse);
    if (note == null || !context.mounted) return;
    await _cubit.disburseAdvance(a, note);
  }

  Future<void> _cancelAdvance(BuildContext context, HrAdvance a) async {
    final note = await _noteDialog(
      context,
      HrFinanceStrings.cancel,
      required: true,
    );
    if (note == null || !context.mounted) return;
    await _cubit.cancelAdvance(a, note);
  }

  Future<void> _reviewAdjustment(
    BuildContext context,
    HrAdjustment a,
    bool approve,
  ) async {
    final note = await _noteDialog(
      context,
      approve ? HrFinanceStrings.approve : HrFinanceStrings.reject,
      required: !approve,
    );
    if (note == null || !context.mounted) return;
    await _cubit.reviewAdjustment(a, approve, note);
  }

  Future<void> _reverseAdjustment(BuildContext context, HrAdjustment a) async {
    final reason = await _noteDialog(
      context,
      HrFinanceStrings.reverse,
      required: true,
    );
    if (reason == null || !context.mounted) return;
    await _cubit.reverseAdjustment(a, reason);
  }

  Future<void> _reviewDiscrepancy(
    BuildContext context,
    HrDiscrepancy d,
    String action, {
    List<HrFinanceEmployee> employees = const [],
  }) async {
    final result = await showDialog<_DiscrepancyResult>(
      context: context,
      builder: (_) => _DiscrepancyDialog(
        action: action,
        amount: d.amount,
        employees: employees,
        initialEmployee: employees.any((e) => e.id == d.attributedStaffId)
            ? d.attributedStaffId
            : null,
      ),
    );
    if (result == null || !context.mounted) return;
    await _cubit.reviewDiscrepancy(
      d,
      action,
      note: result.note,
      evidence: result.evidence,
      attributedStaffId: result.staffId,
      deductionAmount: result.amount,
    );
  }

  Future<void> _createAdjustment(
    BuildContext context,
    List<HrFinanceEmployee> employees,
  ) async {
    final result = await showDialog<_AdjustmentDraft>(
      context: context,
      builder: (_) => _CreateAdjustmentDialog(employees: employees),
    );
    if (result == null || !context.mounted) return;
    await _cubit.createAdjustment(
      result.staffId,
      result.kind,
      result.amount,
      result.reason,
      result.date,
    );
  }

  Future<String?> _noteDialog(
    BuildContext context,
    String title, {
    bool required = false,
  }) => showDialog<String>(
    context: context,
    builder: (_) => _TextActionDialog(title: title, required: required),
  );
}

class _LabeledValue extends StatelessWidget {
  const _LabeledValue(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(label, style: Theme.of(context).textTheme.labelMedium),
      Text(value),
    ],
  );
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({
    required this.title,
    required this.status,
    required this.children,
    required this.actions,
  });
  final String title, status;
  final List<Widget> children;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => AdminDirectoryPanel(
    padding: const EdgeInsets.all(AppSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            Chip(
              label: Text(HrFinanceStrings.statusName(status)),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        ...children,
        if (actions.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: actions,
          ),
        ],
      ],
    ),
  );
}

class _AdvanceReviewResult {
  const _AdvanceReviewResult(this.installment, this.note);
  final double? installment;
  final String? note;
}

class _AdvanceReviewDialog extends StatefulWidget {
  const _AdvanceReviewDialog({required this.advance, required this.approve});
  final HrAdvance advance;
  final bool approve;
  @override
  State<_AdvanceReviewDialog> createState() => _AdvanceReviewDialogState();
}

class _AdvanceReviewDialogState extends State<_AdvanceReviewDialog> {
  final _form = GlobalKey<FormState>();
  late final _installment = TextEditingController(
    text: widget.advance.outstanding.toStringAsFixed(2),
  );
  final _note = TextEditingController();
  @override
  void dispose() {
    _installment.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.approve ? HrFinanceStrings.approve : HrFinanceStrings.reject,
    ),
    content: Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.approve)
            TextFormField(
              controller: _installment,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: HrFinanceStrings.installment,
              ),
              validator: (v) {
                final n = double.tryParse(v ?? '');
                return n == null || n <= 0 || n > widget.advance.outstanding
                    ? HrFinanceStrings.invalidNumber
                    : null;
              },
            ),
          TextField(
            controller: _note,
            maxLines: 2,
            decoration: InputDecoration(labelText: HrFinanceStrings.note),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(HrFinanceStrings.cancel),
      ),
      FilledButton(
        onPressed: () {
          if (!_form.currentState!.validate()) return;
          Navigator.pop(
            context,
            _AdvanceReviewResult(
              widget.approve ? double.parse(_installment.text) : null,
              _note.text.trim(),
            ),
          );
        },
        child: Text(HrFinanceStrings.save),
      ),
    ],
  );
}

class _TextActionDialog extends StatefulWidget {
  const _TextActionDialog({required this.title, this.required = false});
  final String title;
  final bool required;
  @override
  State<_TextActionDialog> createState() => _TextActionDialogState();
}

class _TextActionDialogState extends State<_TextActionDialog> {
  final _controller = TextEditingController();
  String? _error;
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _controller,
      maxLines: 3,
      decoration: InputDecoration(
        labelText: HrFinanceStrings.note,
        errorText: _error,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(HrFinanceStrings.cancel),
      ),
      FilledButton(
        onPressed: () {
          final value = _controller.text.trim();
          if (widget.required && value.isEmpty) {
            setState(() => _error = HrFinanceStrings.required);
            return;
          }
          Navigator.pop(context, value);
        },
        child: Text(HrFinanceStrings.save),
      ),
    ],
  );
}

class _DiscrepancyResult {
  const _DiscrepancyResult({
    this.note,
    this.evidence,
    this.staffId,
    this.amount,
  });
  final String? note, evidence, staffId;
  final double? amount;
}

class _DiscrepancyDialog extends StatefulWidget {
  const _DiscrepancyDialog({
    required this.action,
    required this.amount,
    required this.employees,
    this.initialEmployee,
  });
  final String action;
  final double amount;
  final List<HrFinanceEmployee> employees;
  final String? initialEmployee;
  @override
  State<_DiscrepancyDialog> createState() => _DiscrepancyDialogState();
}

class _DiscrepancyDialogState extends State<_DiscrepancyDialog> {
  final _form = GlobalKey<FormState>();
  final _note = TextEditingController(),
      _evidence = TextEditingController(),
      _amount = TextEditingController();
  String? _staffId;
  @override
  void initState() {
    super.initState();
    _staffId = widget.initialEmployee;
    _amount.text = widget.amount.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _note.dispose();
    _evidence.dispose();
    _amount.dispose();
    super.dispose();
  }

  bool get _needsNote =>
      const {'explain', 'reject', 'deduct'}.contains(widget.action);
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(_actionLabel(widget.action)),
    content: SizedBox(
      width: 440,
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.action == 'confirm')
                DropdownButtonFormField<String>(
                  initialValue: _staffId,
                  decoration: InputDecoration(
                    labelText: HrFinanceStrings.attributedEmployee,
                  ),
                  items: [
                    for (final employee in widget.employees)
                      DropdownMenuItem(
                        value: employee.id,
                        child: Text(employee.name),
                      ),
                  ],
                  validator: (v) =>
                      v == null ? HrFinanceStrings.selectEmployee : null,
                  onChanged: (value) => setState(() => _staffId = value),
                ),
              if (widget.action == 'deduct')
                TextFormField(
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: HrFinanceStrings.amount,
                  ),
                  validator: (v) {
                    final n = double.tryParse(v ?? '');
                    return n == null || n <= 0 || n > widget.amount
                        ? HrFinanceStrings.invalidNumber
                        : null;
                  },
                ),
              TextFormField(
                controller: _note,
                maxLines: 3,
                decoration: InputDecoration(labelText: HrFinanceStrings.note),
                validator: (v) => _needsNote && (v == null || v.trim().isEmpty)
                    ? HrFinanceStrings.required
                    : null,
              ),
              TextField(
                controller: _evidence,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: HrFinanceStrings.evidence,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(HrFinanceStrings.cancel),
      ),
      FilledButton(
        onPressed: () {
          if (!_form.currentState!.validate()) return;
          Navigator.pop(
            context,
            _DiscrepancyResult(
              note: _note.text.trim(),
              evidence: _evidence.text.trim(),
              staffId: widget.action == 'confirm' ? _staffId : null,
              amount: widget.action == 'deduct'
                  ? double.parse(_amount.text)
                  : null,
            ),
          );
        },
        child: Text(HrFinanceStrings.save),
      ),
    ],
  );
  String _actionLabel(String action) => switch (action) {
    'explain' => HrFinanceStrings.explain,
    'reconcile' => HrFinanceStrings.reconcile,
    'confirm' => HrFinanceStrings.confirm,
    'deduct' => HrFinanceStrings.deduct,
    'close' => HrFinanceStrings.close,
    'reject' => HrFinanceStrings.reject,
    _ => action,
  };
}

class _AdjustmentDraft {
  const _AdjustmentDraft(
    this.staffId,
    this.kind,
    this.amount,
    this.reason,
    this.date,
  );
  final String staffId, kind, reason, date;
  final double amount;
}

class _CreateAdjustmentDialog extends StatefulWidget {
  const _CreateAdjustmentDialog({required this.employees});
  final List<HrFinanceEmployee> employees;
  @override
  State<_CreateAdjustmentDialog> createState() =>
      _CreateAdjustmentDialogState();
}

class _CreateAdjustmentDialogState extends State<_CreateAdjustmentDialog> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController(),
      _reason = TextEditingController(),
      _date = TextEditingController();
  String? _staff;
  String _kind = 'allowance';
  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _date.text =
        '${n.year.toString().padLeft(4, '0')}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    _date.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(HrFinanceStrings.create),
    content: SizedBox(
      width: 440,
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _staff,
                decoration: InputDecoration(
                  labelText: HrFinanceStrings.employee,
                ),
                items: [
                  for (final e in widget.employees)
                    DropdownMenuItem(value: e.id, child: Text(e.name)),
                ],
                validator: (v) =>
                    v == null ? HrFinanceStrings.selectEmployee : null,
                onChanged: (v) => setState(() => _staff = v),
              ),
              DropdownButtonFormField<String>(
                initialValue: _kind,
                decoration: InputDecoration(labelText: HrFinanceStrings.kind),
                items: [
                  for (final v in const [
                    'allowance',
                    'bonus',
                    'commission',
                    'overtime',
                    'deduction',
                  ])
                    DropdownMenuItem(
                      value: v,
                      child: Text(HrFinanceStrings.kindName(v)),
                    ),
                ],
                onChanged: (v) => setState(() => _kind = v ?? _kind),
              ),
              TextFormField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(labelText: HrFinanceStrings.amount),
                validator: (v) {
                  final n = double.tryParse(v ?? '');
                  return n == null || n <= 0
                      ? HrFinanceStrings.invalidNumber
                      : null;
                },
              ),
              TextFormField(
                controller: _date,
                decoration: InputDecoration(
                  labelText: HrFinanceStrings.effectiveDate,
                ),
                validator: (v) => DateTime.tryParse(v ?? '') == null
                    ? HrFinanceStrings.required
                    : null,
              ),
              TextFormField(
                controller: _reason,
                maxLines: 3,
                decoration: InputDecoration(labelText: HrFinanceStrings.reason),
                validator: (v) => v == null || v.trim().isEmpty
                    ? HrFinanceStrings.required
                    : null,
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(HrFinanceStrings.cancel),
      ),
      FilledButton(
        onPressed: () {
          if (!_form.currentState!.validate()) return;
          Navigator.pop(
            context,
            _AdjustmentDraft(
              _staff!,
              _kind,
              double.parse(_amount.text),
              _reason.text.trim(),
              _date.text.trim(),
            ),
          );
        },
        child: Text(HrFinanceStrings.save),
      ),
    ],
  );
}
