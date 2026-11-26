import 'package:new_coffee/shared/widgets/custom_btn.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/theme/tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/cart/presentation/manager/cart/cart_cubit.dart';
import 'package:new_coffee/features/customer_bundles/data/model/customer_bundle.dart';
import 'package:new_coffee/features/customer_bundles/data/repositories/customer_bundle_repository.dart';
import 'package:new_coffee/features/menu/data/repositories/batch_product_repository.dart';
import 'package:new_coffee/features/menu/data/repositories/product_repository.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/product_image.dart';
import 'package:new_coffee/features/orders/data/model/order_group.dart';
import 'package:new_coffee/features/orders/data/model/order_item_model.dart';
import 'package:new_coffee/features/orders/data/model/order_status.dart';
import 'package:new_coffee/features/orders/presentation/manager/orders/orders_cubit.dart';
import 'package:new_coffee/features/orders/presentation/views/leave_review_page.dart';
import 'package:new_coffee/features/orders/presentation/views/order_details_page.dart';
import 'package:new_coffee/features/orders/presentation/views/track_order_page.dart';
import 'package:new_coffee/features/orders/presentation/views/widgets/order_status_badge.dart';
import 'package:new_coffee/shared/utils/formatters.dart';
import 'package:new_coffee/shared/widgets/app_icon.dart';
import 'package:new_coffee/shared/widgets/price_label.dart';

/// One order in the history list: number, date, status, item count and the
/// header's real grand total, all frozen snapshots from the invoice.
class OrderCard extends StatelessWidget {
  const OrderCard({super.key, required this.order});

  final OrderGroup order;

