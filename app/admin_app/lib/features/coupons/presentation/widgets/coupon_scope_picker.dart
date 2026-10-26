import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/coupons/data/models/admin_coupon.dart';
import 'package:admin_app/features/coupons/data/models/admin_coupon_targets.dart';
import 'package:admin_app/shared/widgets/admin_dialog_chrome.dart';
import 'package:admin_app/shared/widgets/admin_network_thumb.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/custom_text_form_field.dart';

/// Lets the admin pick the categories or products a coupon applies to.
Future<Set<String>?> showCouponScopePicker({
  required BuildContext context,
  required AdminCouponTargets targets,
  required AdminCouponScope scope,
  required Set<String> selectedIds,
}) {
  assert(scope != AdminCouponScope.all);
  return showDialog<Set<String>>(
    context: context,
    builder: (_) => CouponScopePicker(
      targets: targets,
      scope: scope,
      selectedIds: selectedIds,
    ),
  );
}

class CouponScopePicker extends StatefulWidget {
  const CouponScopePicker({
    super.key,
    required this.targets,
    required this.scope,
    required this.selectedIds,
  });

  final AdminCouponTargets targets;
  final AdminCouponScope scope;
  final Set<String> selectedIds;

  @override
  State<CouponScopePicker> createState() => _CouponScopePickerState();
}

class _CouponScopePickerState extends State<CouponScopePicker> {
  final _searchController = TextEditingController();
  late final Set<String> _selected = {...widget.selectedIds};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _isCategory => widget.scope == AdminCouponScope.category;

  List<_PickerItem> get _items {
    final language = AppLocale.instance.language;
    if (_isCategory) {
      return widget.targets.categories
          .map(
            (category) => _PickerItem(
              id: category.id,
              name: category.nameFor(language),
              caption: S.couponsScopeProducts(category.productsCount),
              imageUrl: category.imageUrl,
              isInactive: !category.isActive,
              searchText: category.searchText,
            ),
          )
          .toList(growable: false);
    }
    return widget.targets.products
        .map(
          (product) => _PickerItem(
            id: product.id,
            name: product.nameFor(language),
            caption: [
              if (product.categoryNameFor(language) != null)
                product.categoryNameFor(language)!,
              if (product.sku != null && product.sku!.trim().isNotEmpty)
                product.sku!.trim(),
            ].join('  •  '),
            imageUrl: product.imageUrl,
            isInactive: !product.isActive,
            isArchived: product.isArchived,
            searchText: product.searchText,
          ),
        )
        .toList(growable: false);
  }

  List<_PickerItem> get _filtered {
    final term = _searchController.text.trim().toLowerCase();
    final items = _items;
    if (term.isEmpty) return items;
    return items
        .where((item) => item.searchText.contains(term))
        .toList(growable: false);
  }

  bool _isDisabled(_PickerItem item) =>
      item.isArchived && !_selected.contains(item.id);

  void _toggle(_PickerItem item) {
    if (_isDisabled(item)) return;
    setState(() {
      if (!_selected.remove(item.id)) _selected.add(item.id);
    });
  }

