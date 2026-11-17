import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/app_dimensions.dart';
import '../../../core/locale/app_strings.dart';
import '../../../shared/widgets/admin_page_frame.dart';
import '../../../shared/widgets/admin_page_header.dart';
import '../../../shared/widgets/admin_state_view.dart';
import 'hr_settings_cubit.dart';

class HrSettingsPage extends StatefulWidget {
  const HrSettingsPage({super.key, this.cubit});
  final HrSettingsCubit? cubit;

  @override
  State<HrSettingsPage> createState() => _HrSettingsPageState();
}

class _HrSettingsPageState extends State<HrSettingsPage> {
  late final HrSettingsCubit _cubit;
  late final bool _ownsCubit;
  final _formKey = GlobalKey<FormState>();
  final _timeZone = TextEditingController();
  final _grace = TextEditingController();
  final _late = TextEditingController();
  final _early = TextEditingController();
  final _absence = TextEditingController();
  final _cap = TextEditingController();
  final _unpaid = TextEditingController();
  bool _cashierDeductions = false;
  bool _seeded = false;

  @override
  void initState() {
    super.initState();
    _ownsCubit = widget.cubit == null;
    _cubit = widget.cubit ?? HrSettingsCubit();
    if (_ownsCubit) _cubit.load();
  }

  @override
  void dispose() {
    if (_ownsCubit) _cubit.close();
    _timeZone.dispose();
    _grace.dispose();
    _late.dispose();
    _early.dispose();
    _absence.dispose();
    _cap.dispose();
    _unpaid.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocProvider.value(
    value: _cubit,
    child: BlocConsumer<HrSettingsCubit, HrSettingsState>(
      listenWhen: (previous, current) =>
          current.status == HrSettingsStatus.ready &&
          (!(_seeded) || (previous.saving && !current.saving)),
      listener: (context, state) {
        _seed(state.values, onlyHiddenRates: _seeded);
      },
      builder: (context, state) {
        if (state.status == HrSettingsStatus.loading && state.values.isEmpty) {
          return const AdminLoadingView();
        }
        if (state.status == HrSettingsStatus.failure && state.values.isEmpty) {
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
                title: S.hrSettings,
                subtitle: S.hrHiddenPolicyKeep,
              ),
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
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.only(top: AppSpacing.md),
                    children: [
                      _field(_timeZone, S.hrTimeZone, required: true),
                      _field(
                        _grace,
                        S.hrLateGrace,
                        required: true,
                        integer: true,
                        max: 240,
                      ),
                      _section(S.hrAttendance),
                      _field(
                        _late,
                        S.hrLateMinuteRate,
                        decimal: true,
                        max: 10000,
                      ),
                      _field(
                        _early,
                        S.hrEarlyMinuteRate,
                        decimal: true,
                        max: 10000,
                      ),
                      _field(
                        _absence,
                        S.hrAbsenceDayRate,
                        decimal: true,
                        max: 100000,
                      ),
                      _field(
                        _unpaid,
                        S.hrUnpaidLeaveRate,
                        decimal: true,
                        max: 100000,
                      ),
                      _section(S.hrFinance),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(S.hrCashierDeductions),
                        value: _cashierDeductions,
                        onChanged: state.saving
                            ? null
                            : (value) =>
                                  setState(() => _cashierDeductions = value),
                      ),
                      _field(_cap, S.hrDeductionCap, decimal: true, max: 100),
                      const SizedBox(height: AppSpacing.md),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: FilledButton(
                          onPressed: state.saving ? null : _save,
                          child: state.saving
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(S.hrSettingsSave),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );

  void _seed(Map<String, dynamic> values, {bool onlyHiddenRates = false}) {
    if (!onlyHiddenRates) {
      _timeZone.text = values['business_time_zone']?.toString() ?? '';
      _grace.text = values['late_grace_minutes']?.toString() ?? '0';
      _cashierDeductions = values['cashier_deduction_allowed'] == true;
    }
    _setMasked(_late, values['late_minute_rate']);
    _setMasked(_early, values['early_minute_rate']);
    _setMasked(_absence, values['absence_day_rate']);
    _setMasked(_cap, values['max_salary_deduction_percent']);
    _setMasked(_unpaid, values['unpaid_leave_day_rate']);
    if (!onlyHiddenRates) {
      _seeded = true;
      if (mounted) setState(() {});
    }
  }

  void _setMasked(TextEditingController controller, Object? value) {
    controller.text = value == null ? '' : value.toString();
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xs),
    child: Text(title, style: Theme.of(context).textTheme.titleMedium),
  );

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
    bool integer = false,
    bool decimal = false,
    double? max,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: TextFormField(
      controller: controller,
      enabled: !_cubit.state.saving,
      keyboardType: integer || decimal
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        helperText: decimal && controller.text.isEmpty
            ? S.hrHiddenPolicyKeep
            : null,
        border: const OutlineInputBorder(),
      ),
      validator: (value) {
        final text = value?.trim() ?? '';
        if (required && text.isEmpty) return S.requiredField;
        if (text.isEmpty) return null;
        final number = double.tryParse(text);
        if ((integer && int.tryParse(text) == null) ||
            (decimal && (number == null || number < 0 || number > max!))) {
          return S.hrAmountInvalid;
        }
        if (integer && (int.parse(text) < 0 || int.parse(text) > max!)) {
          return S.hrAmountInvalid;
        }
        return null;
      },
    ),
  );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final grace = int.tryParse(_grace.text.trim());
    if (grace == null) return;
    final cap = _nullableNumber(_cap.text);
    if (_cashierDeductions && (cap ?? 0) <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(S.hrAmountInvalid)));
      return;
    }
    final saved = await _cubit.save(
      timeZone: _timeZone.text,
      graceMinutes: grace,
      lateRate: _nullableNumber(_late.text),
      earlyRate: _nullableNumber(_early.text),
      absenceRate: _nullableNumber(_absence.text),
      cashierDeductions: _cashierDeductions,
      deductionCap: cap,
      unpaidLeaveRate: _nullableNumber(_unpaid.text),
    );
    if (saved && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(S.hrSettingsSaved)));
    }
  }

  double? _nullableNumber(String text) =>
      text.trim().isEmpty ? null : double.tryParse(text.trim());
}
