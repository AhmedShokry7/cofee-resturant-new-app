import 'package:material_ui/material_ui.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/loyalty/domain/entities/admin_loyalty_rule_draft.dart';
import 'package:admin_app/features/loyalty/domain/entities/admin_loyalty_rule.dart';
import 'package:admin_app/features/loyalty/domain/repositories/loyalty_repository.dart';
import 'package:admin_app/features/loyalty/presentation/manager/admin_loyalty_cubit.dart';
import 'package:admin_app/features/loyalty/presentation/widgets/loyalty_format.dart';
import 'package:admin_app/features/loyalty/presentation/widgets/loyalty_money_bits.dart';
import 'package:admin_app/shared/widgets/admin_dialog_chrome.dart';
import 'package:admin_app/shared/widgets/admin_help_button.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/custom_text_form_field.dart';

Future<void> showLoyaltyRuleDialog({
  required BuildContext context,
  required AdminLoyaltyCubit cubit,
  AdminLoyaltyRule? rule,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => LoyaltyRuleDialog(cubit: cubit, rule: rule),
  );
}

/// Edits the earning program itself: how many points a unit of currency
/// earns, what a point is worth, and whether the program is running.
class LoyaltyRuleDialog extends StatefulWidget {
  const LoyaltyRuleDialog({super.key, required this.cubit, this.rule});

  final AdminLoyaltyCubit cubit;
  final AdminLoyaltyRule? rule;

  @override
  State<LoyaltyRuleDialog> createState() => _LoyaltyRuleDialogState();
}

class _LoyaltyRuleDialogState extends State<LoyaltyRuleDialog> {
  static const _ratePresets = <double>[0.5, 1, 2, 5];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _rate;
  late final TextEditingController _value;
  late final TextEditingController _previewAmount;
  late bool _isActive;
  bool _saving = false;
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;
  String? _error;

