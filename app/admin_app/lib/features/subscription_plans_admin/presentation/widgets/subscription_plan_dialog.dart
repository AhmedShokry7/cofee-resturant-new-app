import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/subscription_plans_admin/domain/entities/admin_subscription_plan_product.dart';
import 'package:admin_app/features/subscription_plans_admin/domain/entities/admin_subscription_plan.dart';
import 'package:admin_app/features/subscription_plans_admin/domain/repositories/subscription_plan_repository.dart';
import 'package:admin_app/features/subscription_plans_admin/presentation/manager/admin_subscription_plan_cubit.dart';
import 'package:admin_app/features/subscription_plans_admin/presentation/manager/admin_subscription_plan_state.dart';
import 'package:admin_app/features/subscription_plans_admin/presentation/widgets/plan_format.dart';
import 'package:admin_app/features/subscription_plans_admin/presentation/widgets/subscription_plan_product_picker.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/custom_text_form_field.dart';

Future<void> showSubscriptionPlanDialog({
  required BuildContext context,
  required AdminSubscriptionPlanCubit cubit,
  AdminSubscriptionPlan? plan,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => SubscriptionPlanDialog(cubit: cubit, plan: plan),
  );
}

class SubscriptionPlanDialog extends StatefulWidget {
  const SubscriptionPlanDialog({super.key, required this.cubit, this.plan});

  final AdminSubscriptionPlanCubit cubit;
  final AdminSubscriptionPlan? plan;

  @override
  State<SubscriptionPlanDialog> createState() => _SubscriptionPlanDialogState();
}