  Future<void> _saveAsList(BuildContext context) async {
    final name = TextEditingController(
      text: S.orderNumber(order.displayNumber),
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(S.saveOrderAsList),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(S.saveOrderAsListHint),
            SizedBox(height: AppSpacing.sm),
            TextField(
              controller: name,
              maxLength: 80,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: S.bundleName),
            ),
          ],
        ),
        actions: [
          CustomTextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(S.cancel),
          ),
          CustomFilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(S.save),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      name.dispose();
      return;
    }
    final bundleName = name.text.trim();
    name.dispose();
    if (bundleName.isEmpty) return;
    final quantities = <String, int>{};
    final sourceLines = <String, OrderItemModel>{};
    for (final line in order.lines) {
      final id = line.product.id;
      if (id.startsWith('removed-product-')) continue;
      sourceLines.putIfAbsent(id, () => line);
      quantities.update(
        id,
        (value) => (value + line.quantity).clamp(1, 99).toInt(),
        ifAbsent: () => line.quantity.clamp(1, 99).toInt(),
      );
    }
    final items = [
      for (final entry in sourceLines.entries)
        CustomerBundleItem(
          id: '',
          bundleId: '',
          productId: entry.key,
          quantity: quantities[entry.key]!,
          productNameAr: entry.value.product.nameAr,
          productNameEn: entry.value.product.nameEn,
          note: entry.value.note.isEmpty ? null : entry.value.note,
        ),
    ];
    if (items.isEmpty) return;
    try {
      await CustomerBundleRepository().createBundle(
        name: bundleName,
        description: S.orderNumber(order.displayNumber),
        items: items,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(S.bundleSaved)));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(S.couldNotSaveBundle)));
    }
  }

  Future<void> _reorder(BuildContext context) async {
    final cart = context.read<CartCubit>();
    if (cart.state.isLoading) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(S.reorderCartLoading)));
      return;
    }
    final validLines = order.lines
        .where((line) => !line.product.id.startsWith('removed-product-'))
        .toList(growable: false);
    final List<ProductModel> products;
    final Set<String> branchUnavailable;
    final Map<String, List<OptionGroup>> optionGroups;
    final productRepository = context.read<ProductRepository>();
    try {
      products = await getProductsByIds(
        productRepository,
        validLines.map((line) => line.product.id).toList(growable: false),
        branchId: cart.branchId,
      );
      branchUnavailable =
          cart.branchId != null &&
              productRepository is ProductAvailabilityRepository
          ? await (productRepository as ProductAvailabilityRepository)
                .unavailableProductIds(
                  validLines
                      .map((line) => line.product.id)
                      .toList(growable: false),
                  branchId: cart.branchId!,
                )
          : const <String>{};
      optionGroups = await productRepository.getOptionsByProduct(
        validLines.map((line) => line.product.id).toSet().toList(growable: false),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(S.reorderFailed)));
      return;
    }
    if (!context.mounted) return;
    final byId = {for (final product in products) product.id: product};
    final List<(OrderItemModel, ProductModel, List<String>, double)> available = [];
    final invalidOptions = <OrderItemModel>[];
    for (final line in validLines) {
      final product = byId[line.product.id];
      if (product == null || branchUnavailable.contains(line.product.id)) continue;
      final groups = optionGroups[line.product.id] ?? const <OptionGroup>[];
      final saved = line.optionValueIds.toSet();
      final validIds = <String>[];
      var invalidRequiredGroup = false;
      for (final group in groups) {
        final groupIds = group.values.map((value) => value.id).toSet();
        final selected = saved.where(groupIds.contains).toList(growable: false);
        validIds.addAll(selected);
        if (group.isRequired && selected.length < group.minSelect) {
          invalidRequiredGroup = true;
        }
        if (group.isSingleSelect && selected.length > 1) {
          invalidRequiredGroup = true;
        }
      }
      if (invalidRequiredGroup) {
        invalidOptions.add(line);
        continue;
      }
      final resolved = await productRepository.resolvePrice(
        product.id,
        branchId: cart.branchId,
        optionValueIds: validIds,
      ).catchError((_) => null);
      if (resolved == null || !resolved.isAvailable) {
        invalidOptions.add(line);
        continue;
      }
      available.add((line, product, validIds, resolved.unitPrice));
    }
    final unavailable = validLines
        .where(
          (line) =>
              !byId.containsKey(line.product.id) ||
              branchUnavailable.contains(line.product.id),
        )
        .toList(growable: false);
    final hasOldNotes = available.any(
      (entry) => entry.$1.note.trim().isNotEmpty,
    );
    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(S.reorderOrder),
        content: SizedBox(
          width: AppSizes.px440,
          height: AppSizes.px350,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(S.reorderReview),
              if (hasOldNotes) ...[
                SizedBox(height: AppSpacing.sm),
                Text(S.reorderOptionsNote),
              ],
              if (invalidOptions.isNotEmpty) ...[
                SizedBox(height: AppSpacing.sm),
                Text(S.reorderOptionsUnavailable),
              ],
              SizedBox(height: AppSpacing.sm),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final entry in available)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(entry.$2.name),
                        subtitle: Text(S.quantityLabel(entry.$1.quantity)),
                      trailing: Text(Formatters.price(entry.$4)),
                      ),
                    for (final line in unavailable)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(line.product.name),
                        subtitle: Text(S.reorderUnavailable),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          CustomTextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(S.cancel),
          ),
          CustomFilledButton(
            onPressed: available.isEmpty
                ? null
                : () => Navigator.pop(dialogContext, true),
            child: Text(S.reorderAddAvailable),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    for (final entry in available) {
      cart.add(
        entry.$2,
        quantity: entry.$1.quantity,
        note: entry.$1.note,
        optionValueIds: entry.$3,
        unitPrice: entry.$4,
      );
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(S.reorderAdded(available.length, unavailable.length + invalidOptions.length)),
      ),
    );
  }

  /// Opens one of the order's pages and reloads the list once that page reports
  /// the order changed underneath — a cancellation is the only way it can.
  Future<void> _open(
    BuildContext context,
    String routeName,
    Object argument,
  ) async {
    final cubit = context.read<OrdersCubit>();
    final changed = await Navigator.of(context)
        .pushNamed(routeName, arguments: argument);
    if (changed == true) await cubit.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final firstLine = order.header;
    final total = order.grandTotal ?? firstLine.chargedTotal;
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.md),
      child: Semantics(
        button: true,
        label: S.orderNumber(order.displayNumber),
        child: Material(
          color: AppColor.cardSurface,
          borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
          child: InkWell(
            // The whole group travels with the route: a pushed page is built by
            // the root navigator, so its lines can only arrive as an argument.
            onTap: () => _open(context, OrderDetailsPage.routeName, order),
            borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
            child: Container(
              padding: EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                border: Border.all(color: AppColor.borderColor),
                borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          S.orderNumber(order.displayNumber),
                          style: AppFonts.semiBold16(context),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      OrderStatusBadge(status: order.status),
                    ],
                  ),
                  SizedBox(height: AppSpacing.xs),
                  if (order.placedAt != null)
                    Text(
                      Formatters.date(order.placedAt!),
                      style: AppFonts.regular12(context)
                          .copyWith(color: AppColor.greyColor),
                    ),
                  SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.r8),
                        child: SizedBox(
                          height: AppSizes.px56,
                          width: AppSizes.px56,
                          child: ProductImageView(product: firstLine.product),
                        ),
                      ),
                      SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              firstLine.product.name,
                              style: AppFonts.medium14(context),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: AppSpacing.xxs),
                            Text(
                              '${S.itemsCount}: ${order.itemCount}',
                              style: AppFonts.regular12(context)
                                  .copyWith(color: AppColor.greyColor),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Text(
                        S.total,
                        style: AppFonts.regular12(context)
                            .copyWith(color: AppColor.greyColor),
                      ),
                      SizedBox(width: AppSpacing.xs),
                      PriceLabel(
                        amount: total,
                        style: AppFonts.semiBold16(context)
                            .copyWith(color: AppColor.primaryColor),
                        iconSize: AppIconSize.md,
                        iconColor: AppColor.primaryColor,
                      ),
                      const Spacer(),
                      if (order.status == OrderStatus.active)
                        _PillButton(
                          label: S.trackOrder,
                          onTap: () => _open(
                            context,
                            TrackOrderPage.routeName,
                            order.header,
                          ),
                        )
                      else if (order.status == OrderStatus.completed)
                        _PillButton(
                          label: S.leaveReview,
                          onTap: () => _open(
                            context,
                            LeaveReviewPage.routeName,
                            order.header,
                          ),
                        ),
                    ],
                  ),
                  if (order.status == OrderStatus.completed) ...[
                    SizedBox(height: AppSpacing.sm),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        CustomOutlinedButton.icon(
                          onPressed: () => _saveAsList(context),
                          icon: const AppIcon(AppIcons.bundle),
                          label: Text(S.saveOrderAsList),
                        ),
                        CustomOutlinedButton.icon(
                          onPressed: () => _reorder(context),
                          icon: const AppIcon(AppIcons.repeat),
                          label: Text(S.reorderOrder),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The one action this order offers, drawn beside its total.
class _PillButton extends StatelessWidget {
  const _PillButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Padding(
        padding: EdgeInsetsDirectional.only(start: AppSpacing.sm),
        child: Semantics(
          button: true,
          label: label,
          child: Material(
            color: AppColor.primaryColor,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              // A control keeps the smallest target the app holds any tappable
              // thing to, even though its own text is 12pt.
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: AppDimensions.tapTargetMin,
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppFonts.regular12(context)
                              .copyWith(color: AppColor.whiteColor),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
