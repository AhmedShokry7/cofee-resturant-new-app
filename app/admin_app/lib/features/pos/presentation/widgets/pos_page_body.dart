import 'package:flutter/material.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/pos/domain/entities/pos_catalog.dart';
import 'package:admin_app/features/pos/presentation/manager/pos_state.dart';
import 'package:admin_app/features/pos/presentation/widgets/pos_cart_panel.dart';
import 'package:admin_app/features/pos/presentation/widgets/pos_format.dart';
import 'package:admin_app/features/pos/presentation/widgets/pos_menu_toolbar.dart';
import 'package:admin_app/features/pos/presentation/widgets/pos_product_card.dart';
import 'package:admin_app/shared/widgets/admin_empty_state.dart';
import 'package:admin_app/shared/widgets/admin_inline_error.dart';
import 'package:admin_app/shared/widgets/admin_page_frame.dart';
import 'package:admin_app/shared/widgets/admin_page_header.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/admin_toolbar.dart';

/// The point-of-sale workspace: the menu on one side and the live basket on
/// the other, or a floating basket that opens in a sheet on narrow screens.
class PosPageBody extends StatelessWidget {
  const PosPageBody({
    super.key,
    required this.state,
    required this.searchController,
    required this.onSearchChanged,
    required this.onCategoryChanged,
    required this.onClearFilters,
    required this.onRefresh,
    required this.onBranchChanged,
    required this.onAddProduct,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemoveLine,
    required this.onClearCart,
    required this.onChooseCustomer,
    required this.onClearCustomer,
    required this.onChooseTable,
    required this.onClearTable,
    required this.onRefreshTables,
    required this.onNoteChanged,
    required this.onPaymentModeChanged,
    required this.onSplitCashChanged,
    required this.onSplitCardChanged,
    required this.onCheckout,
    required this.onOpenCart,
    required this.onShiftPressed,
    this.inlineError,
    this.checkoutError,
  });

  final PosState state;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onCategoryChanged;
  final VoidCallback onClearFilters;
  final VoidCallback onRefresh;
  final ValueChanged<String> onBranchChanged;
  final ValueChanged<PosProduct> onAddProduct;
  final ValueChanged<String> onIncrement;
  final ValueChanged<String> onDecrement;
  final ValueChanged<String> onRemoveLine;
  final VoidCallback onClearCart;
  final VoidCallback onChooseCustomer;
  final VoidCallback onClearCustomer;
  final VoidCallback onChooseTable;
  final VoidCallback onClearTable;
  final VoidCallback onRefreshTables;
  final ValueChanged<String> onNoteChanged;
  final ValueChanged<PosPaymentMode> onPaymentModeChanged;
  final ValueChanged<double> onSplitCashChanged;
  final ValueChanged<double> onSplitCardChanged;
  final VoidCallback onCheckout;
  final VoidCallback onOpenCart;
  final VoidCallback onShiftPressed;
  final String? inlineError;

  /// The reason the last checkout attempt was rejected.
  final String? checkoutError;

  static const double _wideBreakpoint = 960;

