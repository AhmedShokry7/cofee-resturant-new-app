import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/utils/formatters.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/hr/compensation/presentation/hr_compensation_cubit.dart';
import 'package:admin_app/shared/widgets/admin_directory_panel.dart';
import 'package:admin_app/shared/widgets/admin_empty_state.dart';
import 'package:admin_app/shared/widgets/admin_page_frame.dart';
import 'package:admin_app/shared/widgets/admin_page_header.dart';
import 'package:admin_app/shared/widgets/admin_state_view.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/shared/widgets/admin_create_button.dart';

_HrCompensationCopy get _copy =>
    _HrCompensationCopy(AppLocale.instance.isArabic);

class _HrCompensationCopy {
  const _HrCompensationCopy(this.arabic);
  final bool arabic;
  String get accessDenied => arabic
      ? 'تتطلب صفحة التعويضات صلاحية قراءة ملفات الموظفين وإدارة التعويضات.'
      : 'Compensation requires employee-file read and compensation-manage permissions.';
  String get noEmployees => arabic
      ? 'لا يوجد موظفون ضمن نطاق صلاحيتك.'
      : 'No employees are available within your access scope.';
  String get allowances => arabic ? 'إجمالي البدلات' : 'Total allowances';
  String get effectiveTo => arabic ? 'ساري حتى' : 'Effective to';
}

class HrCompensationPage extends StatefulWidget {
  const HrCompensationPage({super.key, required this.canManage, this.cubit});

  final bool canManage;
  final HrCompensationCubit? cubit;

  @override
  State<HrCompensationPage> createState() => _HrCompensationPageState();
}

class _HrCompensationPageState extends State<HrCompensationPage> {
  late final HrCompensationCubit _cubit;
  late final bool _ownsCubit;

  @override
  void initState() {
    super.initState();
    _ownsCubit = widget.cubit == null;
    _cubit = widget.cubit ?? HrCompensationCubit();
    if (widget.canManage) _cubit.load();
  }

