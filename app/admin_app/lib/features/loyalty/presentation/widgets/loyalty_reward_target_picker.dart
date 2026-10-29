import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/loyalty/domain/entities/admin_loyalty_reward_type.dart';
import 'package:admin_app/features/loyalty/domain/entities/admin_loyalty_target_option.dart';
import 'package:admin_app/features/loyalty/presentation/widgets/loyalty_format.dart';
import 'package:admin_app/features/loyalty/presentation/widgets/loyalty_money_bits.dart';
import 'package:admin_app/shared/widgets/admin_network_thumb.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/custom_text_form_field.dart';

/// Opens the catalogue list for one reward target type.
///
/// Targets already used by another reward stay visible but cannot be picked,
/// so the admin understands why an expected entry is missing instead of
/// facing an empty-looking catalogue.
Future<AdminLoyaltyTargetOption?> showLoyaltyRewardTargetPicker({
  required BuildContext context,
  required List<AdminLoyaltyTargetOption> targets,
  required AdminLoyaltyRewardType type,
  String? selectedId,
  String? currentRewardId,
}) {
  return showDialog<AdminLoyaltyTargetOption>(
    context: context,
    builder: (_) => LoyaltyRewardTargetPicker(
      targets: targets,
      type: type,
      selectedId: selectedId,
      currentRewardId: currentRewardId,
    ),
  );
}

class LoyaltyRewardTargetPicker extends StatefulWidget {
  const LoyaltyRewardTargetPicker({
    super.key,
    required this.targets,
    required this.type,
    this.selectedId,
    this.currentRewardId,
  });

  final List<AdminLoyaltyTargetOption> targets;
  final AdminLoyaltyRewardType type;
  final String? selectedId;

  /// The reward being edited, whose own target must remain selectable.
  final String? currentRewardId;

  @override
  State<LoyaltyRewardTargetPicker> createState() =>
      _LoyaltyRewardTargetPickerState();
}

class _LoyaltyRewardTargetPickerState extends State<LoyaltyRewardTargetPicker> {
  final _searchController = TextEditingController();
  late String? _selectedId;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.selectedId;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _isDisabled(AdminLoyaltyTargetOption target) =>
      (target.hasReward && target.rewardId != widget.currentRewardId) ||
      !target.isActive;

