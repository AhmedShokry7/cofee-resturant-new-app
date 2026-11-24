import 'package:new_coffee/shared/widgets/design_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/features/branch/presentation/manager/branch/branch_cubit.dart';
import 'package:new_coffee/features/payment/presentation/views/card_payment_page.dart';
import 'package:new_coffee/features/subscriptions/data/model/customer_subscription.dart';
import 'package:new_coffee/features/subscriptions/data/model/subscription_usage.dart';
import 'package:new_coffee/features/subscriptions/data/repositories/subscription_repository.dart';
import 'package:new_coffee/features/subscriptions/presentation/manager/subscription/subscription_cubit.dart';
import 'package:new_coffee/features/subscriptions/presentation/views/subscription_plans_page.dart';
import 'package:new_coffee/features/subscriptions/presentation/views/widgets/subscription_detail_row.dart';
import 'package:new_coffee/shared/utils/formatters.dart';
import 'package:new_coffee/shared/widgets/auth_guard.dart';
import 'package:new_coffee/core/theme/tokens.dart';
import 'package:qr/qr.dart';

class SubscriptionDetailsPage extends StatelessWidget {
  const SubscriptionDetailsPage({super.key});

  static const routeName = '/subscription-details';

  @override
  Widget build(BuildContext context) {
    // `my_subscription` is revoked from anon (074), so a guest cannot read a
    // subscription that does not exist yet. The shared prompt replaces the
    // request.
    return AuthGuard(
      child: BlocProvider(
        create: (context) => SubscriptionCubit(
          repository: context.read<SubscriptionRepository>(),
          branchId: context.read<BranchCubit>().state.selected?.id,
        )..load(),
        // A renewal is priced by the plan the selected branch sells (083
        // filters on `p_branch_id`), so moving to another branch while this
        // page is open has to re-read it.
        child: BlocListener<BranchCubit, BranchState>(
          listenWhen: (previous, current) =>
              previous.selected?.id != current.selected?.id,
          listener: (context, state) =>
              context.read<SubscriptionCubit>().setBranch(state.selected?.id),
          child: const _SubscriptionDetailsView(),
        ),
      ),
    );
  }
}

class _SubscriptionDetailsView extends StatelessWidget {
  const _SubscriptionDetailsView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: DesignText(
          S.mySubscription,
          page: 'subscription_details',
          label: 'mySubscription',
        ),
      ),
      body: BlocBuilder<SubscriptionCubit, SubscriptionState>(
        builder: (context, state) {
          final subscription = state.subscription;
          // The page a customer is standing on stays up while it is being
          // re-read; only a page that has never been answered shows a spinner.
          if (state.loading && subscription == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (subscription == null && state.loadError != null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(S.couldNotLoadSubscription, textAlign: TextAlign.center),
                  SizedBox(height: AppSpacing.md),
                  FilledButton(
                    onPressed: () => context.read<SubscriptionCubit>().load(),
                    child: DesignText(
                      S.retry,
                      page: 'subscription_details',
                      label: 'retry',
                    ),
                  ),
                ],
              ),
            );
          }
          if (subscription == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DesignText(
                    S.noSubscriptionYet,
                    page: 'subscription_details',
                    label: 'noSubscriptionYet',
                  ),
                  SizedBox(height: AppSpacing.md),
                  FilledButton(
                    onPressed: () =>
                        Navigator.of(context)
                            .pushNamed(SubscriptionPlansPage.routeName),
                    child: DesignText(
                      S.browsePlans,
                      page: 'subscription_details',
                      label: 'browsePlans',
                    ),
                  ),
                ],
              ),
            );
          }
          return _SubscriptionBody(
            subscription: subscription,
            state: state,
            cubit: context.read<SubscriptionCubit>(),
          );
        },
      ),
    );
  }
}

class _SubscriptionBody extends StatelessWidget {
  const _SubscriptionBody({
    required this.subscription,
    required this.state,
    required this.cubit,
  });

  final CustomerSubscription subscription;
  final SubscriptionState state;
  final SubscriptionCubit cubit;