class _SubscriptionPlanDialogState extends State<SubscriptionPlanDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameAr;
  late final TextEditingController _nameEn;
  late final TextEditingController _code;
  late final TextEditingController _descriptionAr;
  late final TextEditingController _descriptionEn;
  late final TextEditingController _price;
  late final TextEditingController _currency;
  late final TextEditingController _duration;
  late final TextEditingController _cups;
  late final TextEditingController _rollover;
  late final TextEditingController _bonusValue;

  String _bonusType = 'none';
  String _renewalPolicy = 'manual';
  bool _autoRenewSupported = false;
  bool _bonusExpiresWithCycle = true;
  bool _isActive = true;
  bool _isForSale = true;
  String _productScope = 'all';
  final Map<String, AdminSubscriptionPlanProduct> _selectedProducts = {};
  bool _saving = false;
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;
  String? _error;

  bool get _isEditing => widget.plan != null;

  @override
  void initState() {
    super.initState();
    final plan = widget.plan;
    _nameAr = TextEditingController(text: plan?.nameAr ?? '');
    _nameEn = TextEditingController(text: plan?.nameEn ?? '');
    _code = TextEditingController(text: plan?.code ?? '');
    _descriptionAr = TextEditingController(text: plan?.descriptionAr ?? '');
    _descriptionEn = TextEditingController(text: plan?.descriptionEn ?? '');
    _price = TextEditingController(
      text: plan == null ? '' : _formatInitialAmount(plan.price),
    );
    _currency = TextEditingController(text: plan?.currencyCode ?? 'SAR');
    _duration = TextEditingController(text: '${plan?.durationDays ?? 30}');
    _cups = TextEditingController(text: '${plan?.cupsPerCycle ?? 10}');
    _rollover = TextEditingController(text: '${plan?.rolloverCapCups ?? 0}');
    _bonusType = plan?.bonusType ?? 'none';
    _bonusValue = TextEditingController(
      text: plan == null || plan.bonusType == 'none'
          ? ''
          : _formatInitialAmount(plan.bonusValue),
    );
    _renewalPolicy = plan?.renewalPolicy ?? 'manual';
    _autoRenewSupported = plan?.autoRenewSupported ?? false;
    _bonusExpiresWithCycle = plan?.bonusExpiresWithCycle ?? true;
    _isActive = plan?.isActive ?? true;
    _isForSale = plan?.isForSale ?? true;
    _productScope = plan?.productScope == 'selected' ? 'selected' : 'all';
    for (final product
        in plan?.products ?? const <AdminSubscriptionPlanProduct>[]) {
      _selectedProducts[product.id] = product;
    }
  }

  @override
  void dispose() {
    _nameAr.dispose();
    _nameEn.dispose();
    _code.dispose();
    _descriptionAr.dispose();
    _descriptionEn.dispose();
    _price.dispose();
    _currency.dispose();
    _duration.dispose();
    _cups.dispose();
    _rollover.dispose();
    _bonusValue.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AdminSubscriptionPlanCubit>.value(
      value: widget.cubit,
      child:
          BlocBuilder<AdminSubscriptionPlanCubit, AdminSubscriptionPlanState>(
            builder: (context, planState) => _buildDialog(context, planState),
          ),
    );
  }

  Widget _buildDialog(
    BuildContext context,
    AdminSubscriptionPlanState planState,
  ) {
    final theme = Theme.of(context);
    final dark = adminIsDark(theme);
    final narrow =
        MediaQuery.sizeOf(context).width < AppBreakpoints.dialogPadding;

    return Dialog(
      clipBehavior: Clip.antiAlias,
      insetPadding: EdgeInsets.symmetric(
        horizontal: narrow ? AppSpacing.md : AppSpacing.xxxl,
        vertical: AppSpacing.lg,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DialogHeader(
              title: _isEditing
                  ? S.subscriptionPlanEditTitle
                  : S.subscriptionPlanAddTitle,
              onClose: _saving ? null : () => Navigator.of(context).pop(),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                child: Form(
                  key: _formKey,
                  autovalidateMode: _autovalidate,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _section(S.subscriptionPlanIdentitySection),
                      _row([
                        _field(
                          fieldKey: const Key('plan-name-ar'),
                          controller: _nameAr,
                          label: S.subscriptionPlanNameAr,
                          textInputAction: TextInputAction.next,
                          validator: _validateRequired,
                        ),
                        _field(
                          fieldKey: const Key('plan-name-en'),
                          controller: _nameEn,
                          label: S.subscriptionPlanNameEn,
                          textInputAction: TextInputAction.next,
                          validator: _validateRequired,
                        ),
                      ]),
                      _row([
                        _field(
                          fieldKey: const Key('plan-code'),
                          controller: _code,
                          label: S.subscriptionPlanCodeLabel,
                          hint: S.subscriptionPlanCodeHint,
                          keyboardType: TextInputType.text,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[A-Za-z0-9_-]'),
                            ),
                            LengthLimitingTextInputFormatter(40),
                          ],
                          validator: _validateCode,
                        ),
                      ]),
                      _field(
                        controller: _descriptionAr,
                        label: S.subscriptionPlanDescriptionAr,
                        maxLines: 2,
                        textInputAction: TextInputAction.newline,
                      ),
                      _field(
                        controller: _descriptionEn,
                        label: S.subscriptionPlanDescriptionEn,
                        maxLines: 2,
                        textInputAction: TextInputAction.newline,
                      ),
                      _section(S.subscriptionPlanPricingSection),
                      _row([
                        _field(
                          fieldKey: const Key('plan-price'),
                          controller: _price,
                          label: S.subscriptionPlanPriceLabel,
                          hint: '0.00',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [_decimalFormatter],
                          validator: _validatePrice,
                        ),
                        _field(
                          fieldKey: const Key('plan-currency'),
                          controller: _currency,
                          label: S.subscriptionPlanCurrencyLabel,
                          hint: 'SAR',
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp('[a-zA-Z]'),
                            ),
                            LengthLimitingTextInputFormatter(3),
                          ],
                          validator: _validateCurrency,
                        ),
                      ]),
                      _row([
                        _field(
                          fieldKey: const Key('plan-duration'),
                          controller: _duration,
                          label: S.subscriptionPlanDurationDays,
                          hint: '30',
                          keyboardType: TextInputType.number,
                          inputFormatters: [_integerFormatter],
                          validator: _validateDuration,
                        ),
                        _field(
                          fieldKey: const Key('plan-cups'),
                          controller: _cups,
                          label: S.subscriptionPlanCupsLabel,
                          hint: '10',
                          keyboardType: TextInputType.number,
                          inputFormatters: [_integerFormatter],
                          validator: _validateCups,
                        ),
                        _field(
                          fieldKey: const Key('plan-rollover'),
                          controller: _rollover,
                          label: S.subscriptionPlanRolloverLabel,
                          hint: '0',
                          keyboardType: TextInputType.number,
                          inputFormatters: [_integerFormatter],
                          validator: _validateRollover,
                        ),
                      ]),
                      _section(S.subscriptionPlanBenefitsSection),
                      _choiceRow<String>(
                        label: S.subscriptionPlanBonusType,
                        values: const ['none', 'percent', 'fixed', 'points'],
                        selected: _bonusType,
                        labelFor: (value) => switch (value) {
                          'percent' => S.subscriptionPlanBonusPercent,
                          'fixed' => S.subscriptionPlanBonusFixed,
                          'points' => S.subscriptionPlanBonusPoints,
                          _ => S.subscriptionPlanBonusNone,
                        },
                        onChanged: (value) => setState(() {
                          _bonusType = value;
                          _error = null;
                        }),
                      ),
                      if (_bonusType != 'none')
                        _row([
                          _field(
                            fieldKey: const Key('plan-bonus-value'),
                            controller: _bonusValue,
                            label: S.subscriptionPlanBonusValue,
                            hint: '0',
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [_decimalFormatter],
                            validator: _validateBonusValue,
                          ),
                        ]),
                      if (_bonusType != 'none')
                        _switchTile(
                          title: S.subscriptionPlanBonusExpires,
                          value: _bonusExpiresWithCycle,
                          onChanged: (value) =>
                              setState(() => _bonusExpiresWithCycle = value),
                        ),
                      _choiceRow<String>(
                        label: S.subscriptionPlanRenewalPolicy,
                        values: const ['manual', 'auto'],
                        selected: _renewalPolicy,
                        labelFor: (value) => value == 'auto'
                            ? S.subscriptionPlanRenewalAuto
                            : S.subscriptionPlanRenewalManual,
                        onChanged: (value) => setState(() {
                          _renewalPolicy = value;
                          if (value == 'auto') _autoRenewSupported = true;
                        }),
                      ),
                      _switchTile(
                        title: S.subscriptionPlanAutoRenewSupported,
                        value: _autoRenewSupported,
                        onChanged: (value) => setState(() {
                          _autoRenewSupported = value;
                          if (!value) _renewalPolicy = 'manual';
                        }),
                      ),
                      _section(S.subscriptionPlanProductsSection),
                      _productsSection(planState),
                      _section(S.subscriptionPlanVisibilitySection),
                      _switchTile(
                        title: S.subscriptionPlanActiveLabel,
                        subtitle: S.subscriptionPlanActiveHint,
                        value: _isActive,
                        onChanged: (value) => setState(() => _isActive = value),
                      ),
                      _switchTile(
                        title: S.subscriptionPlanForSaleLabel,
                        subtitle: S.subscriptionPlanForSaleHint,
                        value: _isForSale,
                        onChanged: (value) =>
                            setState(() => _isForSale = value),
                      ),
                      if (_isEditing) _scopePanel(widget.plan!),
                      if (_error != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        _ErrorBanner(message: _error!),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            _DialogFooter(
              saving: _saving,
              onCancel: () => Navigator.of(context).pop(),
              onSave: _save,
              dark: dark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: AppColor.adminAccent,
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
          ),
          const SizedBox(width: AppSizes.px8),
          Text(
            title,
            style: TextStyle(
              color: adminHeadingColor(theme),
              fontSize: AppFontSizes.size12_5,
              fontWeight: AppFontWeights.bold,
              height: AppTextHeights.line1_5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(List<Widget> children) {
    final wide = MediaQuery.sizeOf(context).width >= 640;
    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < children.length; index++) ...[
            if (index > 0) const SizedBox(width: AppSpacing.md),
            Expanded(child: children[index]),
          ],
        ],
      );
    }
    return Column(children: children);
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    Key? fieldKey,
    String? hint,
    TextInputType? keyboardType,
    TextInputAction textInputAction = TextInputAction.next,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return CustomTextFormField(
      key: fieldKey,
      controller: controller,
      label: label,
      hint: hint ?? label,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      inputFormatters: inputFormatters,
      validator: validator,
      maxLines: maxLines,
    );
  }

  Widget _choiceRow<T>({
    required String label,
    required List<T> values,
    required T selected,
    required String Function(T value) labelFor,
    required ValueChanged<T> onChanged,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: adminMutedColor(theme),
              fontSize: AppFontSizes.size10_5,
              fontWeight: AppFontWeights.semiBold,
              height: AppTextHeights.line1_5,
            ),
          ),
          const SizedBox(height: AppSizes.px6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final value in values)
                ChoiceChip(
                  label: Text(labelFor(value)),
                  selected: value == selected,
                  onSelected: _saving ? null : (_) => onChanged(value),
                  labelStyle: TextStyle(
                    fontSize: AppFontSizes.size11,
                    fontWeight: value == selected
                        ? AppFontWeights.semiBold
                        : AppFontWeights.regular,
                    height: AppTextHeights.line1_5,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _switchTile({
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(
        title,
        style: TextStyle(
          color: adminBodyColor(theme),
          fontSize: AppFontSizes.size11_5,
          fontWeight: AppFontWeights.semiBold,
          height: AppTextHeights.line1_5,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle,
              style: TextStyle(
                color: adminMutedColor(theme),
                fontSize: AppFontSizes.size9_5,
                height: AppTextHeights.line1_5,
              ),
            ),
      value: value,
      onChanged: _saving ? null : onChanged,
    );
  }

  Widget _productsSection(AdminSubscriptionPlanState planState) {
    final theme = Theme.of(context);
    final scopeSelected = _productScope == 'selected';
    final options = planState.productOptions;
    final selected = _selectedProducts.values.toList(growable: false);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: adminTintedSurfaceColor(theme),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: adminCardBorderColor(theme)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            S.subscriptionPlanProductsHint,
            style: TextStyle(
              color: adminMutedColor(theme),
              fontSize: AppFontSizes.size9_5,
              height: AppTextHeights.line1_5,
            ),
          ),
          const SizedBox(height: AppSizes.px8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                key: const Key('plan-product-scope-all'),
                label: Text(S.subscriptionPlanAllProducts),
                selected: !scopeSelected,
                onSelected: _saving
                    ? null
                    : (_) => setState(() {
                        _productScope = 'all';
                        _error = null;
                      }),
                labelStyle: const TextStyle(
                  fontSize: AppFontSizes.size11,
                  height: AppTextHeights.line1_5,
                ),
              ),
              ChoiceChip(
                key: const Key('plan-product-scope-selected'),
                label: Text(S.subscriptionPlanSelectedProducts),
                selected: scopeSelected,
                onSelected: _saving
                    ? null
                    : (_) {
                        setState(() {
                          _productScope = 'selected';
                          _error = null;
                        });
                        final planState = widget.cubit.state;
                        if (planState.productOptions.isEmpty &&
                            !planState.productOptionsLoading) {
                          widget.cubit.loadProductOptions();
                        }
                      },
                labelStyle: const TextStyle(
                  fontSize: AppFontSizes.size11,
                  height: AppTextHeights.line1_5,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.px8),
          Text(
            scopeSelected
                ? S.subscriptionPlanProductsSelectedHint
                : S.subscriptionPlanProductsAllHint,
            style: TextStyle(
              color: adminMutedColor(theme),
              fontSize: AppFontSizes.size9_5,
              height: AppTextHeights.line1_5,
            ),
          ),
          if (scopeSelected) ...[
            const SizedBox(height: AppSizes.px10),
            if (planState.productOptionsLoading && options.isEmpty)
              _ProductOptionsMessage(
                icon: AppIcons.loading03,
                message: S.subscriptionPlanProductsLoading,
                busy: true,
              )
            else if (options.isEmpty)
              _ProductOptionsMessage(
                icon: planState.productOptionsError != null
                    ? AppIcons.alert
                    : AppIcons.package,
                message: planState.productOptionsError != null
                    ? S.subscriptionPlanProductsLoadFailed
                    : S.subscriptionPlanProductsEmptyCatalog,
                action: TextButton(
                  onPressed: _saving ? null : widget.cubit.loadProductOptions,
                  child: Text(S.retry),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: Text(
                      localizeDigits(
                        S.subscriptionPlanProductsSelectedCount(
                          selected.length,
                        ),
                      ),
                      style: TextStyle(
                        color: adminBodyColor(theme),
                        fontSize: AppFontSizes.size10_5,
                        fontWeight: AppFontWeights.semiBold,
                        height: AppTextHeights.line1_5,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    key: const Key('plan-products-choose'),
                    onPressed: _saving ? null : _pickProducts,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 32),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(AppIcons.edit01, size: 15),
                    label: Text(
                      selected.isEmpty
                          ? S.subscriptionPlanProductsChoose
                          : S.subscriptionPlanProductsChange,
                    ),
                  ),
                ],
              ),
            if (selected.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  S.subscriptionPlanProductsNoneSelected,
                  style: TextStyle(
                    color: adminMutedColor(theme),
                    fontSize: AppFontSizes.size9_5,
                    height: AppTextHeights.line1_5,
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final product in selected)
                      InputChip(
                        label: Text(
                          product.nameFor(AppLocale.instance.language),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        labelStyle: TextStyle(
                          fontSize: AppFontSizes.size10,
                          height: AppTextHeights.line1_5,
                          color: adminBodyColor(theme),
                        ),
                        onDeleted: _saving
                            ? null
                            : () => setState(
                                () => _selectedProducts.remove(product.id),
                              ),
                        deleteIcon: const Icon(AppIcons.cancel01, size: 14),
                        deleteButtonTooltipMessage:
                            S.subscriptionPlanProductRemove,
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          6,
                          0,
                          0,
                          0,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickProducts() async {
    if (_saving) return;
    final options = widget.cubit.state.productOptions;
    if (options.isEmpty) return;
    final result = await showSubscriptionPlanProductPicker(
      context: context,
      products: options,
      initialSelection: _selectedProducts.keys.toSet(),
    );
    if (result == null || !mounted) return;
    final byId = {for (final product in options) product.id: product};
    setState(() {
      _selectedProducts.removeWhere((id, _) => byId.containsKey(id));
      for (final id in result) {
        final product = byId[id];
        if (product != null) _selectedProducts[id] = product;
      }
      _error = null;
    });
  }

  Widget _scopePanel(AdminSubscriptionPlan plan) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: adminTintedSurfaceColor(theme),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: adminCardBorderColor(theme)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ScopeRow(
            label: S.branches,
            value: subscriptionPlanBranchesScope(plan),
          ),
        ],
      ),
    );
  }

  String? _validateRequired(String? value) {
    if ((value ?? '').trim().isEmpty) return S.subscriptionPlanRequired;
    return null;
  }

  String? _validateCode(String? value) {
    final code = (value ?? '').trim().toUpperCase();
    if (code.isEmpty) return S.subscriptionPlanRequired;
    if (!RegExp(r'^[A-Z0-9_-]{2,40}$').hasMatch(code)) {
      return S.subscriptionPlanInvalidCode;
    }
    return null;
  }

  String? _validatePrice(String? value) {
    final amount = _parseDecimal(value);
    if (amount == null || amount < 0) return S.subscriptionPlanInvalidPrice;
    return null;
  }

  String? _validateCurrency(String? value) {
    final currency = (value ?? '').trim().toUpperCase();
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(currency)) {
      return S.subscriptionPlanInvalidCurrency;
    }
    return null;
  }

  String? _validateDuration(String? value) {
    final days = int.tryParse(_normalizeDigits((value ?? '').trim()));
    if (days == null) return S.subscriptionPlanInvalidNumber;
    if (days < 1) return S.subscriptionPlanInvalidDays;
    return null;
  }

  String? _validateCups(String? value) {
    final cups = int.tryParse(_normalizeDigits((value ?? '').trim()));
    if (cups == null || cups < 0) return S.subscriptionPlanInvalidNumber;
    return null;
  }

  String? _validateRollover(String? value) {
    final text = _normalizeDigits((value ?? '').trim());
    if (text.isEmpty) return null;
    final cups = int.tryParse(text);
    if (cups == null || cups < 0) return S.subscriptionPlanInvalidNumber;
    return null;
  }

  String? _validateBonusValue(String? value) {
    final amount = _parseDecimal(value);
    if (amount == null || amount < 0) return S.subscriptionPlanInvalidNumber;
    if (_bonusType == 'percent' && amount > 100) {
      return S.subscriptionPlanInvalidNumber;
    }
    return null;
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _autovalidate = AutovalidateMode.onUserInteraction;
      _error = null;
    });
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_productScope == 'selected' && _selectedProducts.isEmpty) {
      setState(() => _error = S.subscriptionPlanProductsRequired);
      return;
    }

    final draft = AdminSubscriptionPlanDraft(
      id: widget.plan?.id,
      code: _code.text.trim().toUpperCase(),
      nameAr: _nameAr.text.trim(),
      nameEn: _nameEn.text.trim(),
      descriptionAr: _descriptionAr.text.trim(),
      descriptionEn: _descriptionEn.text.trim(),
      price: _parseDecimal(_price.text) ?? 0,
      currencyCode: _currency.text.trim().toUpperCase(),
      durationDays: int.tryParse(_normalizeDigits(_duration.text.trim())) ?? 0,
      cupsPerCycle: int.tryParse(_normalizeDigits(_cups.text.trim())) ?? 0,
      bonusType: _bonusType,
      bonusValue: _bonusType == 'none'
          ? 0
          : (_parseDecimal(_bonusValue.text) ?? 0),
      bonusExpiresWithCycle: _bonusExpiresWithCycle,
      rolloverCapCups:
          int.tryParse(_normalizeDigits(_rollover.text.trim())) ?? 0,
      renewalPolicy: _renewalPolicy,
      autoRenewSupported: _autoRenewSupported,
      productScope: _productScope,
      productIds: _productScope == 'selected'
          ? _selectedProducts.keys.toList(growable: false)
          : const <String>[],
      isActive: _isActive,
      isForSale: _isForSale,
    );

    setState(() => _saving = true);
    final outcome = await widget.cubit.savePlan(draft);
    if (!mounted) return;
    setState(() => _saving = false);

    switch (outcome) {
      case SubscriptionPlanSaveOutcome.saved:
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).pop();
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(S.subscriptionPlanSaved)));
        break;
      case SubscriptionPlanSaveOutcome.duplicateCode:
        setState(() => _error = S.subscriptionPlanDuplicateCode);
        break;
      case SubscriptionPlanSaveOutcome.invalidData:
        setState(() => _error = S.subscriptionPlanInvalidData);
        break;
      case SubscriptionPlanSaveOutcome.missingProducts:
        setState(() => _error = S.subscriptionPlanProductsSaveMissing);
        break;
      case SubscriptionPlanSaveOutcome.invalidProducts:
        setState(() => _error = S.subscriptionPlanProductsSaveInvalid);
        break;
      case SubscriptionPlanSaveOutcome.notFound:
        setState(() => _error = S.subscriptionPlanNotFound);
        break;
      case SubscriptionPlanSaveOutcome.failed:
        setState(() => _error = S.subscriptionPlanSaveFailed);
        break;
    }
  }
}