  List<AdminLoyaltyTargetOption> get _filtered {
    final term = _searchController.text.trim().toLowerCase();
    return widget.targets
        .where((target) {
          if (target.type != widget.type) return false;
          if (term.isEmpty) return true;
          final text = <String>[
            target.nameAr ?? '',
            target.nameEn ?? '',
            target.code ?? '',
            target.categoryNameAr ?? '',
            target.categoryNameEn ?? '',
          ].join(' ').toLowerCase();
          return text.contains(term);
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = adminIsDark(theme);
    final screen = MediaQuery.sizeOf(context);
    final height = math.min(screen.height * .76, 640.0);
    final filtered = _filtered;
    final typeTargets = widget.targets
        .where((target) => target.type == widget.type)
        .toList(growable: false);

    return Dialog(
      clipBehavior: Clip.antiAlias,
      insetPadding: EdgeInsets.symmetric(
        horizontal: screen.width < AppBreakpoints.dialogPadding
            ? AppSpacing.md
            : AppSpacing.xxxl,
        vertical: AppSpacing.lg,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SizedBox(
          height: height,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border(
                    bottom: BorderSide(color: adminRowBorderColor(theme)),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            S.loyaltyRewardTargetPickerTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: adminHeadingColor(theme),
                              fontSize: AppFontSizes.size16,
                              fontWeight: AppFontWeights.bold,
                              height: AppTextHeights.line1_5,
                            ),
                          ),
                          Text(
                            _typeHint(widget.type),
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
                    IconButton(
                      tooltip: S.close,
                      onPressed: () => Navigator.of(context).pop(),
                      style: IconButton.styleFrom(
                        fixedSize: const Size(36, 36),
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: AppIcon(
                        AppIcons.cancel01,
                        size: 18,
                        color: adminMutedColor(theme),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  0,
                ),
                child: CustomTextFormField(
                  key: const Key('loyalty-reward-target-search'),
                  controller: _searchController,
                  hint: S.loyaltyRewardTargetSearchHint,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.search,
                  prefixIcon: const Icon(AppIcons.search01),
                  bottomPadding: AppSpacing.md,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? _EmptyList(hasTargets: typeTargets.isNotEmpty)
                    : ListView.separated(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          AppSpacing.md,
                          0,
                          AppSpacing.md,
                          AppSpacing.md,
                        ),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSizes.px4),
                        itemBuilder: (context, index) {
                          final target = filtered[index];
                          final disabled = _isDisabled(target);
                          return _TargetTile(
                            key: Key('loyalty-reward-target-${target.id}'),
                            target: target,
                            selected: _selectedId == target.id,
                            disabled: disabled,
                            alreadyRewarded:
                                target.hasReward &&
                                target.rewardId != widget.currentRewardId,
                            onTap: disabled
                                ? null
                                : () => setState(() => _selectedId = target.id),
                          );
                        },
                      ),
              ),
              Container(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border(
                    top: BorderSide(
                      color: dark
                          ? AppColor.darkBorder
                          : AppColor.adminRowBorder,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(S.cancel),
                    ),
                    const SizedBox(width: AppSizes.px8),
                    FilledButton(
                      key: const Key('loyalty-reward-target-choose'),
                      onPressed: _selectedId == null
                          ? null
                          : () => Navigator.of(context).pop(_selectedTarget()),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 38),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                      child: Text(
                        S.loyaltyRewardTargetChoose,
                        style: const TextStyle(
                          fontSize: AppFontSizes.size11,
                          fontWeight: AppFontWeights.semiBold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _typeHint(AdminLoyaltyRewardType type) => switch (type) {
    AdminLoyaltyRewardType.product => S.loyaltyRewardProductHint,
    AdminLoyaltyRewardType.bundle => S.loyaltyRewardBundleHint,
    AdminLoyaltyRewardType.plan => S.loyaltyRewardPlanHint,
  };

  AdminLoyaltyTargetOption? _selectedTarget() {
    for (final target in widget.targets) {
      if (target.type == widget.type && target.id == _selectedId) {
        return target;
      }
    }
    return null;
  }
}

class _TargetTile extends StatelessWidget {
  const _TargetTile({
    super.key,
    required this.target,
    required this.selected,
    required this.disabled,
    required this.alreadyRewarded,
    required this.onTap,
  });

  final AdminLoyaltyTargetOption target;
  final bool selected;
  final bool disabled;
  final bool alreadyRewarded;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(AppRadius.md);
    return Opacity(
      opacity: disabled ? .55 : 1,
      child: Material(
        color: AppColor.transparent,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? adminTintedSurfaceColor(theme)
                  : AppColor.transparent,
              borderRadius: radius,
              border: Border.all(
                color: selected
                    ? AppColor.adminAccent.withValues(alpha: .45)
                    : AppColor.transparent,
              ),
            ),
            child: Row(
              children: [
                AdminNetworkThumb(
                  imageUrl: target.imageUrl,
                  size: 38,
                  icon: _typeIcon(target.type),
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
                          fontWeight: AppFontWeights.semiBold,
                          height: AppTextHeights.line1_5,
                        ),
                      ),
                      LoyaltyMoneyText(
                        sentence: loyaltyTargetOptionCaption(target),
                        style: TextStyle(
                          color: adminMutedColor(theme),
                          fontSize: AppFontSizes.size9_5,
                          height: AppTextHeights.line1_5,
                        ),
                      ),
                      if (alreadyRewarded)
                        Text(
                          localizeDigits(
                            S.loyaltyRewardTargetAlreadyRewardPoints(
                              target.rewardPointsCost ?? 0,
                            ),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColor.adminWarning,
                            fontSize: AppFontSizes.size9,
                            fontWeight: AppFontWeights.semiBold,
                            height: AppTextHeights.line1_5,
                          ),
                        )
                      else if (!target.isActive)
                        Text(
                          S.loyaltyRewardUnavailable,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColor.adminWarning,
                            fontSize: AppFontSizes.size9,
                            fontWeight: AppFontWeights.semiBold,
                            height: AppTextHeights.line1_5,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSizes.px8),
                AppIcon(
                  selected ? AppIcons.checkmarkCircle02 : AppIcons.circle,
                  size: 18,
                  color: selected
                      ? AppColor.adminAccent
                      : adminMutedColor(theme),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static IconData _typeIcon(AdminLoyaltyRewardType type) => switch (type) {
    AdminLoyaltyRewardType.product => AppIcons.package,
    AdminLoyaltyRewardType.bundle => AppIcons.shoppingBag01,
    AdminLoyaltyRewardType.plan => AppIcons.repeat,
  };
}

class _EmptyList extends StatelessWidget {
  const _EmptyList({required this.hasTargets});

  final bool hasTargets;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = adminMutedColor(theme);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(AppIcons.search01, size: 26, color: muted),
            const SizedBox(height: AppSizes.px8),
            Text(
              hasTargets ? S.loyaltyNoTargetsFound : S.loyaltyProductsEmpty,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: muted,
                fontSize: AppFontSizes.size11,
                height: AppTextHeights.line1_5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