  @override
  Widget build(BuildContext context) {
    // A write is in flight, so no button on this page can say what it would do.
    final busy = state.isMutating;
    return ListView(
      padding: EdgeInsets.all(AppSpacing.lg),
      children: [
        if (state.loadError != null) ...[
          _StaleNotice(onRetry: () => cubit.load()),
          SizedBox(height: AppSpacing.md),
        ],
        _SubscriptionSummary(subscription: subscription),
        SizedBox(height: AppSpacing.md),
        _SubscriptionFacts(subscription: subscription),
        SizedBox(height: AppSpacing.sm),
        Card(
          margin: EdgeInsets.zero,
          child: SwitchListTile(
            contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
            title: DesignText(
              S.autoRenew,
              page: 'subscription_details',
              label: 'autoRenew',
            ),
            value: subscription.autoRenew,
            onChanged: subscription.isActive && !busy
                ? (value) => _setAutoRenew(context, value)
                : null,
          ),
        ),
        SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            if (subscription.isPendingPayment)
              FilledButton(
                onPressed: busy ? null : () => cubit.load(),
                child: DesignText(
                  S.checkPaymentStatus,
                  page: 'subscription_details',
                  label: 'checkPaymentStatus',
                ),
              ),
            if (subscription.isActive)
              FilledButton(
                onPressed: busy ? null : () => _showQr(context),
                child: DesignText(
                  S.showQrCode,
                  page: 'subscription_details',
                  label: 'showQrCode',
                ),
              ),
            OutlinedButton(
              onPressed: busy ? null : () => _renew(context),
              child: DesignText(
                S.renew,
                page: 'subscription_details',
                label: 'renew',
              ),
            ),
            OutlinedButton(
              onPressed: subscription.isActive && !busy
                  ? () => _cancel(context)
                  : null,
              child: DesignText(
                S.cancel,
                page: 'subscription_details',
                label: 'cancel',
              ),
            ),
          ],
        ),
        SizedBox(height: AppSpacing.lg),
        Text(S.usageHistory, style: AppFonts.semiBold16(context)),
        SizedBox(height: AppSpacing.xs),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: _UsageHistory(
              state: state,
              onRetry: () => cubit.loadUsage(subscription.id),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _setAutoRenew(BuildContext context, bool value) async {
    final messenger = ScaffoldMessenger.of(context);
    if (await cubit.setAutoRenew(value)) return;
    messenger.showSnackBar(
      SnackBar(
        content: DesignText(
          S.couldNotSaveAutoRenew,
          page: 'subscription_details',
          label: 'couldNotSaveAutoRenew',
        ),
      ),
    );
  }

  /// Makes a pass, or says why there is none.
  ///
  /// A token the cashier would refuse is worse than no token at all, so the
  /// page only ever shows what the server handed back.
  Future<void> _showQr(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!await cubit.showQr()) {
      messenger.showSnackBar(
        SnackBar(
          content: DesignText(
            S.couldNotShowQr,
            page: 'subscription_details',
            label: 'couldNotShowQr',
          ),
        ),
      );
      return;
    }
    if (!context.mounted || cubit.state.qrToken == null) return;
    final qrSize = (MediaQuery.sizeOf(context).width - 128)
        .clamp(128.0, 240.0)
        .toDouble();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: DesignText(
          S.showQrCode,
          page: 'subscription_details',
          label: 'showQrCode',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
              ),
              child: CustomPaint(
                size: Size.square(qrSize),
                painter: _SubscriptionQrPainter(cubit.state.qrToken!),
              ),
            ),
            SizedBox(height: AppSpacing.md),
            Text(S.qrSingleUseHint, textAlign: TextAlign.center),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: DesignText(
              S.ok,
              page: 'subscription_details',
              label: 'closeQr',
            ),
          ),
        ],
      ),
    );
  }

  /// Renews and pays for the new cycle.
  ///
  /// The subscription the payment is opened for is the row the renewal
  /// created: charging the id this page already held would pay off a cycle
  /// that is already spent. The amount comes from the plan the cubit can name,
  /// because an unknown plan is never charged as a free one.
  Future<void> _renew(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final renewed = await cubit.renew();
    if (renewed == null) {
      messenger.showSnackBar(
        SnackBar(
          content: DesignText(
            S.couldNotRenewSubscription,
            page: 'subscription_details',
            label: 'couldNotRenewSubscription',
          ),
        ),
      );
      return;
    }
    final plan = cubit.renewalPlan;
    if (plan == null) {
      messenger.showSnackBar(
        SnackBar(
          content: DesignText(
            S.couldNotPriceRenewal,
            page: 'subscription_details',
            label: 'couldNotPriceRenewal',
          ),
        ),
      );
      // The new row is real and unpaid, so the page is re-read rather than left
      // showing a subscription the customer cannot act on.
      await cubit.load();
      return;
    }
    if (!context.mounted) return;
    CardPaymentPage.pushForSubscription(
      context,
      subscriptionId: renewed.id,
      amount: plan.price,
      currency: plan.currencyCode,
    );
  }

  Future<void> _cancel(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    if (await cubit.cancel()) return;
    messenger.showSnackBar(
      SnackBar(
        content: DesignText(
          S.couldNotCancelSubscription,
          page: 'subscription_details',
          label: 'couldNotCancelSubscription',
        ),
      ),
    );
  }
}

class _SubscriptionSummary extends StatelessWidget {
  const _SubscriptionSummary({required this.subscription});

  final CustomerSubscription subscription;