  void _selectAllVisible() {
    setState(() {
      for (final item in _filtered) {
        if (!_isDisabled(item)) _selected.add(item.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screen = MediaQuery.sizeOf(context);
    final height = math.min(screen.height * .76, 640.0);
    final filtered = _filtered;
    final selectable = filtered.where((item) => !_isDisabled(item));
    final allSelected =
        selectable.isNotEmpty &&
        selectable.every((item) => _selected.contains(item.id));

    return Dialog(
      clipBehavior: Clip.antiAlias,
      insetPadding: EdgeInsets.symmetric(
        horizontal: screen.width < 600 ? AppDimensions.md : AppDimensions.xxl,
        vertical: AppDimensions.lg,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SizedBox(
          height: height,
          child: Column(
            children: [
              AdminDialogHeader(
                title: _isCategory
                    ? S.couponsPickerCategoriesTitle
                    : S.couponsPickerProductsTitle,
                onClose: () => Navigator.of(context).pop(),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppDimensions.lg,
                  AppDimensions.md,
                  AppDimensions.lg,
                  0,
                ),
                child: CustomTextFormField(
                  key: const Key('coupon-scope-search'),
                  controller: _searchController,
                  hint: _isCategory
                      ? S.couponsPickerSearchCategories
                      : S.couponsPickerSearchProducts,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.search,
                  prefixIcon: const Icon(HugeIcons.strokeRoundedSearch01),
                  bottomPadding: AppDimensions.sm,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppDimensions.lg,
                  0,
                  AppDimensions.sm,
                  0,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        localizeDigits(
                          S.couponsSelectedCount(_selected.length),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: adminMutedColor(theme),
                          fontSize: AppFontSizes.size9_5,
                          height: AppTextHeights.line1_5,
                        ),
                      ),
                    ),
                    TextButton(
                      key: const Key('coupon-scope-select-all'),
                      onPressed: allSelected || selectable.isEmpty
                          ? null
                          : _selectAllVisible,
                      child: Text(S.couponsPickerSelectAll),
                    ),
                    TextButton(
                      key: const Key('coupon-scope-clear'),
                      onPressed: _selected.isEmpty
                          ? null
                          : () => setState(_selected.clear),
                      child: Text(S.couponsPickerClear),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? _EmptyList(hasItems: _items.isNotEmpty)
                    : ListView.separated(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          AppDimensions.md,
                          0,
                          AppDimensions.md,
                          AppDimensions.md,
                        ),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 4),
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          final disabled = _isDisabled(item);
                          return _TargetTile(
                            key: Key('coupon-scope-option-${item.id}'),
                            item: item,
                            selected: _selected.contains(item.id),
                            disabled: disabled,
                            onTap: disabled ? null : () => _toggle(item),
                          );
                        },
                      ),
              ),
              Container(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppDimensions.lg,
                  AppDimensions.sm,
                  AppDimensions.lg,
                  AppDimensions.sm,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border(
                    top: BorderSide(
                      color: adminIsDark(theme)
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
                    const SizedBox(width: 8),
                    FilledButton(
                      key: const Key('coupon-scope-apply'),
                      onPressed: _selected.isEmpty
                          ? null
                          : () => Navigator.of(context).pop({..._selected}),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 38),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9),
                        ),
                      ),
                      child: Text(
                        S.couponsPickerApply,
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

class _PickerItem {
  const _PickerItem({
    required this.id,
    required this.name,
    required this.caption,
    required this.imageUrl,
    required this.isInactive,
    required this.searchText,
    this.isArchived = false,
  });

  final String id;
  final String name;
  final String caption;
  final String? imageUrl;
  final bool isInactive;
  final bool isArchived;
  final String searchText;
}

class _TargetTile extends StatelessWidget {
  const _TargetTile({
    super.key,
    required this.item,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });

  final _PickerItem item;
  final bool selected;
  final bool disabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(10);
    return Opacity(
      opacity: disabled ? .55 : 1,
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: selected
                  ? adminTintedSurfaceColor(theme)
                  : Colors.transparent,
              borderRadius: radius,
              border: Border.all(
                color: selected
                    ? AppColor.adminAccent.withValues(alpha: .45)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                AdminNetworkThumb(
                  imageUrl: item.imageUrl,
                  size: 38,
                  icon: item.isArchived
                      ? HugeIcons.strokeRoundedArchive
                      : HugeIcons.strokeRoundedPackage,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: adminBodyColor(theme),
                          fontSize: AppFontSizes.size11_5,
                          fontWeight: AppFontWeights.semiBold,
                          height: AppTextHeights.line1_5,
                        ),
                      ),
                      if (item.caption.isNotEmpty)
                        Text(
                          localizeDigits(item.caption),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: adminMutedColor(theme),
                            fontSize: AppFontSizes.size9_5,
                            height: AppTextHeights.line1_5,
                          ),
                        ),
                      if (item.isArchived || item.isInactive)
                        Text(
                          item.isArchived
                              ? S.couponsArchived
                              : S.couponsInactive,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: item.isArchived
                                ? AppColor.adminWarning
                                : adminMutedColor(theme),
                            fontSize: AppFontSizes.size9,
                            fontWeight: AppFontWeights.semiBold,
                            height: AppTextHeights.line1_5,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Checkbox(
                  value: selected,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: disabled
                      ? null
                      : (_) {
                          onTap?.call();
                        },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyList extends StatelessWidget {
  const _EmptyList({required this.hasItems});

  final bool hasItems;

  @override
  Widget build(BuildContext context) {
    final muted = adminMutedColor(Theme.of(context));
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedSearch01,
              size: 26,
              color: muted,
            ),
            const SizedBox(height: 8),
            Text(
              hasItems ? S.couponsPickerNoMatches : S.couponsPickerEmpty,
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
