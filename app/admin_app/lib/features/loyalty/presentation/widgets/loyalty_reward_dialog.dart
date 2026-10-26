import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/loyalty/domain/entities/admin_loyalty_reward_draft.dart';
import 'package:admin_app/features/loyalty/domain/entities/admin_loyalty_reward_type.dart';
import 'package:admin_app/features/loyalty/domain/entities/admin_loyalty_reward.dart';
import 'package:admin_app/features/loyalty/domain/entities/admin_loyalty_target_option.dart';
import 'package:admin_app/features/loyalty/domain/repositories/loyalty_repository.dart';
import 'package:admin_app/features/loyalty/presentation/manager/admin_loyalty_cubit.dart';
import 'package:admin_app/features/loyalty/presentation/manager/admin_loyalty_state.dart';
import 'package:admin_app/features/loyalty/presentation/widgets/loyalty_format.dart';
import 'package:admin_app/features/loyalty/presentation/widgets/loyalty_reward_target_picker.dart';
import 'package:admin_app/shared/widgets/admin_dialog_chrome.dart';
import 'package:admin_app/shared/widgets/admin_network_thumb.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/custom_text_form_field.dart';

Future<void> showLoyaltyRewardDialog({
  required BuildContext context,
  required AdminLoyaltyCubit cubit,
  AdminLoyaltyReward? reward,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => LoyaltyRewardDialog(cubit: cubit, reward: reward),
  );
}

class LoyaltyRewardDialog extends StatefulWidget {
  const LoyaltyRewardDialog({super.key, required this.cubit, this.reward});

  final AdminLoyaltyCubit cubit;
  final AdminLoyaltyReward? reward;

  @override
  State<LoyaltyRewardDialog> createState() => _LoyaltyRewardDialogState();
}