class _DialogHeader extends StatelessWidget {
  const _DialogHeader({required this.title, required this.onClose});

  final String title;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = adminIsDark(theme);
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(bottom: BorderSide(color: adminRowBorderColor(theme))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: adminHeadingColor(theme),
                fontSize: AppFontSizes.size16,
                fontWeight: AppFontWeights.bold,
                height: AppTextHeights.line1_5,
              ),
            ),
          ),
          IconButton(
            tooltip: S.close,
            onPressed: onClose,
            style: IconButton.styleFrom(
              fixedSize: const Size(36, 36),
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: AppIcon(
              AppIcons.cancel01,
              size: 18,
              color: dark ? AppColor.darkTextSecondary : AppColor.adminMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _DialogFooter extends StatelessWidget {
  const _DialogFooter({
    required this.saving,
    required this.onCancel,
    required this.onSave,
    required this.dark,
  });

  final bool saving;
  final VoidCallback onCancel;
  final VoidCallback onSave;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: dark ? AppColor.darkBorder : AppColor.adminRowBorder,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: saving ? null : onCancel,
            child: Text(S.cancel),
          ),
          const SizedBox(width: AppSizes.px8),
          FilledButton(
            onPressed: saving ? null : onSave,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 38),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (saving) ...[
                  const SizedBox(
                    width: AppSizes.px14,
                    height: AppSizes.px14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColor.whiteColor,
                    ),
                  ),
                  const SizedBox(width: AppSizes.px8),
                ],
                Text(
                  saving
                      ? S.subscriptionPlanSaving
                      : S.subscriptionPlanSaveAction,
                  style: const TextStyle(
                    fontSize: AppFontSizes.size11,
                    fontWeight: AppFontWeights.semiBold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductOptionsMessage extends StatelessWidget {
  const _ProductOptionsMessage({
    required this.icon,
    required this.message,
    this.action,
    this.busy = false,
  });

  final IconData icon;
  final String message;
  final Widget? action;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        if (busy)
          const SizedBox(
            width: AppSizes.px14,
            height: AppSizes.px14,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          AppIcon(icon, size: 16, color: adminMutedColor(theme)),
        const SizedBox(width: AppSizes.px8),
        Expanded(
          child: Text(
            message,
            style: TextStyle(
              color: adminMutedColor(theme),
              fontSize: AppFontSizes.size9_5,
              height: AppTextHeights.line1_5,
            ),
          ),
        ),
        ?action,
      ],
    );
  }
}

class _ScopeRow extends StatelessWidget {
  const _ScopeRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: adminMutedColor(theme),
              fontSize: AppFontSizes.size10,
              height: AppTextHeights.line1_5,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: adminBodyColor(theme),
            fontSize: AppFontSizes.size10_5,
            fontWeight: AppFontWeights.semiBold,
            height: AppTextHeights.line1_5,
          ),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColor.errorColor.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColor.errorColor.withValues(alpha: .3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppIcon(AppIcons.alert, size: 16, color: AppColor.errorColor),
          const SizedBox(width: AppSizes.px8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColor.errorColor,
                fontSize: AppFontSizes.size10_5,
                height: AppTextHeights.line1_5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final _decimalFormatter = FilteringTextInputFormatter.allow(
  RegExp('[0-9٠-٩٫.,]'),
);

final _integerFormatter = FilteringTextInputFormatter.allow(RegExp('[0-9٠-٩]'));

double? _parseDecimal(String? value) {
  final text = _normalizeDigits((value ?? '').trim()).replaceAll(',', '');
  if (text.isEmpty) return null;
  return double.tryParse(text);
}

String _normalizeDigits(String value) {
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  const western = '0123456789';
  final buffer = StringBuffer();
  for (final character in value.split('')) {
    if (character == '٫' || character == '٬') {
      buffer.write(character == '٫' ? '.' : '');
      continue;
    }
    final index = arabic.indexOf(character);
    buffer.write(index >= 0 ? western[index] : character);
  }
  return buffer.toString();
}

String _formatInitialAmount(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(2);
}