  @override
  Widget build(BuildContext context) {
    final total = subscription.cupsEntitled + subscription.cupsCarriedOver;
    final progress = total == 0
        ? 0.0
        : (subscription.availableCups / total).clamp(0.0, 1.0).toDouble();
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subscription.planName, style: AppFonts.semiBold20(context)),
            SizedBox(height: AppSpacing.xs),
            SubscriptionDetailRow(
              label: S.subscriptionStatus,
              value: subscription.statusLabel,
            ),
            SizedBox(height: AppSpacing.sm),
            SubscriptionDetailRow(
              label: S.availableCups,
              value: '${subscription.availableCups}',
            ),
            SizedBox(height: AppSpacing.xs),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: AppColor.borderColor,
              ),
            ),
            SizedBox(height: AppSpacing.xs),
            SubscriptionDetailRow(
              label: S.cupsUsed,
              value: '${subscription.cupsUsed}',
            ),
          ],
        ),
      ),
    );
  }
}

class _SubscriptionFacts extends StatelessWidget {
  const _SubscriptionFacts({required this.subscription});

  final CustomerSubscription subscription;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (subscription.startsAt != null)
            SubscriptionDetailRow(
              label: S.subscriptionStart,
              value: Formatters.date(subscription.startsAt!),
            ),
          if (subscription.endsAt != null)
            SubscriptionDetailRow(
              label: S.subscriptionEnd,
              value: Formatters.date(subscription.endsAt!),
            ),
          SubscriptionDetailRow(
            label: S.cupsCarriedOver,
            value: '${subscription.cupsCarriedOver}',
          ),
          SubscriptionDetailRow(
            label: S.extraCredit,
            value: Formatters.amount(subscription.bonusBalance),
          ),
          if (subscription.bonusExpiresAt != null)
            SubscriptionDetailRow(
              label: S.creditExpires,
              value: Formatters.date(subscription.bonusExpiresAt!),
            ),
        ],
      ),
    ),
  );
}

class _SubscriptionQrPainter extends CustomPainter {
  _SubscriptionQrPainter(String token)
    : _image = QrImage(
        QrCode.fromData(data: token, errorCorrectLevel: QrErrorCorrectLevel.M),
      );

  final QrImage _image;

  @override
  void paint(Canvas canvas, Size size) {
    final moduleSize = size.width / (_image.moduleCount + 8);
    final quietZone = moduleSize * 4;
    final paint = Paint()..color = Colors.black;
    for (var row = 0; row < _image.moduleCount; row++) {
      for (var column = 0; column < _image.moduleCount; column++) {
        if (_image.isDark(row, column)) {
          canvas.drawRect(
            Rect.fromLTWH(
              quietZone + column * moduleSize,
              quietZone + row * moduleSize,
              moduleSize,
              moduleSize,
            ),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SubscriptionQrPainter oldDelegate) =>
      oldDelegate._image != _image;
}

/// A re-read that failed while the page still holds the answer from before.
///
/// The rows stay on screen - they are the customer's own facts - and the
/// banner says the page may not be current and offers the retry that a
/// replaced screen would have hidden.
class _StaleNotice extends StatelessWidget {
  const _StaleNotice({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColor.primarySoft,
        borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              S.subscriptionOutdated,
              style: AppFonts.regular14(context),
            ),
          ),
          Semantics(
            button: true,
            label: S.retry,
            child: Material(
              color: AppColor.transparent,
              child: TextButton(
                onPressed: onRetry,
                child: DesignText(
                  S.retry,
                  page: 'subscription_details',
                  label: 'retry',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The cups already spent.
///
/// "Not read yet" and "read, nothing there" are shown apart, so an empty
/// history never looks like a spinner that never stops.
class _UsageHistory extends StatelessWidget {
  const _UsageHistory({required this.state, required this.onRetry});

  final SubscriptionState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (state.usageError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(S.couldNotLoadUsage, style: AppFonts.regular14(context)),
          TextButton(
            onPressed: onRetry,
            child: DesignText(
              S.retry,
              page: 'subscription_details',
              label: 'retry',
            ),
          ),
        ],
      );
    }
    final usage = state.usage;
    if (usage == null) {
      return Padding(
        padding: EdgeInsets.all(AppSpacing.sm),
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    if (usage.isEmpty) {
      return DesignText(
        S.noUsageYet,
        page: 'subscription_details',
        label: 'noUsageYet',
      );
    }
    return Column(
      children: [for (final entry in usage) _UsageRow(entry: entry)],
    );
  }
}

class _UsageRow extends StatelessWidget {
  const _UsageRow({required this.entry});

  final SubscriptionUsage entry;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(entry.title),
      subtitle: Text(S.cupsCount(entry.quantity)),
      trailing: entry.createdAt == null
          ? null
          : Text(
              Formatters.date(entry.createdAt!),
              style: AppFonts.regular14(context),
            ),
    );
  }
}
