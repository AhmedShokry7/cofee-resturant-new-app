import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/loyalty/data/models/admin_loyalty_rule.dart';
import 'package:admin_app/features/loyalty/data/models/admin_loyalty_rule_draft.dart';
import 'package:admin_app/features/loyalty/data/repositories/admin_loyalty_repository.dart';
import 'package:admin_app/features/loyalty/presentation/manager/admin_loyalty_cubit.dart';
import 'package:admin_app/features/loyalty/presentation/widgets/loyalty_format.dart';
import 'package:admin_app/shared/widgets/admin_dialog_chrome.dart';
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
  static const _previewAmount = 100.0;
  static const _previewPoints = 100.0;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _rate;
  late final TextEditingController _value;
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
    _isActive = rule?.isActive ?? true;
    _rate.addListener(_onFieldChanged);
    _value.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _rate
      ..removeListener(_onFieldChanged)
      ..dispose();
    _value
      ..removeListener(_onFieldChanged)
      ..dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 600;
    return Dialog(
      clipBehavior: Clip.antiAlias,
      insetPadding: EdgeInsets.symmetric(
        horizontal: narrow ? AppDimensions.md : AppDimensions.xxl,
        vertical: AppDimensions.lg,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
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
                  AppDimensions.lg,
                  AppDimensions.md,
                  AppDimensions.lg,
                  AppDimensions.lg,
                ),
                child: Form(
                  key: _formKey,
                  autovalidateMode: _autovalidate,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _intro(),
                      const SizedBox(height: AppDimensions.md),
                      _field(
                        fieldKey: const Key('loyalty-rule-rate'),
                        controller: _rate,
                        label: S.loyaltyProgramRateField,
                        hint: S.loyaltyProgramRateHint,
                        helper: S.loyaltyProgramRateHelp,
                        validator: _validateRate,
                      ),
                      _field(
                        fieldKey: const Key('loyalty-rule-value'),
                        controller: _value,
                        label: S.loyaltyProgramValueField,
                        hint: S.loyaltyProgramValueHint,
                        helper: S.loyaltyProgramValueHelp,
                        validator: _validateValue,
                      ),
                      _preview(),
                      const SizedBox(height: AppDimensions.sm),
                      _switchTile(),
                      if (_error != null) ...[
                        const SizedBox(height: AppDimensions.sm),
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
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: adminTintedSurfaceColor(theme),
        borderRadius: BorderRadius.circular(10),
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
              borderRadius: BorderRadius.circular(9),
            ),
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedGift,
              size: 17,
              color: adminFlagForeground(theme, AppColor.adminAccent),
            ),
          ),
          const SizedBox(width: 10),
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
    required String helper,
    required String? Function(String?) validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CustomTextFormField(
          key: fieldKey,
          controller: controller,
          label: label,
          hint: hint,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: validator,
          bottomPadding: 4,
        ),
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

  Widget _preview() {
    final theme = Theme.of(context);
    final rate = _parse(_rate.text);
    final value = _parse(_value.text);
    final valid =
        rate != null &&
        rate > 0 &&
        rate <= 1000 &&
        value != null &&
        value >= 0 &&
        value <= 1000;
    final points = valid ? (_previewAmount * rate).floor() : 0;
    final worth = valid ? _previewPoints * value : 0;
    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: adminFlagBackground(
          theme,
          AppColor.adminAccent,
          AppColor.adminAccentSurface,
        ),
        borderRadius: BorderRadius.circular(10),
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
              HugeIcon(
                icon: HugeIcons.strokeRoundedChartLineData01,
                size: 15,
                color: adminFlagForeground(theme, AppColor.adminAccent),
              ),
              const SizedBox(width: 6),
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
          const SizedBox(height: 7),
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
              icon: HugeIcons.strokeRoundedShoppingBag01,
              text: S.loyaltyProgramPreviewEarn(
                '${loyaltyCompactNumber(_previewAmount)} ${S.currency}',
                loyaltyCompactNumber(points),
              ),
            ),
            const SizedBox(height: 5),
            _previewRow(
              icon: HugeIcons.strokeRoundedStar,
              text: S.loyaltyProgramPreviewWorth(
                loyaltyCompactNumber(_previewPoints),
                '${loyaltyCompactNumber(worth)} ${S.currency}',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _previewRow({required IconData icon, required String text}) {
    final theme = Theme.of(context);
    return Row(
      children: [
        HugeIcon(
          icon: icon,
          size: 14,
          color: adminFlagForeground(theme, AppColor.adminAccent),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
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
    final rate = _parse(value ?? '');
    if (rate == null || rate <= 0 || rate > 1000) {
      return S.loyaltyProgramInvalidRate;
    }
    return null;
  }

  String? _validateValue(String? value) {
    final pointValue = _parse(value ?? '');
    if (pointValue == null || pointValue < 0 || pointValue > 1000) {
      return S.loyaltyProgramInvalidValue;
    }
    return null;
  }

  static double? _parse(String raw) {
    final normalized = normalizeDigits(raw.trim()).replaceAll(',', '');
    if (normalized.isEmpty || normalized == '.') return null;
    return double.tryParse(normalized);
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