  @override
  void initState() {
    super.initState();
    final rule = widget.rule;
    _rate = TextEditingController(
      text: _numberText(rule?.pointsPerCurrencyUnit ?? 1),
    );
    _value = TextEditingController(text: _numberText(rule?.pointValue ?? 0.05));
    _previewAmount = TextEditingController(text: '100');
    _isActive = rule?.isActive ?? true;
    _rate.addListener(_onFieldChanged);
    _value.addListener(_onFieldChanged);
    _previewAmount.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _rate
      ..removeListener(_onFieldChanged)
      ..dispose();
    _value
      ..removeListener(_onFieldChanged)
      ..dispose();
    _previewAmount
      ..removeListener(_onFieldChanged)
      ..dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
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
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AdminDialogHeader(
              title: S.loyaltyProgramDialogTitle,
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
                      _intro(),
                      const SizedBox(height: AppSpacing.md),
                      _field(
                        fieldKey: const Key('loyalty-rule-rate'),
                        controller: _rate,
                        label: S.loyaltyProgramRateField,
                        hint: S.loyaltyProgramRateHint,
                        helper: S.loyaltyProgramRateHelp,
                        helpMessage: S.loyaltyProgramRateTooltip,
                        validator: _validateRate,
                      ),
                      _ratePresetPicker(),
                      _field(
                        fieldKey: const Key('loyalty-rule-value'),
                        controller: _value,
                        label: S.loyaltyProgramValueField,
                        hint: S.loyaltyProgramValueHint,
                        helper: S.loyaltyProgramValueHelp,
                        helpMessage: S.loyaltyProgramValueTooltip,
                        validator: _validateValue,
                        currencyIconOutside: true,
                      ),
                      _previewAmountField(),
                      _preview(),
                      const SizedBox(height: AppSpacing.sm),
                      _changeImpact(),
                      const SizedBox(height: AppSpacing.sm),
                      _switchTile(),
                      if (_error != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        AdminErrorBanner(message: _error!),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            AdminDialogFooter(
              saving: _saving,
              onCancel: () => Navigator.of(context).pop(),
              onSave: _save,
              saveKey: const Key('loyalty-rule-save'),
              saveLabel: S.loyaltyProgramSaveAction,
              savingLabel: S.loyaltyProgramSaving,
            ),
          ],
        ),
      ),
    );
  }

  Widget _intro() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: adminTintedSurfaceColor(theme),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: adminCardBorderColor(theme)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: adminFlagBackground(
                theme,
                AppColor.adminAccent,
                AppColor.adminAccentSurface,
              ),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: AppIcon(
              AppIcons.gift,
              size: 17,
              color: adminFlagForeground(theme, AppColor.adminAccent),
            ),
          ),
          const SizedBox(width: AppSizes.px10),
          Expanded(
            child: Text(
              S.loyaltyProgramDialogIntro,
              style: TextStyle(
                color: adminBodyColor(theme),
                fontSize: AppFontSizes.size10,
                height: AppTextHeights.line1_6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required Key fieldKey,
    required TextEditingController controller,
    required String label,
    required String hint,
    required String? helper,
    String? helpMessage,
    required String? Function(String?) validator,
    Widget? suffixIcon,
    bool currencyIconOutside = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CustomTextFormField(
          key: fieldKey,
          controller: controller,
          label: label,
          labelTrailing: helpMessage == null
              ? null
              : AdminHelpButton(title: label, message: helpMessage),
          hint: hint,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: validator,
          suffixIcon: suffixIcon,
          currencyIconOutside: currencyIconOutside,
          bottomPadding: 4,
        ),
        if (helper != null && helper.isNotEmpty)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 12, bottom: 12),
            child: Text(
              helper,
              style: TextStyle(
                color: adminMutedColor(Theme.of(context)),
                fontSize: AppFontSizes.size9,
                height: AppTextHeights.line1_5,
              ),
            ),
          ),
      ],
    );
  }

  Widget _ratePresetPicker() {
    final theme = Theme.of(context);
    final selectedRate = _parse(_rate.text);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 12, bottom: 6),
            child: Text(
              S.loyaltyProgramPresetsLabel,
              style: TextStyle(
                color: adminMutedColor(theme),
                fontSize: AppFontSizes.size9,
              ),
            ),
          ),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final rate in _ratePresets)
                ChoiceChip(
                  key: ValueKey('loyalty-rate-preset-$rate'),
                  label: Text(localizeDigits(S.loyaltyProgramPreset(rate))),
                  selected: selectedRate == rate,
                  onSelected: _saving
                      ? null
                      : (_) => _rate.text = _numberText(rate),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _previewAmountField() => _field(
    fieldKey: const Key('loyalty-rule-preview-amount'),
    controller: _previewAmount,
    label: S.loyaltyProgramPreviewAmountLabel,
    hint: S.loyaltyProgramPreviewAmountHint,
    helper: null,
    validator: (_) => null,
    currencyIconOutside: true,
  );

  Widget _changeImpact() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: adminTintedSurfaceColor(theme),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: adminCardBorderColor(theme)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIcon(
            AppIcons.informationCircle,
            size: 15,
            color: adminMutedColor(theme),
          ),
          const SizedBox(width: AppSizes.px8),
          Expanded(
            child: Text(
              S.loyaltyProgramChangeImpact,
              style: TextStyle(
                color: adminMutedColor(theme),
                fontSize: AppFontSizes.size9,
                height: AppTextHeights.line1_5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _preview() {
    final theme = Theme.of(context);
    final rate = _parse(_rate.text);
    final value = _parse(_value.text);
    final amount = _parse(_previewAmount.text);
    final valid =
        rate != null &&
        rate > 0 &&
        rate <= 1000 &&
        value != null &&
        value >= 0 &&
        value <= 1000 &&
        amount != null &&
        amount > 0 &&
        amount <= 1000000;
    final points = valid ? (amount * rate).floor() : 0;
    final worth = valid ? points * value : 0;
    final returnPercent = valid ? worth / amount * 100 : 0;
    final earnAmount = loyaltyCompactNumber(amount ?? 0);
    final worthAmount = loyaltyCompactNumber(worth);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: adminFlagBackground(
          theme,
          AppColor.adminAccent,
          AppColor.adminAccentSurface,
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppColor.adminAccent.withValues(
            alpha: adminIsDark(theme) ? .28 : .16,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AppIcon(
                AppIcons.chartLineData01,
                size: 15,
                color: adminFlagForeground(theme, AppColor.adminAccent),
              ),
              const SizedBox(width: AppSizes.px6),
              Text(
                S.loyaltyProgramPreviewTitle,
                style: TextStyle(
                  color: adminFlagForeground(theme, AppColor.adminAccent),
                  fontSize: AppFontSizes.size10,
                  fontWeight: AppFontWeights.bold,
                  height: AppTextHeights.line1_5,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.px8),
          if (!valid)
            Text(
              S.loyaltyProgramPreviewPending,
              style: TextStyle(
                color: adminMutedColor(theme),
                fontSize: AppFontSizes.size9_5,
                height: AppTextHeights.line1_5,
              ),
            )
          else ...[
            _previewRow(
              icon: AppIcons.shoppingBag01,
              sentence: loyaltyMoneySentence(
                earnAmount,
                S.loyaltyProgramPreviewEarn(
                  loyaltyMoneySlot(earnAmount),
                  loyaltyCompactNumber(points),
                ),
              ),
            ),
            const SizedBox(height: AppSizes.px6),
            _previewRow(
              icon: AppIcons.star,
              sentence: loyaltyMoneySentence(
                worthAmount,
                S.loyaltyProgramPreviewWorth(
                  loyaltyCompactNumber(points),
                  loyaltyMoneySlot(worthAmount),
                ),
              ),
            ),
            const SizedBox(height: AppSizes.px6),
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 22),
              child: Text(
                localizeDigits(
                  S.loyaltyProgramPreviewReturn(
                    loyaltyCompactNumber(returnPercent),
                  ),
                ),
                style: TextStyle(
                  color: adminFlagForeground(theme, AppColor.adminAccent),
                  fontSize: AppFontSizes.size9,
                  height: AppTextHeights.line1_5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _previewRow({
    required IconData icon,
    required LoyaltyMoneySentence sentence,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        AppIcon(
          icon,
          size: 14,
          color: adminFlagForeground(theme, AppColor.adminAccent),
        ),
        const SizedBox(width: AppSizes.px8),
        Expanded(
          child: LoyaltyMoneyText(
            sentence: sentence,
            style: TextStyle(
              color: adminFlagForeground(theme, AppColor.adminAccent),
              fontSize: AppFontSizes.size10,
              fontWeight: AppFontWeights.semiBold,
              height: AppTextHeights.line1_5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _switchTile() {
    final theme = Theme.of(context);
    return SwitchListTile(
      key: const Key('loyalty-rule-active'),
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(
        S.loyaltyProgramActiveTitle,
        style: TextStyle(
          color: adminBodyColor(theme),
          fontSize: AppFontSizes.size11_5,
          fontWeight: AppFontWeights.semiBold,
          height: AppTextHeights.line1_5,
        ),
      ),
      subtitle: Text(
        S.loyaltyProgramActiveHelp,
        style: TextStyle(
          color: adminMutedColor(theme),
          fontSize: AppFontSizes.size9_5,
          height: AppTextHeights.line1_5,
        ),
      ),
      value: _isActive,
      onChanged: _saving ? null : (value) => setState(() => _isActive = value),
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _autovalidate = AutovalidateMode.onUserInteraction;
      _error = null;
    });
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final rate = _parse(_rate.text);
    final value = _parse(_value.text);
    if (rate == null || value == null) return;

    setState(() => _saving = true);
    final outcome = await widget.cubit.saveRule(
      AdminLoyaltyRuleDraft(
        id: widget.rule?.id,
        pointsPerCurrencyUnit: rate,
        pointValue: value,
        isActive: _isActive,
      ),
    );
    if (!mounted) return;
    setState(() => _saving = false);

    switch (outcome) {
      case LoyaltyRuleSaveOutcome.saved:
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).pop();
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(S.loyaltyProgramSaved)));
        break;
      case LoyaltyRuleSaveOutcome.invalidRate:
        setState(() => _error = S.loyaltyProgramInvalidRate);
        break;
      case LoyaltyRuleSaveOutcome.invalidValue:
        setState(() => _error = S.loyaltyProgramInvalidValue);
        break;
      case LoyaltyRuleSaveOutcome.notFound:
        setState(() => _error = S.loyaltyProgramNotFound);
        break;
      case LoyaltyRuleSaveOutcome.failed:
        setState(() => _error = S.loyaltyProgramSaveFailed);
        break;
    }
  }

  String? _validateRate(String? value) {
    final raw = value ?? '';
    final rate = _parse(raw);
    if (rate == null || rate <= 0 || rate > 1000 || !_hasPrecision(raw, 4)) {
      return S.loyaltyProgramInvalidRate;
    }
    return null;
  }

  String? _validateValue(String? value) {
    final raw = value ?? '';
    final pointValue = _parse(raw);
    if (pointValue == null ||
        pointValue < 0 ||
        pointValue > 1000 ||
        !_hasPrecision(raw, 2)) {
      return S.loyaltyProgramInvalidValue;
    }
    return null;
  }

  static double? _parse(String raw) {
    final normalized = normalizeDigits(raw.trim()).replaceAll(',', '');
    if (normalized.isEmpty || normalized == '.') return null;
    return double.tryParse(normalized);
  }

  static bool _hasPrecision(String raw, int decimalPlaces) {
    final normalized = normalizeDigits(raw.trim()).replaceAll(',', '');
    final decimalIndex = normalized.indexOf('.');
    return decimalIndex < 0 ||
        normalized.length - decimalIndex - 1 <= decimalPlaces;
  }

  static String _numberText(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    var text = value.toStringAsFixed(4);
    while (text.endsWith('0')) {
      text = text.substring(0, text.length - 1);
    }
    if (text.endsWith('.')) text = text.substring(0, text.length - 1);
    return text;
  }
}
