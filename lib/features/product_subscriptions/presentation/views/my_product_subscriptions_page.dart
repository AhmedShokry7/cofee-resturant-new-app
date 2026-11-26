import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
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
              itemCount: state.items.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (_, i) {
                final s = state.items[i];
                final isActive = s.status.toLowerCase() == 'active';
                final isPaused = s.status.toLowerCase() == 'paused';
                final localNextRun = s.nextRunAt?.toLocal();
                final nextRun = localNextRun != null
                    ? '${localNextRun.year}-${localNextRun.month.toString().padLeft(2, '0')}-${localNextRun.day.toString().padLeft(2, '0')} ${localNextRun.hour.toString().padLeft(2, '0')}:${localNextRun.minute.toString().padLeft(2, '0')}'
                    : null;
                return Card(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        title: Text(s.name ?? S.productSubscriptions),
                        subtitle: Text(
                          '${_statusLabel(s.status)} · ${S.repeatInterval(s.intervalValue, s.frequency)}'
                          '${nextRun != null ? ' · ${S.nextRun}: $nextRun' : ''}'
                          '${s.items.isNotEmpty ? '\n${s.items.map((item) => '${item.productNameAr ?? item.productNameEn ?? item.productId} × ${item.quantity}').join('، ')}' : ''}',
                        ),
                        isThreeLine: nextRun != null || s.items.isNotEmpty,
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) {
                            if (v == 'pause') {
                              context.read<ProductSubscriptionsCubit>().pause(
                                s.id,
                              );
                            } else if (v == 'resume') {
                              context.read<ProductSubscriptionsCubit>().resume(
                                s.id,
                              );
                            } else if (v == 'cancel') {
                              _confirmCancel(context, s.id);
                            }
                          },
                          itemBuilder: (_) => [
                            if (isActive)
                              PopupMenuItem(
                                value: 'pause',
                                child: Text(S.pause),
                              ),
                            if (isPaused)
                              PopupMenuItem(
                                value: 'resume',
                                child: Text(S.resume),
                              ),
                            if (isActive || isPaused)
                              PopupMenuItem(
                                value: 'cancel',
                                child: Text(
                                  S.cancel,
                                  style: const TextStyle(
                                    color: AppColor.errorColor,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      for (final run in s.pendingRuns)
                        Padding(
                          padding: const EdgeInsetsDirectional.fromSTEB(
                            AppSpacing.md,
                            0,
                            AppSpacing.md,
                            AppSpacing.md,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                '${S.productSubscriptionOrderDue}: ${run.scheduledFor.toLocal().toString().substring(0, 16)}',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              CustomFilledButton.icon(
                                onPressed: isActive
                                    ? () => _reviewDueRun(context, s, run)
                                    : null,
                                icon: const Icon(AppIcons.bag),
                                label: Text(S.reviewAndConfirmOrder),
                              ),
                              CustomTextButton(
                                onPressed: () => _skipRun(context, run),
                                child: Text(S.skipThisOccurrence),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(context),
        child: const Icon(AppIcons.add),
      ),
    );
  }
}
