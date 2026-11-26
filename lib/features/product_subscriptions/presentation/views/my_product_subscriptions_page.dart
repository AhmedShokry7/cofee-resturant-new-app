import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/theme/tokens.dart';
import 'package:new_coffee/features/cart/presentation/manager/cart/cart_cubit.dart';
import 'package:new_coffee/features/checkout/presentation/manager/checkout/checkout_cubit.dart';
import 'package:new_coffee/features/checkout/presentation/views/checkout_page.dart';
import 'package:new_coffee/features/menu/data/repositories/supabase_product_repository.dart';
import 'package:new_coffee/features/product_subscriptions/data/model/product_subscription.dart';
import 'package:new_coffee/features/product_subscriptions/data/repositories/product_subscription_repository.dart';
import 'package:new_coffee/features/product_subscriptions/presentation/manager/product_subscriptions_cubit.dart';
import 'package:new_coffee/features/product_subscriptions/presentation/manager/product_subscriptions_state.dart';
import 'package:new_coffee/features/product_subscriptions/presentation/views/product_subscription_form_page.dart';
import 'package:new_coffee/shared/widgets/auth_guard.dart';
import 'package:new_coffee/shared/widgets/design_text.dart';
import 'package:new_coffee/shared/widgets/empty_state.dart';
import 'package:new_coffee/shared/widgets/app_back_button.dart';
import 'package:new_coffee/shared/utils/formatters.dart';

class MyProductSubscriptionsPage extends StatelessWidget {
  const MyProductSubscriptionsPage({super.key});
  static const routeName = '/my-product-subscriptions';

  @override
  Widget build(BuildContext context) {
    return AuthGuard(
      child: BlocProvider(
        create: (_) =>
            ProductSubscriptionsCubit(ProductSubscriptionRepository())..load(),
        child: const _ProductSubscriptionsView(),
      ),
    );
  }
}

class _ProductSubscriptionsView extends StatelessWidget {
  const _ProductSubscriptionsView();

