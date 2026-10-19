import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/spacing_tokens.dart';
import 'package:admin_app/core/utils/formatters.dart';
import 'package:admin_app/features/auth/data/models/admin_session.dart';
import 'package:admin_app/features/dashboard/data/models/dashboard_stats.dart';
import 'package:admin_app/features/dashboard/presentation/manager/dashboard_cubit.dart';
import 'package:admin_app/features/dashboard/presentation/manager/dashboard_state.dart';
import 'package:admin_app/features/dashboard/presentation/widgets/recent_orders_card.dart';
import 'package:admin_app/features/dashboard/presentation/widgets/stat_card.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key, required this.session});

  final AdminSession session;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<DashboardCubit>(
      create: (_) => DashboardCubit(session: session)..load(),
      child: _DashboardView(session: session),
    );
  }
}

class _DashboardView extends StatelessWidget {
  const _DashboardView({required this.session});

  final AdminSession session;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DashboardCubit, DashboardState>(
      builder: (context, state) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(SpacingTokens.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(
                session: session,
                onRefresh: state.status == DashboardStatus.loading
                    ? null
                    : () => context.read<DashboardCubit>().load(),
              ),
              const SizedBox(height: SpacingTokens.xl),
              switch (state.status) {
                DashboardStatus.loading => const _LoadingState(),
                DashboardStatus.error => _ErrorState(
                    message: state.errorMessage ?? 'Failed to load dashboard.',
                    onRetry: () => context.read<DashboardCubit>().load(),
                  ),
                DashboardStatus.ready => _Content(
                    stats: state.stats ?? const DashboardStats(),
                  ),
              },
            ],
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.session, this.onRefresh});

  final AdminSession session;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final firstName = session.fullName.trim().split(RegExp(r'\s+')).first;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dashboard',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: SpacingTokens.xs),
              Text(
                firstName.isEmpty
                    ? 'Welcome back.'
                    : 'Welcome back, $firstName.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColor.greyColor,
                    ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Refresh',
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.stats});

  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final cards = _cards(context, stats);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = SpacingTokens.lg;
            final columns = constraints.maxWidth >= 1200
                ? 4
                : constraints.maxWidth >= 820
                    ? 3
                    : constraints.maxWidth >= 560
                        ? 2
                        : 1;
            final width =
                (constraints.maxWidth - gap * (columns - 1)) / columns;

            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final card in cards)
                  SizedBox(width: width, child: card),
              ],
            );
          },
        ),
        const SizedBox(height: SpacingTokens.xl),
        RecentOrdersCard(orders: stats.recentOrders),
        if (stats.totalOrders != null) ...[
          const SizedBox(height: SpacingTokens.md),
          Text(
            'Total orders to date: ${formatCount(stats.totalOrders!)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColor.greyColor,
                ),
          ),
        ],
      ],
    );
  }

  List<Widget> _cards(BuildContext context, DashboardStats stats) {
    final cards = <Widget>[
      if (stats.todayOrders != null)
        StatCard(
          label: "Today's orders",
          value: formatCount(stats.todayOrders!),
          icon: Icons.receipt_long_outlined,
          accent: AppColor.primaryColor,
        ),
      if (stats.todayRevenue != null)
        StatCard(
          label: "Today's revenue",
          value: formatMoney(stats.todayRevenue!),
          icon: Icons.payments_outlined,
          accent: AppColor.greenColor,
        ),
      if (stats.activeOrders != null)
        StatCard(
          label: 'Active orders',
          value: formatCount(stats.activeOrders!),
          icon: Icons.timelapse_outlined,
          accent: const Color(0xFFB45309),
        ),
      if (stats.activeProducts != null)
        StatCard(
          label: 'Active products',
          value: formatCount(stats.activeProducts!),
          icon: Icons.local_cafe_outlined,
          accent: AppColor.secondryColor,
        ),
      if (stats.customers != null)
        StatCard(
          label: 'Customers',
          value: formatCount(stats.customers!),
          icon: Icons.people_outline,
          accent: AppColor.primaryColor,
        ),
      if (stats.activeBranches != null)
        StatCard(
          label: 'Active branches',
          value: formatCount(stats.activeBranches!),
          icon: Icons.storefront_outlined,
          accent: AppColor.secondryColor,
        ),
    ];

    return cards.isEmpty
        ? [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(SpacingTokens.xl),
                child: Text(
                  'Your role does not include dashboard metrics.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColor.greyColor,
                      ),
                ),
              ),
            ),
          ]
        : cards;
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: SpacingTokens.xxxl),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(SpacingTokens.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.error_outline, color: AppColor.errorColor),
                const SizedBox(width: SpacingTokens.sm),
                Text(
                  'Could not load dashboard',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: SpacingTokens.sm),
            Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColor.greyColor,
                  ),
            ),
            const SizedBox(height: SpacingTokens.lg),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
