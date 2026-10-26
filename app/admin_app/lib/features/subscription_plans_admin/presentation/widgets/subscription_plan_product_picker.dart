import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/formatters.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/subscription_plans_admin/domain/entities/admin_subscription_plan_product.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/custom_text_form_field.dart';

/// Opens the multi-select list of products a plan can be limited to.
Future<Set<String>?> showSubscriptionPlanProductPicker({
  required BuildContext context,
  required List<AdminSubscriptionPlanProduct> products,
  required Set<String> initialSelection,
}) {
  return showDialog<Set<String>>(
    context: context,
    builder: (_) => SubscriptionPlanProductPicker(
      products: products,
      initialSelection: initialSelection,
    ),
  );
}

class SubscriptionPlanProductPicker extends StatefulWidget {
  const SubscriptionPlanProductPicker({
    super.key,
    required this.products,
    required this.initialSelection,
  });

  final List<AdminSubscriptionPlanProduct> products;
  final Set<String> initialSelection;

  @override
  State<SubscriptionPlanProductPicker> createState() =>
      _SubscriptionPlanProductPickerState();
}

class _SubscriptionPlanProductPickerState
    extends State<SubscriptionPlanProductPicker> {
  final _searchController = TextEditingController();
  late final Set<String> _selection;

  @override
  void initState() {
    super.initState();
    _selection = {...widget.initialSelection};
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AdminSubscriptionPlanProduct> get _filtered {
    final term = _searchController.text.trim().toLowerCase();
    if (term.isEmpty) return widget.products;
    return widget.products
        .where((product) {
          return _matches(product.nameAr, term) ||
              _matches(product.nameEn, term) ||
              _matches(product.sku, term) ||
              _matches(product.categoryNameAr, term) ||
              _matches(product.categoryNameEn, term);
        })
        .toList(growable: false);
  }

  static bool _matches(String? value, String term) =>
      (value ?? '').toLowerCase().contains(term);

  void _toggle(AdminSubscriptionPlanProduct product) {
    setState(() {
      if (!_selection.remove(product.id)) _selection.add(product.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = adminIsDark(theme);
    final screen = MediaQuery.sizeOf(context);
    final height = math.min(screen.height * .74, 620.0);
    final filtered = _filtered;

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
                            S.subscriptionPlanProductPickerTitle,
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
                            localizeDigits(
                              S.subscriptionPlanProductPickerSelected(
                                _selection.length,
                              ),
                            ),
                            style: TextStyle(
                              color: adminMutedColor(theme),
                              fontSize: AppFontSizes.size10,
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
                        color: dark
                            ? AppColor.darkTextSecondary
                            : AppColor.adminMuted,
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
                  key: const Key('plan-product-search'),
                  controller: _searchController,
                  hint: S.searchProductsHint,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.search,
                  prefixIcon: const Icon(AppIcons.search01),
                  bottomPadding: AppSpacing.md,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? _EmptyList(hasProducts: widget.products.isNotEmpty)
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
                          final product = filtered[index];
                          return _ProductTile(
                            key: Key('plan-product-option-${product.id}'),
                            product: product,
                            selected: _selection.contains(product.id),
                            onTap: () => _toggle(product),
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
                      key: const Key('plan-product-picker-apply'),
                      onPressed: () =>
                          Navigator.of(context).pop({..._selection}),
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
                        S.subscriptionPlanProductPickerApply,
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
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    super.key,
    required this.product,
    required this.selected,
    required this.onTap,
  });

  final AdminSubscriptionPlanProduct product;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(AppRadius.md);
    final category = product.categoryNameFor(AppLocale.instance.language);
    final price = localizeDigits(formatAmount(product.basePrice));

    return Material(
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
              _Thumb(imageUrl: product.imageUrl),
              const SizedBox(width: AppSizes.px10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.nameFor(AppLocale.instance.language),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: adminBodyColor(theme),
                        fontSize: AppFontSizes.size11_5,
                        fontWeight: AppFontWeights.semiBold,
                        height: AppTextHeights.line1_5,
                      ),
                    ),
                    Text(
                      [
                        if (category.isNotEmpty) category,
                        '$price ${S.currency}',
                      ].join('  •  '),
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
              if (!product.isActive) ...[
                const SizedBox(width: AppSizes.px8),
                Text(
                  S.subscriptionPlanProductInactive,
                  style: const TextStyle(
                    color: AppColor.adminWarning,
                    fontSize: AppFontSizes.size9,
                    fontWeight: AppFontWeights.semiBold,
                    height: AppTextHeights.line1_5,
                  ),
                ),
              ],
              const SizedBox(width: AppSizes.px4),
              Checkbox(
                value: selected,
                onChanged: (_) => onTap(),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final url = imageUrl?.trim();
    final fallback = ColoredBox(
      color: adminTintedSurfaceColor(theme),
      child: AppIcon(AppIcons.cube, size: 16, color: adminMutedColor(theme)),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: SizedBox(
        width: AppSizes.px38,
        height: AppSizes.px38,
        child: url == null || url.isEmpty
            ? fallback
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.fill,
                errorWidget: (_, _, _) => fallback,
              ),
      ),
    );
  }
}

class _EmptyList extends StatelessWidget {
  const _EmptyList({required this.hasProducts});

  final bool hasProducts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(AppIcons.search01, size: 26, color: adminMutedColor(theme)),
            const SizedBox(height: AppSizes.px8),
            Text(
              hasProducts
                  ? S.noProductsFound
                  : S.subscriptionPlanProductsEmptyCatalog,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: adminMutedColor(theme),
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