  Future<void> _openForm(BuildContext context) async {
    await Navigator.of(context)
        .pushNamed(ProductSubscriptionFormPage.routeName);
    if (context.mounted) context.read<ProductSubscriptionsCubit>().load();
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return S.activeStatus;
      case 'paused':
        return S.paused;
      case 'cancelled':
      case 'canceled':
        return S.cancelledStatus;
      default:
        return status;
    }
  }

  Widget _statusPill(BuildContext context, String status) {
    final active = status.toLowerCase() == 'active';
    final color = active ? AppColor.successColor : AppColor.greyColor;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        _statusLabel(status),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: active ? AppColor.successColorDeep : AppColor.greyColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _dateTime(DateTime value) {
    final local = value.toLocal();
    final time = '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    return '${Formatters.date(local)} · $time';
  }

  String _itemName(ProductSubscriptionItem item) =>
      AppLocale.instance.isArabic
          ? (item.productNameAr ?? item.productNameEn ?? item.productId)
          : (item.productNameEn ?? item.productNameAr ?? item.productId);

  Future<void> _confirmCancel(BuildContext context, String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.cancelSubscription),
        actions: [
          CustomTextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(S.cancel),
          ),
          CustomTextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              S.confirm,
              style: const TextStyle(color: AppColor.errorColor),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<ProductSubscriptionsCubit>().cancel(id);
    }
  }

  Future<void> _skipRun(
    BuildContext context,
    ProductSubscriptionRun run,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(S.skipThisOccurrence),
        content: Text(S.skipSubscriptionOccurrenceConfirm),
        actions: [
          CustomTextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(S.cancel),
          ),
          CustomFilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(S.confirm),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<ProductSubscriptionsCubit>().skipRun(run.id);
    }
  }

  Future<void> _reviewDueRun(
    BuildContext context,
    ProductSubscription subscription,
    ProductSubscriptionRun run,
  ) async {
    final cart = context.read<CartCubit>();
    final checkout = context.read<CheckoutCubit>();
    final navigator = Navigator.of(context);
    if (cart.state.items.isNotEmpty) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          content: Text(S.replaceCartForSubscription),
          actions: [
            CustomTextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(S.cancel),
            ),
            CustomFilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(S.confirm),
            ),
          ],
        ),
      );
      if (replace != true || !context.mounted) return;
    }

    try {
      final products = await SupabaseProductRepository().getByIds(
        subscription.items.map((item) => item.productId).toList(),
        branchId: subscription.branchId,
      );
      final productsById = {
        for (final product in products) product.id: product,
      };
      if (subscription.items.any(
        (item) => !productsById.containsKey(item.productId),
      )) {
        throw StateError('A scheduled product is no longer available.');
      }
      await checkout.prepareSubscriptionOrder(
        runId: run.id,
        targetBranchId: subscription.branchId,
        fulfillmentType: subscription.fulfillmentType,
        addressId: subscription.deliveryAddressId,
      );
      if (!context.mounted) return;
      await cart.setBranch(subscription.branchId);
      cart.clear();
      for (final item in subscription.items) {
        cart.add(
          productsById[item.productId]!,
          quantity: item.quantity,
          note: item.note ?? '',
          optionValueIds: item.optionValueIds,
        );
      }
      await navigator.pushNamed(CheckoutPage.routeName);
      if (context.mounted) context.read<ProductSubscriptionsCubit>().load();
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.couldNotPrepareSubscriptionOrder)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: DesignText(
          S.productSubscriptions,
          page: 'my_product_subscriptions',
          label: 'title',
        ),
      ),
      body: BlocConsumer<ProductSubscriptionsCubit, ProductSubscriptionsState>(
        listener: (context, state) {
          if (state.error != null) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(state.error!)));
          }
        },
        builder: (context, state) {
          if (state.status == ProductSubscriptionsStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == ProductSubscriptionsStatus.failure) {
            return EmptyState(
              icon: AppIcons.repeat,
              title: S.couldNotLoadProductSubscriptions,
              actionLabel: S.retry,
              onAction: () => context.read<ProductSubscriptionsCubit>().load(),
            );
          }
          if (state.items.isEmpty) {
            return EmptyState(
              icon: AppIcons.repeat,
              title: S.noProductSubscriptionsYet,
              subtitle: S.productSubscriptionsHint,
              actionLabel: S.newProductSubscription,
              onAction: () => _openForm(context),
            );
          }
          return RefreshIndicator(
            onRefresh: () => context.read<ProductSubscriptionsCubit>().load(),
            child: ListView.separated(
              padding: AppLayout.pageBody,
              itemCount: state.items.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColor.primarySoft,
                      borderRadius: BorderRadius.circular(AppRadius.r16),
                    ),
                    child: Row(
                      children: [
                        Icon(AppIcons.repeat, color: AppColor.primaryColor),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            S.productSubscriptionsDescription,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                final subscription = state.items[index - 1];
                final isActive = subscription.status.toLowerCase() == 'active';
                final isPaused = subscription.status.toLowerCase() == 'paused';
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                subscription.name?.trim().isNotEmpty == true
                                    ? subscription.name!
                                    : S.productSubscriptions,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            _statusPill(context, subscription.status),
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'pause') {
                                  context.read<ProductSubscriptionsCubit>().pause(subscription.id);
                                } else if (value == 'resume') {
                                  context.read<ProductSubscriptionsCubit>().resume(subscription.id);
                                } else if (value == 'cancel') {
                                  _confirmCancel(context, subscription.id);
                                }
                              },
                              itemBuilder: (_) => [
                                if (isActive) PopupMenuItem(value: 'pause', child: Text(S.pause)),
                                if (isPaused) PopupMenuItem(value: 'resume', child: Text(S.resume)),
                                if (isActive || isPaused)
                                  PopupMenuItem(
                                    value: 'cancel',
                                    child: Text(S.cancel, style: const TextStyle(color: AppColor.errorColor)),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xs,
                          children: [
                            _detailPill(context, AppIcons.repeat, S.repeatInterval(subscription.intervalValue, subscription.frequency)),
                            if (subscription.nextRunAt != null)
                              _detailPill(context, AppIcons.calendar, '${S.nextRun}: ${_dateTime(subscription.nextRunAt!)}'),
                            _detailPill(context, AppIcons.coffee, _fulfillmentLabel(subscription.fulfillmentType)),
                          ],
                        ),
                        if (subscription.items.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.md),
                          Text(S.product, style: Theme.of(context).textTheme.labelLarge),
                          const SizedBox(height: AppSpacing.xs),
                          Wrap(
                            spacing: AppSpacing.xs,
                            runSpacing: AppSpacing.xs,
                            children: subscription.items.map((item) => _detailPill(
                              context,
                              AppIcons.package,
                              '${_itemName(item)} × ${item.quantity}',
                            )).toList(),
                          ),
                        ],
                        for (final run in subscription.pendingRuns) ...[
                          const SizedBox(height: AppSpacing.md),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: AppColor.lightGreyColor,
                              borderRadius: BorderRadius.circular(AppRadius.r12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(S.productSubscriptionOrderDue, style: Theme.of(context).textTheme.labelLarge),
                                const SizedBox(height: AppSpacing.xxs),
                                Text(_dateTime(run.scheduledFor)),
                                const SizedBox(height: AppSpacing.sm),
                                CustomFilledButton.icon(
                                  onPressed: isActive ? () => _reviewDueRun(context, subscription, run) : null,
                                  icon: const Icon(AppIcons.bag),
                                  label: Text(S.reviewAndConfirmOrder),
                                ),
                                Align(
                                  alignment: AlignmentDirectional.centerEnd,
                                  child: CustomTextButton(
                                    onPressed: () => _skipRun(context, run),
                                    child: Text(S.skipThisOccurrence),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context),
        icon: const Icon(AppIcons.add),
        label: Text(S.newProductSubscription),
      ),
    );
  }

  String _fulfillmentLabel(String type) => type == 'delivery' ? S.delivery : S.pickup;

  Widget _detailPill(BuildContext context, IconData icon, String label) =>
      Container(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.sm, AppSpacing.xxs, AppSpacing.sm, AppSpacing.xxs,
        ),
        decoration: BoxDecoration(
          color: AppColor.lightGreyColor,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: AppSizes.px16, color: AppColor.greyColor),
            const SizedBox(width: AppSpacing.xxs),
            Flexible(child: Text(label, style: Theme.of(context).textTheme.labelMedium)),
          ],
        ),
      );
}