class _LoyaltyRewardDialogState extends State<LoyaltyRewardDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _points;
  late final TextEditingController _stock;
  late AdminLoyaltyRewardType _type;
  AdminLoyaltyTargetOption? _target;
  late bool _isActive;
  bool _saving = false;
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;
  String? _error;

  bool get _isEditing => widget.reward != null;

  @override
  void initState() {
    super.initState();
    final reward = widget.reward;
    _points = TextEditingController(
      text: reward == null ? '' : '${reward.pointsCost}',
    );
    _stock = TextEditingController(
      text: reward?.stockAvailable == null ? '' : '${reward!.stockAvailable}',
    );
    _type = reward?.type ?? AdminLoyaltyRewardType.product;
    _target = reward == null ? null : _optionFromReward(reward);
    _isActive = reward?.isActive ?? true;
    final state = widget.cubit.state;
    if (state.targets.isEmpty && !state.targetsLoading) {
      widget.cubit.loadTargets();
    }
  }

  @override
  void dispose() {
    _points.dispose();
    _stock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AdminLoyaltyCubit>.value(
      value: widget.cubit,
      child: BlocBuilder<AdminLoyaltyCubit, AdminLoyaltyState>(
        builder: (context, state) => _buildDialog(context, state),
      ),
    );
  }

  Widget _buildDialog(BuildContext context, AdminLoyaltyState state) {
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
        constraints: const BoxConstraints(maxWidth: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AdminDialogHeader(
              title: _isEditing
                  ? S.loyaltyRewardDialogEditTitle
                  : S.loyaltyRewardDialogAddTitle,
              onClose: _saving ? null : () => Navigator.of(context).pop(),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                child: Form(
                  key: _formKey,
                  autovalidateMode: _autovalidate,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _section(S.loyaltyRewardTargetSection),
                      _typeSelector(),
                      _targetSelector(state),
                      _section(S.loyaltyRewardPointsSection),
                      _row([
                        _field(
                          fieldKey: const Key('loyalty-reward-points'),
                          controller: _points,
                          label: S.loyaltyRewardPointsLabel,
                          hint: S.loyaltyRewardPointsHint,
                          keyboardType: TextInputType.number,
                          validator: _validatePoints,
                          helper: S.loyaltyRewardPointsHelp,
                        ),
                        _field(
                          fieldKey: const Key('loyalty-reward-stock'),
                          controller: _stock,
                          label: S.loyaltyRewardStockLabelOptional,
                          hint: S.loyaltyRewardStockHint,
                          keyboardType: TextInputType.number,
                          validator: _validateStock,
                          helper: S.loyaltyRewardStockHelp,
                        ),
                      ]),
                      _switchTile(
                        title: S.loyaltyRewardActiveTitle,
                        subtitle: S.loyaltyRewardActiveHelp,
                        value: _isActive,
                        onChanged: (value) => setState(() => _isActive = value),
                      ),
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
              saveKey: const Key('loyalty-reward-save'),
              saveLabel: S.loyaltyRewardSaveAction,
              savingLabel: S.loyaltyRewardSaving,
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

  Widget _typeSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final type in AdminLoyaltyRewardType.values)
          _TypeChip(
            key: Key('loyalty-reward-type-${type.wireValue}'),
            type: type,
            selected: _type == type,
            onTap: _saving ? null : () => _selectType(type),
          ),
      ],
    );
  }

  Widget _targetSelector(AdminLoyaltyState state) {
    final theme = Theme.of(context);
    final target = _target;
    final loading = state.targetsLoading;
    final targetsEmpty = state.targets.isEmpty;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: adminTintedSurfaceColor(theme),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: adminCardBorderColor(theme)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (target == null)
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: adminCardBorderColor(theme)),
                  ),
                  child: AppIcon(
                    _typeIcon(_type),
                    size: 18,
                    color: adminMutedColor(theme),
                  ),
                ),
                const SizedBox(width: AppSizes.px10),
                Expanded(
                  child: Text(
                    _typeHint(_type),
                    style: TextStyle(
                      color: adminMutedColor(theme),
                      fontSize: AppFontSizes.size10,
                      height: AppTextHeights.line1_5,
                    ),
                  ),
                ),
                const SizedBox(width: AppSizes.px8),
                _chooseButton(
                  key: const Key('loyalty-reward-choose-target'),
                  label: S.loyaltyRewardTargetChoose,
                  busy: loading,
                  onPressed: _chooseTarget,
                ),
              ],
            )
          else
            Row(
              children: [
                AdminNetworkThumb(
                  imageUrl: target.imageUrl,
                  size: 42,
                  icon: _typeIcon(_type),
                ),
                const SizedBox(width: AppSizes.px10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        target.nameFor(AppLocale.instance.language),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: adminBodyColor(theme),
                          fontSize: AppFontSizes.size11_5,
                          fontWeight: AppFontWeights.bold,
                          height: AppTextHeights.line1_5,
                        ),
                      ),
                      Text(
                        loyaltyTargetOptionCaption(target),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: adminMutedColor(theme),
                          fontSize: AppFontSizes.size9_5,
                          height: AppTextHeights.line1_5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSizes.px8),
                _chooseButton(
                  key: const Key('loyalty-reward-change-target'),
                  label: S.loyaltyRewardTargetChange,
                  busy: loading,
                  onPressed: _chooseTarget,
                ),
              ],
            ),
          if (target == null)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 52, top: 7),
              child: Text(
                S.loyaltyRewardTargetMissing,
                style: TextStyle(
                  color: adminMutedColor(theme),
                  fontSize: AppFontSizes.size9,
                  height: AppTextHeights.line1_5,
                ),
              ),
            ),
          if (state.targetsError != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Row(
                children: [
                  const AppIcon(
                    AppIcons.alert,
                    size: 14,
                    color: AppColor.errorColor,
                  ),
                  const SizedBox(width: AppSizes.px6),
                  Expanded(
                    child: Text(
                      S.loyaltyProductsLoadFailed,
                      style: const TextStyle(
                        color: AppColor.errorColor,
                        fontSize: AppFontSizes.size9,
                        height: AppTextHeights.line1_5,
                      ),
                    ),
                  ),
                  if (targetsEmpty)
                    TextButton(
                      onPressed: _saving ? null : widget.cubit.loadTargets,
                      child: Text(S.retry),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _chooseButton({
    required Key key,
    required String label,
    required bool busy,
    required VoidCallback? onPressed,
  }) {
    return TextButton.icon(
      key: key,
      onPressed: busy ? null : onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 32),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        visualDensity: VisualDensity.compact,
      ),
      icon: busy
          ? const SizedBox(
              width: AppSizes.px14,
              height: AppSizes.px14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(AppIcons.edit01, size: 15),
      label: Text(label),
    );
  }

  Widget _row(List<Widget> children) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 420) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < children.length; index++) ...[
                if (index > 0) const SizedBox(height: AppSpacing.sm),
                children[index],
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < children.length; index++) ...[
              if (index > 0) const SizedBox(width: AppSpacing.md),
              Expanded(child: children[index]),
            ],
          ],
        );
      },
    );
  }

  Widget _field({
    required Key fieldKey,
    required TextEditingController controller,
    required String label,
    required String hint,
    required TextInputType keyboardType,
    required String? Function(String?) validator,
    required String helper,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CustomTextFormField(
          key: fieldKey,
          controller: controller,
          label: label,
          hint: hint,
          keyboardType: keyboardType,
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

  Widget _switchTile({
    required String title,
    required String subtitle,
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
      subtitle: Text(
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

  void _selectType(AdminLoyaltyRewardType type) {
    if (_type == type) return;
    setState(() {
      _type = type;
      _target = null;
      _error = null;
    });
  }

  Future<void> _chooseTarget() async {
    if (_saving) return;
    var targets = widget.cubit.state.targets;
    if (targets.isEmpty) {
      await widget.cubit.loadTargets();
      if (!mounted) return;
      targets = widget.cubit.state.targets;
      if (targets.isEmpty) return;
    }
    final selected = await showLoyaltyRewardTargetPicker(
      context: context,
      targets: targets,
      type: _type,
      selectedId: _target?.type == _type ? _target?.id : null,
      currentRewardId: widget.reward?.id,
    );
    if (selected == null || !mounted) return;
    setState(() {
      _target = selected;
      _error = null;
    });
  }

  String? _validatePoints(String? value) {
    final points = int.tryParse(normalizeDigits((value ?? '').trim()));
    if (points == null || points <= 0) return S.loyaltyRewardInvalidPoints;
    if (points > 1000000) return S.loyaltyRewardInvalidPoints;
    return null;
  }

  String? _validateStock(String? value) {
    final text = normalizeDigits((value ?? '').trim());
    if (text.isEmpty) return null;
    final stock = int.tryParse(text);
    if (stock == null || stock < 0 || stock > 1000000) {
      return S.loyaltyRewardInvalidStock;
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
    final target = _target;
    if (target == null) {
      setState(() => _error = S.loyaltyRewardTargetMissing);
      return;
    }
    final stockText = normalizeDigits(_stock.text.trim());
    final draft = AdminLoyaltyRewardDraft(
      id: widget.reward?.id,
      type: _type,
      targetId: target.id,
      pointsCost: int.parse(normalizeDigits(_points.text.trim())),
      stockAvailable: stockText.isEmpty ? null : int.parse(stockText),
      isActive: _isActive,
    );

    setState(() => _saving = true);
    final outcome = await widget.cubit.saveReward(draft);
    if (!mounted) return;
    setState(() => _saving = false);

    switch (outcome) {
      case LoyaltyRewardSaveOutcome.saved:
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).pop();
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(S.loyaltyRewardSaved)));
        break;
      case LoyaltyRewardSaveOutcome.duplicateTarget:
        setState(() => _error = S.loyaltyRewardDuplicateTarget);
        break;
      case LoyaltyRewardSaveOutcome.invalidTarget:
        setState(() => _error = S.loyaltyRewardInvalidTarget);
        break;
      case LoyaltyRewardSaveOutcome.invalidType:
        setState(() => _error = S.loyaltyRewardInvalidTarget);
        break;
      case LoyaltyRewardSaveOutcome.targetUnavailable:
        setState(() => _error = S.loyaltyRewardTargetUnavailableCannotActivate);
        break;
      case LoyaltyRewardSaveOutcome.invalidPoints:
        setState(() => _error = S.loyaltyRewardInvalidPoints);
        break;
      case LoyaltyRewardSaveOutcome.invalidStock:
        setState(() => _error = S.loyaltyRewardInvalidStock);
        break;
      case LoyaltyRewardSaveOutcome.notFound:
        setState(() => _error = S.loyaltyRewardNotFound);
        break;
      case LoyaltyRewardSaveOutcome.failed:
        setState(() => _error = S.loyaltyRewardSaveFailed);
        break;
    }
  }

  static String _typeHint(AdminLoyaltyRewardType type) => switch (type) {
    AdminLoyaltyRewardType.product => S.loyaltyRewardProductHint,
    AdminLoyaltyRewardType.bundle => S.loyaltyRewardBundleHint,
    AdminLoyaltyRewardType.plan => S.loyaltyRewardPlanHint,
  };

  static IconData _typeIcon(AdminLoyaltyRewardType type) => switch (type) {
    AdminLoyaltyRewardType.product => AppIcons.package,
    AdminLoyaltyRewardType.bundle => AppIcons.shoppingBag01,
    AdminLoyaltyRewardType.plan => AppIcons.repeat,
  };

  static AdminLoyaltyTargetOption _optionFromReward(AdminLoyaltyReward reward) {
    return AdminLoyaltyTargetOption(
      type: reward.type,
      id: reward.targetId,
      nameAr: reward.targetNameAr,
      nameEn: reward.targetNameEn,
      code: reward.targetCode,
      imageUrl: reward.targetImageUrl,
      price: reward.targetPrice,
      isActive: reward.targetIsActive && reward.targetIsAvailable,
      categoryNameAr: reward.categoryNameAr,
      categoryNameEn: reward.categoryNameEn,
      bundleItemsCount: reward.bundleItemsCount,
      planDurationDays: reward.planDurationDays,
      planCupsPerCycle: reward.planCupsPerCycle,
      rewardId: reward.id,
      rewardPointsCost: reward.pointsCost,
      rewardIsActive: reward.isActive,
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    super.key,
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final AdminLoyaltyRewardType type;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(AppRadius.md);
    final foreground = selected ? AppColor.adminAccent : adminBodyColor(theme);
    return Material(
      color: selected
          ? AppColor.adminAccent.withValues(alpha: .08)
          : theme.colorScheme.surface,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: selected
                  ? AppColor.adminAccent.withValues(alpha: .45)
                  : adminCardBorderColor(theme),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(
                _LoyaltyRewardDialogState._typeIcon(type),
                size: 15,
                color: foreground,
              ),
              const SizedBox(width: AppSizes.px6),
              Text(
                loyaltyRewardTypeLabel(type),
                style: TextStyle(
                  color: foreground,
                  fontSize: AppFontSizes.size10_5,
                  fontWeight: AppFontWeights.bold,
                  height: AppTextHeights.line1_4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
