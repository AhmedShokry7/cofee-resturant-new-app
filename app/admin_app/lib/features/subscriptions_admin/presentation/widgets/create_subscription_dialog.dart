import 'dart:async';
import 'dart:math';

import 'package:material_ui/material_ui.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/formatters.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/subscription_plans_admin/domain/entities/admin_subscription_plan.dart';
import 'package:admin_app/features/subscriptions_admin/domain/entities/admin_subscription_options.dart';
import 'package:admin_app/features/subscriptions_admin/presentation/manager/admin_subscription_cubit.dart';
import 'package:admin_app/shared/widgets/admin_dialog_chrome.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

Future<void> showCreateSubscriptionDialog({
  required BuildContext context,
  required AdminSubscriptionCubit cubit,
}) async {
  final created = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _CreateSubscriptionDialog(cubit: cubit),
  );
  if (created == true && context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(S.subscriptionsCreateSuccess)));
  }
}

class _CreateSubscriptionDialog extends StatefulWidget {
  const _CreateSubscriptionDialog({required this.cubit});

  final AdminSubscriptionCubit cubit;

  @override
  State<_CreateSubscriptionDialog> createState() =>
      _CreateSubscriptionDialogState();
}

class _CreateSubscriptionDialogState extends State<_CreateSubscriptionDialog> {
  final _search = TextEditingController();
  final _idempotencyKey = _newIdempotencyKey();
  Timer? _debounce;
  int _customerSearchRequest = 0;
  List<AdminSubscriptionCustomer> _customers = const [];
  List<AdminSubscriptionPaymentMethod> _methods = const [];
  List<AdminSubscriptionPlan> _plans = const [];
  AdminSubscriptionCustomer? _customer;
  AdminSubscriptionPlan? _plan;
  AdminSubscriptionPaymentMethod? _method;
  bool _loadingCustomers = true;
  bool _loadingOptions = true;
  bool _confirmPaid = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOptions();
    _searchCustomers('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    try {
      final options = await Future.wait([
        widget.cubit.loadAvailablePlans(),
        widget.cubit.loadPaymentMethods(),
      ]);
      if (!mounted) return;
      setState(() {
        _plans = options[0] as List<AdminSubscriptionPlan>;
        _methods = options[1] as List<AdminSubscriptionPaymentMethod>;
        _plan = _plans.isEmpty ? null : _plans.first;
        _method = _methods.isEmpty ? null : _methods.first;
        _loadingOptions = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingOptions = false);
    }
  }

