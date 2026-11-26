import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/tokens.dart';
import 'package:new_coffee/features/product_subscriptions/data/repositories/product_subscription_repository.dart';
import 'package:new_coffee/features/product_subscriptions/presentation/manager/product_subscriptions_cubit.dart';
import 'package:new_coffee/features/product_subscriptions/presentation/manager/product_subscriptions_state.dart';
import 'package:new_coffee/features/product_subscriptions/presentation/views/product_subscription_form_page.dart';
import 'package:new_coffee/shared/widgets/auth_guard.dart';
import 'package:new_coffee/shared/widgets/design_text.dart';
import 'package:new_coffee/shared/widgets/empty_state.dart';

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
    await Navigator.of(context).pushNamed(ProductSubscriptionFormPage.routeName);
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

  String _frequencyLabel(String freq) {
    switch (freq.toLowerCase()) {
      case 'daily':
        return S.daily;
      case 'weekly':
        return S.weekly;
      case 'monthly':
        return S.monthly;
      default:
        return freq;
    }
  }

  Future<void> _confirmCancel(BuildContext context, String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.cancelSubscription),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(S.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(S.confirm, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<ProductSubscriptionsCubit>().cancel(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
              icon: Icons.autorenew_outlined,
              title: S.couldNotLoadProductSubscriptions,
              actionLabel: S.retry,
              onAction: () => context.read<ProductSubscriptionsCubit>().load(),
            );
          }
          if (state.items.isEmpty) {
            return EmptyState(
              icon: Icons.autorenew_outlined,
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
                final nextRun = s.nextRunAt != null
                    ? '${s.nextRunAt!.year}-${s.nextRunAt!.month.toString().padLeft(2, '0')}-${s.nextRunAt!.day.toString().padLeft(2, '0')}'
                    : null;
                return Card(
                  child: ListTile(
                    title: Text(s.name ?? S.productSubscriptions),
                    subtitle: Text(
                      '${_statusLabel(s.status)} · ${_frequencyLabel(s.frequency)}'
                      '${nextRun != null ? ' · ${S.nextRun}: $nextRun' : ''}',
                    ),
                    isThreeLine: nextRun != null,
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'pause') {
                          context.read<ProductSubscriptionsCubit>().pause(s.id);
                        } else if (v == 'resume') {
                          context.read<ProductSubscriptionsCubit>().resume(s.id);
                        } else if (v == 'cancel') {
                          _confirmCancel(context, s.id);
                        }
                      },
                      itemBuilder: (_) => [
                        if (isActive)
                          PopupMenuItem(value: 'pause', child: Text(S.pause)),
                        if (isPaused)
                          PopupMenuItem(value: 'resume', child: Text(S.resume)),
                        if (isActive || isPaused)
                          PopupMenuItem(
                            value: 'cancel',
                            child: Text(S.cancel, style: const TextStyle(color: Colors.red)),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}