  @override
  void dispose() {
    if (_ownsCubit) _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocProvider.value(
    value: _cubit,
    child: BlocBuilder<HrCompensationCubit, HrCompensationState>(
      builder: (context, state) {
        if (!widget.canManage) {
          return AdminFailureView(message: _copy.accessDenied);
        }
        if (state.status == HrCompensationStatus.initial ||
            (state.status == HrCompensationStatus.loading &&
                state.employees.isEmpty)) {
          return const AdminLoadingView();
        }
        if (state.status == HrCompensationStatus.failure &&
            state.employees.isEmpty) {
          return AdminFailureView(message: state.error, onRetry: _cubit.load);
        }
        return AdminPageFrame(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AdminPageHeader(
                title: S.hrCompensation,
                subtitle: S.hrCompensationSubtitle,
                actions: [
                  if (state.selectedStaffId != null)
                    AdminCreateButton(
                      label: S.hrSaveCompensation,
                      onPressed:
                          state.saving ||
                              state.status == HrCompensationStatus.loading
                          ? null
                          : () => _addCompensation(context, state),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _employeePicker(state),
              if (state.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    state.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              Expanded(child: _content(state)),
            ],
          ),
        );
      },
    ),
  );

  Widget _employeePicker(HrCompensationState state) => AdminDirectoryPanel(
    padding: const EdgeInsets.all(AppSpacing.md),
    child: SizedBox(
      width: 420,
      child: DropdownButtonFormField<String>(
        initialValue: state.selectedStaffId,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: S.hrChooseEmployee,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        items: [
          for (final employee in state.employees)
            DropdownMenuItem(
              value: employee.staffId,
              child: Text(
                employee.employeeNumber == null ||
                        employee.employeeNumber!.isEmpty
                    ? employee.fullName
                    : '${employee.fullName} · ${employee.employeeNumber}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: (staffId) {
          if (staffId != null) _cubit.selectEmployee(staffId);
        },
      ),
    ),
  );

  Widget _content(HrCompensationState state) {
    if (state.employees.isEmpty) {
      return AdminEmptyState(
        icon: AppIcons.userMultiple,
        message: _copy.noEmployees,
      );
    }
    if (state.status == HrCompensationStatus.loading) {
      return const AdminLoadingView();
    }
    if (state.selectedStaffId == null || state.compensation == null) {
      return AdminEmptyState(
        icon: AppIcons.wallet01,
        message: S.hrNoCompensation,
      );
    }

    final compensation = state.compensation!;
    final current = compensation['current'];
    final history = compensation['history'];
    return ListView(
      children: [
        _currentCard(current),
        const SizedBox(height: AppSpacing.md),
        Text(
          S.hrCompensationHistory,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        if (history is! List || history.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(S.hrNoCompensation),
          )
        else
          ...history.whereType<Map>().map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _historyCard(Map<String, dynamic>.from(entry)),
            ),
          ),
      ],
    );
  }

  Widget _currentCard(Object? raw) {
    final current = raw is Map ? Map<String, dynamic>.from(raw) : null;
    if (current == null) {
      return AdminDirectoryPanel(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Text(S.hrNoCompensation),
      );
    }
    final currency = '${current['currency_code'] ?? 'SAR'}';
    return AdminDirectoryPanel(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            S.hrCurrentCompensation,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            children: [
              _amountTile(S.hrBasicSalary, current['basic_salary'], currency),
              _amountTile(
                S.hrHousingAllowance,
                current['housing_allowance'],
                currency,
              ),
              _amountTile(
                S.hrTransportAllowance,
                current['transport_allowance'],
                currency,
              ),
              _amountTile(
                S.hrOtherAllowance,
                current['other_allowance'],
                currency,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('${S.hrEffectiveFrom}: ${_date(current['effective_from'])}'),
        ],
      ),
    );
  }

  Widget _historyCard(Map<String, dynamic> entry) {
    final currency = '${entry['currency_code'] ?? 'SAR'}';
    final end = entry['effective_to'];
    return AdminDirectoryPanel(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${S.hrEffectiveFrom}: ${_date(entry['effective_from'])}'),
          if (end != null) Text('${_copy.effectiveTo}: ${_date(end)}'),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${S.hrBasicSalary}: ${_money(entry['basic_salary'], currency)}',
          ),
          Text('${_copy.allowances}: ${_money(entry['allowances'], currency)}'),
          if ('${entry['note'] ?? ''}'.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text('${S.hrCompensationNote}: ${entry['note']}'),
            ),
        ],
      ),
    );
  }

  Widget _amountTile(String label, Object? raw, String currency) => SizedBox(
    width: 210,
    child: ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(_money(raw, currency)),
    ),
  );

  String _money(Object? value, String currency) {
    final amount = value is num ? value : num.tryParse('$value') ?? 0;
    return '${localizeDigits(formatAmount(amount))} $currency';
  }

  String _date(Object? value) {
    if (value == null) return '—';
    final parsed = DateTime.tryParse('$value');
    if (parsed == null) return '$value';
    return localizeDigits(
      '${parsed.year.toString().padLeft(4, '0')}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}',
    );
  }