  Future<void> _searchCustomers(String query) async {
    final request = ++_customerSearchRequest;
    if (mounted) setState(() => _loadingCustomers = true);
    try {
      final customers = await widget.cubit.searchCustomers(query);
      if (!mounted || request != _customerSearchRequest) return;
      setState(() {
        _customers = customers;
        _loadingCustomers = false;
      });
    } catch (_) {
      if (!mounted || request != _customerSearchRequest) return;
      setState(() {
        _customers = const [];
        _loadingCustomers = false;
      });
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _searchCustomers(value);
    });
  }

  bool get _requiresPayment => (_plan?.price ?? 0) > 0;

  bool get _canCreate =>
      !_saving &&
      !_loadingOptions &&
      !_loadingCustomers &&
      _customer != null &&
      _plan != null &&
      (!_requiresPayment || (_method != null && _confirmPaid));

  Future<void> _create() async {
    final customer = _customer;
    final plan = _plan;
    if (!_canCreate || customer == null || plan == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final outcome = await widget.cubit.createSubscription(
      customerId: customer.id,
      planId: plan.id,
      paymentMethodId: _requiresPayment ? _method?.id : null,
      paymentConfirmed: _confirmPaid,
      idempotencyKey: _idempotencyKey,
    );
    if (!mounted) return;
    if (outcome == AdminCreateSubscriptionOutcome.created) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _saving = false;
      _error = switch (outcome) {
        AdminCreateSubscriptionOutcome.customerUnavailable =>
          S.subscriptionsCreateCustomerUnavailable,
        AdminCreateSubscriptionOutcome.planUnavailable =>
          S.subscriptionsCreatePlanUnavailable,
        AdminCreateSubscriptionOutcome.paymentMethodRequired ||
        AdminCreateSubscriptionOutcome.paymentMethodUnavailable ||
        AdminCreateSubscriptionOutcome.paymentConfirmationRequired =>
          S.subscriptionsCreatePaymentUnavailable,
        AdminCreateSubscriptionOutcome.idempotencyConflict =>
          S.subscriptionsCreateConflict,
        AdminCreateSubscriptionOutcome.databaseNeedsUpdate =>
          S.subscriptionsCreateDatabaseNeedsUpdate,
        AdminCreateSubscriptionOutcome.invalid => S.subscriptionsCreateInvalid,
        _ => S.subscriptionsCreateFailed,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = min(620.0, size.width - 32);
    final height = min(740.0, size.height * .9);
    return PopScope(
      canPop: !_saving,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xxl,
        ),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: SizedBox(
          width: width,
          height: height,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AdminDialogHeader(
                title: S.subscriptionsCreateTitle,
                subtitle: S.subscriptionsCreateSubtitle,
                onClose: _saving ? null : () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SectionLabel(label: S.subscriptionsCreateCustomer),
                      const SizedBox(height: AppSpacing.sm),
                      TextField(
                        controller: _search,
                        enabled: !_saving,
                        onChanged: _onSearchChanged,
                        decoration: adminDialogFieldDecoration(
                          context,
                          label: S.subscriptionsCreateSearchCustomer,
                          hint: S.subscriptionsCreateSearchHint,
                        ).copyWith(prefixIcon: const Icon(AppIcons.search01)),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _customerPicker(),
                      const SizedBox(height: AppSpacing.lg),
                      _SectionLabel(label: S.subscriptionsCreatePlan),
                      const SizedBox(height: AppSpacing.sm),
                      _loadingOptions
                          ? const LinearProgressIndicator()
                          : _plans.isEmpty
                          ? _InfoBox(text: S.subscriptionsCreateNoPlans)
                          : DropdownButtonFormField<AdminSubscriptionPlan>(
                              initialValue: _plan,
                              isExpanded: true,
                              decoration: adminDialogFieldDecoration(
                                context,
                                label: S.subscriptionsCreatePlan,
                                hint: S.subscriptionsCreatePlanHint,
                              ),
                              items: [
                                for (final plan in _plans)
                                  DropdownMenuItem(
                                    value: plan,
                                    child: Text(
                                      '${plan.nameFor(AppLocale.instance.language)} · '
                                      '${localizeDigits(formatAmount(plan.price))} ${plan.currencyCode}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                              onChanged: _saving
                                  ? null
                                  : (value) => setState(() {
                                      _plan = value;
                                      _confirmPaid = false;
                                      _error = null;
                                    }),
                            ),
                      if (_plan != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        _InfoBox(
                          text: S.subscriptionsCreatePlanSummary(
                            localizeDigits(
                              S.subscriptionsPlanDuration(_plan!.durationDays),
                            ),
                            localizeDigits(
                              S.subscriptionsCupsRedeemed(_plan!.cupsPerCycle),
                            ),
                          ),
                        ),
                      ],
                      if (_requiresPayment) ...[
                        const SizedBox(height: AppSpacing.lg),
                        _SectionLabel(
                          label: S.subscriptionsCreatePaymentMethod,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _loadingOptions
                            ? const LinearProgressIndicator()
                            : _methods.isEmpty
                            ? _InfoBox(
                                text: S.subscriptionsCreateNoPaymentMethods,
                              )
                            : DropdownButtonFormField<
                                AdminSubscriptionPaymentMethod
                              >(
                                initialValue: _method,
                                isExpanded: true,
                                decoration: adminDialogFieldDecoration(
                                  context,
                                  label: S.subscriptionsCreatePaymentMethod,
                                  hint: S.subscriptionsCreatePaymentHint,
                                ),
                                items: [
                                  for (final method in _methods)
                                    DropdownMenuItem(
                                      value: method,
                                      child: Text(
                                        method.code == 'cash'
                                            ? S.subscriptionsCashPaymentMethod
                                            : method.nameFor(
                                                AppLocale.instance.language,
                                              ),
                                      ),
                                    ),
                                ],
                                onChanged: _saving
                                    ? null
                                    : (value) => setState(() {
                                        _method = value;
                                        _error = null;
                                      }),
                              ),
                        const SizedBox(height: AppSpacing.sm),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          value: _confirmPaid,
                          onChanged: _saving
                              ? null
                              : (value) => setState(
                                  () => _confirmPaid = value == true,
                                ),
                          title: Text(S.subscriptionsCreateConfirmPayment),
                          subtitle: Text(
                            S.subscriptionsCreateConfirmPaymentHint,
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: AppSpacing.md),
                        _InfoBox(text: S.subscriptionsCreateFreePlanHint),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          _error!,
                          style: const TextStyle(color: AppColor.errorColor),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              AdminDialogFooter(
                saving: _saving,
                onCancel: () => Navigator.of(context).pop(),
                onSave: _canCreate ? _create : null,
                saveKey: const Key('create-subscription-submit'),
                saveLabel: S.subscriptionsCreateAction,
                savingLabel: S.subscriptionsCreateSaving,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _customerPicker() {
    if (_loadingCustomers) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_customers.isEmpty) {
      return _InfoBox(
        text: _search.text.trim().isEmpty
            ? S.subscriptionsCreateNoCustomers
            : S.subscriptionsCreateNoCustomerMatches,
      );
    }
    return Container(
      constraints: const BoxConstraints(maxHeight: 190),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: adminControlBorderColor(Theme.of(context))),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: _customers.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final customer = _customers[index];
          final selected = _customer?.id == customer.id;
          final contact = [
            if ((customer.phone ?? '').trim().isNotEmpty)
              customer.phone!.trim(),
            if ((customer.email ?? '').trim().isNotEmpty)
              customer.email!.trim(),
          ].join(' · ');
          return ListTile(
            dense: true,
            selected: selected,
            enabled: !_saving,
            leading: Icon(
              selected ? AppIcons.checkmarkCircle02 : AppIcons.user,
              color: selected ? AppColor.adminAccent : null,
            ),
            title: Text(
              customer.displayName(AppLocale.instance.language),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: contact.isEmpty
                ? null
                : Text(contact, maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () => setState(() {
              _customer = customer;
              _error = null;
            }),
          );
        },
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: TextStyle(
      color: adminHeadingColor(Theme.of(context)),
      fontSize: AppFontSizes.size12,
      fontWeight: AppFontWeights.semiBold,
    ),
  );
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: adminTintedSurfaceColor(Theme.of(context)),
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: adminMutedColor(Theme.of(context)),
        fontSize: AppFontSizes.size10_5,
        height: AppTextHeights.line1_5,
      ),
    ),
  );
}

String _newIdempotencyKey() {
  final random = Random.secure().nextInt(0xFFFFFFFF).toRadixString(16);
  return 'admin-sub-${DateTime.now().microsecondsSinceEpoch}-$random';
}