  @override
  Widget build(BuildContext context) {
    return AdminPageFrame(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= _wideBreakpoint;
          final showBar = !wide && !state.isCartEmpty;
          final bottomInset = showBar ? 70.0 : 0.0;
          final cartWidth = (constraints.maxWidth * .3)
              .clamp(400.0, 480.0)
              .toDouble();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AdminPageHeader(
                title: S.pos,
                subtitle: S.posSubtitle,
                actions: [
                  _ShiftButton(state: state, onPressed: onShiftPressed),
                  _BranchPicker(state: state, onChanged: onBranchChanged),
                  AdminToolbarButton(
                    label: S.refresh,
                    icon: AppIcons.refresh,
                    busy: state.isRefreshing,
                    onPressed: onRefresh,
                  ),
                ],
              ),
              if (inlineError != null)
                AdminInlineError(message: inlineError!, onRetry: onRefresh),
              const SizedBox(height: AppSizes.px14),
              Expanded(
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _buildMenu(bottomInset: 0)),
                          const SizedBox(width: AppSizes.px16),
                          SizedBox(width: cartWidth, child: _buildCart()),
                        ],
                      )
                    : Stack(
                        children: [
                          Positioned.fill(
                            child: _buildMenu(bottomInset: bottomInset),
                          ),
                          if (showBar)
                            PositionedDirectional(
                              start: 0,
                              end: 0,
                              bottom: 0,
                              child: _CartBar(state: state, onOpen: onOpenCart),
                            ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMenu({required double bottomInset}) {
    final visible = state.visibleProducts;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PosMenuToolbar(
          searchController: searchController,
          onSearchChanged: onSearchChanged,
          categories: state.categories,
          categoryId: state.categoryId,
          onCategoryChanged: onCategoryChanged,
          totalProducts: state.products.length,
        ),
        const SizedBox(height: AppSizes.px12),
        Expanded(
          child: visible.isEmpty
              ? Padding(
                  padding: EdgeInsets.only(bottom: bottomInset),
                  child: AdminEmptyState(
                    icon: state.hasProducts
                        ? AppIcons.search01
                        : AppIcons.coffee01,
                    message: state.hasProducts
                        ? S.posNoMatches
                        : S.posNoMenuTitle,
                    hint: state.hasProducts
                        ? S.posNoMatchesHint
                        : S.posNoMenuHint,
                    action: state.hasProducts && state.hasActiveFilters
                        ? TextButton(
                            onPressed: onClearFilters,
                            child: Text(S.clearFilters),
                          )
                        : null,
                  ),
                )
              : GridView.builder(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.only(bottom: bottomInset),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 300,
                    mainAxisExtent: 264,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final product = visible[index];
                    return PosProductCard(
                      product: product,
                      currencyCode: state.currencyCode,
                      inCart: state.quantityOf(product.id),
                      remaining: state.remainingFor(product),
                      onTap: () => onAddProduct(product),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCart() {
    return PosCartPanel(
      state: state,
      onIncrement: onIncrement,
      onDecrement: onDecrement,
      onRemove: onRemoveLine,
      onClear: onClearCart,
      onChooseCustomer: onChooseCustomer,
      onClearCustomer: onClearCustomer,
      onChooseTable: onChooseTable,
      onClearTable: onClearTable,
      onRefreshTables: onRefreshTables,
      onNoteChanged: onNoteChanged,
      onPaymentModeChanged: onPaymentModeChanged,
      onSplitCashChanged: onSplitCashChanged,
      onSplitCardChanged: onSplitCardChanged,
      onCheckout: onCheckout,
      checkoutError: checkoutError,
    );
  }
}

class _BranchPicker extends StatelessWidget {
  const _BranchPicker({required this.state, required this.onChanged});

  final PosState state;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final branch = state.selectedBranch;
    if (branch == null) return const SizedBox.shrink();
    return PopupMenuButton<String>(
      tooltip: S.branches,
      position: PopupMenuPosition.under,
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final option in state.branches)
          PopupMenuItem<String>(
            value: option.id,
            child: Row(
              children: [
                SizedBox(
                  width: AppSizes.px18,
                  child: option.id == branch.id
                      ? const AppIcon(
                          AppIcons.tick01,
                          size: 15,
                          color: AppColor.adminAccent,
                        )
                      : null,
                ),
                const SizedBox(width: AppSizes.px6),
                Flexible(
                  child: Text(
                    option.nameFor(AppLocale.instance.language),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: adminBodyColor(Theme.of(context)),
                      fontSize: AppFontSizes.size12,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
      child: AdminToolbarSurface(
        label: branch.nameFor(AppLocale.instance.language),
        icon: AppIcons.store01,
        active: true,
      ),
    );
  }
}

class _ShiftButton extends StatelessWidget {
  const _ShiftButton({required this.state, required this.onPressed});

  final PosState state;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shift = state.shift;
    if (shift == null) {
      return AdminToolbarButton(
        key: const Key('pos-shift-button'),
        label: state.shiftKnown ? S.posShiftOpenAction : S.posShift,
        icon: AppIcons.cashier,
        busy: state.isLoadingShift,
        onPressed: onPressed,
      );
    }

    final accent = adminFlagForeground(theme, AppColor.adminAccent);
    final meta = <String>[
      posMoney(shift.expectedCash, shift.currencyCode),
      S.posShiftSince(posClock(shift.openedAt)),
    ].join(' • ');

    return Material(
      key: const Key('pos-shift-button'),
      color: AppColor.transparent,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 240),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: adminFlagBackground(
              theme,
              AppColor.adminAccent,
              AppColor.adminAccentSurface,
            ),
            border: Border.all(
              color: AppColor.adminAccent.withValues(alpha: .45),
            ),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(AppIcons.cashier, size: 17, color: accent),
              const SizedBox(width: AppSizes.px8),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      S.posShiftActive,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: accent,
                        fontSize: AppFontSizes.size10_5,
                        fontWeight: AppFontWeights.bold,
                        height: AppTextHeights.line1_4,
                      ),
                    ),
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: adminMutedColor(theme),
                        fontSize: AppFontSizes.size8_5,
                        fontWeight: AppFontWeights.semiBold,
                        height: AppTextHeights.line1_4,
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

class _CartBar extends StatelessWidget {
  const _CartBar({required this.state, required this.onOpen});

  final PosState state;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = state.cartSummary;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: adminCardBorderColor(theme)),
        boxShadow: adminIsDark(theme)
            ? const []
            : const [
                BoxShadow(
                  color: AppColor.inkWashSoft,
                  blurRadius: 20,
                  offset: Offset(0, 6),
                ),
              ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: adminFlagBackground(
                theme,
                AppColor.adminAccent,
                AppColor.adminAccentSurface,
              ),
              shape: BoxShape.circle,
            ),
            child: AppIcon(
              AppIcons.shoppingBag01,
              size: 18,
              color: adminFlagForeground(theme, AppColor.adminAccent),
            ),
          ),
          const SizedBox(width: AppSizes.px10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.posCartCount(summary.quantity),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: adminHeadingColor(theme),
                    fontSize: AppFontSizes.size11,
                    fontWeight: AppFontWeights.bold,
                    height: AppTextHeights.line1_4,
                  ),
                ),
                Text(
                  posMoney(summary.total, state.currencyCode),
                  style: TextStyle(
                    color: adminMutedColor(theme),
                    fontSize: AppFontSizes.size10,
                    fontWeight: AppFontWeights.semiBold,
                    height: AppTextHeights.line1_4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.px8),
          FilledButton(
            onPressed: state.isPlacingOrder ? null : onOpen,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 38),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            child: Text(
              S.posViewCart,
              style: const TextStyle(
                fontSize: AppFontSizes.size10_5,
                fontWeight: AppFontWeights.semiBold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