  Future<void> _addCompensation(
    BuildContext context,
    HrCompensationState state,
  ) async {
    final current = state.compensation?['current'];
    final data = await showDialog<_CompensationDraft>(
      context: context,
      builder: (context) => _CompensationDialog(
        current: current is Map ? Map<String, dynamic>.from(current) : null,
        history: state.compensation?['history'] is List
            ? (state.compensation!['history'] as List)
                  .whereType<Map>()
                  .map(Map<String, dynamic>.from)
                  .toList()
            : const [],
      ),
    );
    if (data == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final saved = await _cubit.addCompensation(
      basicSalary: data.basicSalary,
      housingAllowance: data.housingAllowance,
      transportAllowance: data.transportAllowance,
      otherAllowance: data.otherAllowance,
      effectiveFrom: data.effectiveFrom,
      note: data.note,
    );
    if (!context.mounted || !saved) return;
    messenger.showSnackBar(SnackBar(content: Text(S.hrCompensationSaved)));
  }
}

class _CompensationDraft {
  const _CompensationDraft({
    required this.basicSalary,
    required this.housingAllowance,
    required this.transportAllowance,
    required this.otherAllowance,
    required this.effectiveFrom,
    required this.note,
  });
  final double basicSalary;
  final double housingAllowance;
  final double transportAllowance;
  final double otherAllowance;
  final DateTime effectiveFrom;
  final String note;
}

class _CompensationDialog extends StatefulWidget {
  const _CompensationDialog({required this.current, required this.history});
  final Map<String, dynamic>? current;
  final List<Map<String, dynamic>> history;
  @override
  State<_CompensationDialog> createState() => _CompensationDialogState();
}

class _CompensationDialogState extends State<_CompensationDialog> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _fields;
  DateTime _effectiveFrom = DateUtils.dateOnly(DateTime.now());
  late final TextEditingController _note = TextEditingController();

  @override
  void initState() {
    super.initState();
    final current = widget.current ?? const <String, dynamic>{};
    _fields = {
      'basic': TextEditingController(text: '${current['basic_salary'] ?? ''}'),
      'housing': TextEditingController(
        text: '${current['housing_allowance'] ?? 0}',
      ),
      'transport': TextEditingController(
        text: '${current['transport_allowance'] ?? 0}',
      ),
      'other': TextEditingController(
        text: '${current['other_allowance'] ?? 0}',
      ),
    };
  }

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(S.hrSaveCompensation),
    content: SizedBox(
      width: 480,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _amountField('basic', S.hrBasicSalary, required: true),
              _amountField('housing', S.hrHousingAllowance),
              _amountField('transport', S.hrTransportAllowance),
              _amountField('other', S.hrOtherAllowance),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(S.hrEffectiveFrom),
                subtitle: Text(_dateLabel(_effectiveFrom)),
                trailing: IconButton(
                  tooltip: S.hrEffectiveFrom,
                  icon: const AppIcon(AppIcons.calendar01, size: 18),
                  onPressed: _pickDate,
                ),
              ),
              TextFormField(
                controller: _note,
                maxLength: 500,
                decoration: InputDecoration(labelText: S.hrCompensationNote),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(S.cancel),
      ),
      FilledButton(onPressed: _submit, child: Text(S.hrSaveCompensation)),
    ],
  );

  Widget _amountField(String key, String label, {bool required = false}) =>
      TextFormField(
        controller: _fields[key],
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label),
        validator: (value) {
          if (required && (value == null || value.trim().isEmpty)) {
            return S.requiredField;
          }
          if (value == null || value.trim().isEmpty) return null;
          final amount = double.tryParse(value.trim());
          if (amount == null || !amount.isFinite || amount < 0) {
            return S.hrAmountInvalid;
          }
          if (value.trim().contains('.') &&
              value.trim().split('.').last.length > 2) {
            return S.hrAmountInvalid;
          }
          return null;
        },
      );

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _effectiveFrom,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date != null) setState(() => _effectiveFrom = DateUtils.dateOnly(date));
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_dateConflicts()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.hrEffectiveDateDuplicateOrBackdated)),
      );
      return;
    }
    double amount(String key) =>
        double.tryParse(_fields[key]!.text.trim()) ?? 0;
    Navigator.pop(
      context,
      _CompensationDraft(
        basicSalary: amount('basic'),
        housingAllowance: amount('housing'),
        transportAllowance: amount('transport'),
        otherAllowance: amount('other'),
        effectiveFrom: _effectiveFrom,
        note: _note.text.trim(),
      ),
    );
  }

  bool _dateConflicts() {
    for (final row in widget.history) {
      final date = DateTime.tryParse('${row['effective_from'] ?? ''}');
      if (date == null) continue;
      final normalized = DateUtils.dateOnly(date);
      if (!normalized.isBefore(_effectiveFrom)) return true;
    }
    return false;
  }

  String _dateLabel(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
