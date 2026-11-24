import 'package:material_ui/material_ui.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/features/marketing/domain/entities/marketing_entities.dart';
import 'package:admin_app/features/marketing/presentation/manager/marketing_cubit.dart';
import 'package:admin_app/features/marketing/presentation/manager/marketing_state.dart';
import 'package:admin_app/features/marketing/presentation/widgets/campaign_dialogs.dart';
import 'package:admin_app/shared/widgets/admin_empty_state.dart';
import 'package:admin_app/shared/widgets/admin_metric_card.dart';
import 'package:admin_app/shared/widgets/admin_page_title.dart';
import 'package:admin_app/shared/widgets/admin_create_button.dart';
import 'package:admin_app/shared/widgets/admin_state_view.dart';
import 'package:admin_app/shared/widgets/admin_status_badge.dart';
import 'package:admin_app/shared/widgets/custom_btn.dart';

/// Marketing Hub shell. Each tab renders only what the backend actually
/// returned; a missing backend surfaces as an explicit failure message
/// (never fabricated numbers).
class MarketingHubPage extends StatelessWidget {
  const MarketingHubPage({
    super.key,
    this.canCreate = false,
    this.canReview = false,
    this.canSchedule = false,
    this.canSend = false,
    this.canReadConsent = false,
    this.cubit,
  });

  final bool canCreate;
  final bool canReview;
  final bool canSchedule;
  final bool canSend;
  final bool canReadConsent;
  final MarketingCubit? cubit;

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: cubit ?? MarketingCubit(),
      child: _HubBody(
        canCreate: canCreate,
        canReview: canReview,
        canSchedule: canSchedule,
        canSend: canSend,
        canReadConsent: canReadConsent,
      ),
    );
  }
}

class _HubBody extends StatefulWidget {
  const _HubBody({
    required this.canCreate,
    required this.canReview,
    required this.canSchedule,
    required this.canSend,
    required this.canReadConsent,
  });

  final bool canCreate;
  final bool canReview;
  final bool canSchedule;
  final bool canSend;
  final bool canReadConsent;

  @override
  State<_HubBody> createState() => _HubBodyState();
}

class _HubBodyState extends State<_HubBody> {
  late final MarketingCubit _cubit;
  bool _ownsCubit = false;

  @override
  void initState() {
    super.initState();
    final bloc = context.read<MarketingCubit>();
    _cubit = bloc;
    _ownsCubit = _cubit.state.status == MarketingLoadStatus.initial;
    if (_ownsCubit) {
      _cubit.load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MarketingCubit, MarketingState>(
      builder: (context, state) {
        if (state.status == MarketingLoadStatus.loading) {
          return const AdminLoadingView();
        }
        if (state.status == MarketingLoadStatus.failure) {
          return AdminFailureView(
            message: _unavailableMessage(state.error),
            onRetry: _cubit.refresh,
          );
        }
        return DefaultTabController(
          length: 7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Expanded(child: AdminPageTitle(S.marketingHub)),
                    if (widget.canCreate)
                      AdminCreateButton(
                        label: S.marketingNewCampaign,
                        onPressed: () =>
                            showCampaignCreateDialog(context, _cubit),
                      ),
                  ],
                ),
              ),
              TabBar(
                isScrollable: true,
                tabs: [
                  Tab(text: S.marketingOverview),
                  Tab(text: S.marketingCampaigns),
                  Tab(text: S.marketingAudience),
                  Tab(text: S.marketingConsent),
                  Tab(text: S.marketingDelivery),
                  Tab(text: S.marketingTemplates),
                  Tab(text: S.marketingTools),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _OverviewTab(state: state),
                    _CampaignsTab(state: state, cubit: _cubit, widget: widget),
                    _AudienceTab(cubit: _cubit),
                    _ConsentTab(
                      state: state,
                      cubit: _cubit,
                      canRead: widget.canReadConsent,
                    ),
                    _DeliveryTab(state: state, cubit: _cubit, widget: widget),
                    const _TemplatesTab(),
                    const _ToolsTab(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _unavailableMessage(String? error) {
    if (error != null && error.contains('PGRST202')) {
      return 'Marketing backend is not applied yet (RPC missing). '
          'Apply the approved migrations to enable this section.';
    }
    return error ?? 'Failed to load marketing data.';
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.state});
  final MarketingState state;

  @override
  Widget build(BuildContext context) {
    final o = state.overview;
    if (state.campaigns.isEmpty) {
      return AdminEmptyState(
        icon: AppIcons.promotion,
        message: S.marketingNoCampaigns,
        hint: S.marketingHintFirstCampaign,
      );
    }
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            AdminMetricCard(
              label: S.marketingTotalCampaigns,
              value: '${o.totalCampaigns}',
              icon: AppIcons.promotion,
              iconBackground: Colors.indigo.shade100,
              iconColor: Colors.indigo,
            ),
            AdminMetricCard(
              label: S.marketingActive,
              value: '${o.activeCampaigns}',
              icon: AppIcons.play,
              iconBackground: Colors.green.shade100,
              iconColor: Colors.green,
            ),
            AdminMetricCard(
              label: S.marketingScheduled,
              value: '${o.scheduledCampaigns}',
              icon: AppIcons.clock01,
              iconBackground: Colors.orange.shade100,
              iconColor: Colors.orange,
            ),
            AdminMetricCard(
              label: S.marketingCompleted,
              value: '${o.completedCampaigns}',
              icon: AppIcons.checkmarkCircle01,
              iconBackground: Colors.teal.shade100,
              iconColor: Colors.teal,
            ),
            AdminMetricCard(
              label: S.marketingRecipients,
              value: '${o.totalRecipients}',
              icon: AppIcons.userGroup,
              iconBackground: Colors.blue.shade100,
              iconColor: Colors.blue,
            ),
            AdminMetricCard(
              label: S.marketingSent,
              value: '${o.totalSent}',
              icon: AppIcons.notification01,
              iconBackground: Colors.purple.shade100,
              iconColor: Colors.purple,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        const Text(
          'Recent activity',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: AppSpacing.sm),
        ...o.recent.map(
          (c) => ListTile(
            title: Text(c.name),
            subtitle: Text('${c.channel} • ${c.purpose}'),
            trailing: _statusBadge(c.status),
          ),
        ),
      ],
    );
  }
}

class _CampaignsTab extends StatelessWidget {
  const _CampaignsTab({
    required this.state,
    required this.cubit,
    required this.widget,
  });
  final MarketingState state;
  final MarketingCubit cubit;
  final _HubBody widget;

  @override
  Widget build(BuildContext context) {
    if (state.campaigns.isEmpty) {
      return AdminEmptyState(
        icon: AppIcons.promotion,
        message: S.marketingNoCampaigns,
        hint: S.marketingHintDraft,
        action: widget.canCreate
            ? AdminCreateButton(
                label: S.marketingNewCampaign,
                onPressed: () => showCampaignCreateDialog(context, cubit),
              )
            : null,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: state.campaigns.length,
      itemBuilder: (context, i) {
        final c = state.campaigns[i];
        return Card(
          child: ListTile(
            title: Text(c.name),
            subtitle: Text(
              '${c.channel} • ${c.purpose} • recipients: ${c.recipientTotal}',
            ),
            trailing: _statusBadge(c.status),
            onTap: () => showCampaignDetailSheet(context, cubit, c, widget),
          ),
        );
      },
    );
  }
}

class _AudienceTab extends StatelessWidget {
  const _AudienceTab({required this.cubit});
  final MarketingCubit cubit;

  @override
  Widget build(BuildContext context) {
    // Audience preview is captured at schedule time (frozen snapshot).
    // Until scheduling runs, we show the campaign list context.
    return BlocBuilder<MarketingCubit, MarketingState>(
      bloc: cubit,
      builder: (context, state) {
        final eligible = state.campaigns
            .where(
              (c) =>
                  c.status == MarketingCampaignStatus.scheduled ||
                  c.status == MarketingCampaignStatus.processing,
            )
            .length;
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            const Text(
              'Audience snapshots are frozen when a campaign is scheduled. '
              'Eligibility (consent + channel reachability) is captured per recipient '
              'and re-checked by the worker before every send.',
            ),
            const SizedBox(height: AppSpacing.md),
            AdminMetricCard(
              label: 'Scheduled / processing campaigns',
              value: '$eligible',
              icon: AppIcons.userGroup,
              iconBackground: Colors.blue.shade100,
              iconColor: Colors.blue,
            ),
          ],
        );
      },
    );
  }
}

class _ConsentTab extends StatefulWidget {
  const _ConsentTab({
    required this.state,
    required this.cubit,
    required this.canRead,
  });
  final MarketingState state;
  final MarketingCubit cubit;
  final bool canRead;

  @override
  State<_ConsentTab> createState() => _ConsentTabState();
}

class _ConsentTabState extends State<_ConsentTab> {
  final TextEditingController _userController = TextEditingController();

  @override
  void dispose() {
    _userController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.canRead) {
      return AdminEmptyState(
        icon: AppIcons.shield01,
        message: S.marketingConsentRequired,
      );
    }
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        const Text(
          'Only consented customers can receive marketing messages. '
          'Missing consent means no send — consent is never inferred.',
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _userController,
          decoration: InputDecoration(labelText: S.marketingCustomerUserId),
        ),
        const SizedBox(height: AppSpacing.sm),
        CustomBtn(
          text: S.marketingLoadConsents,
          onPressed: () {
            final id = _userController.text.trim();
            if (id.isNotEmpty) widget.cubit.loadConsents(id);
          },
        ),
        const SizedBox(height: AppSpacing.md),
        ...widget.state.consents.map(
          (c) => ListTile(
            title: Text('${c.channel} • ${c.purpose}'),
            trailing: AdminStatusBadge(
              label: c.isGranted ? S.marketingGranted : S.marketingRevoked,
              color: c.isGranted ? Colors.green : Colors.red,
            ),
          ),
        ),
      ],
    );
  }
}

class _DeliveryTab extends StatelessWidget {
  const _DeliveryTab({
    required this.state,
    required this.cubit,
    required this.widget,
  });
  final MarketingState state;
  final MarketingCubit cubit;
  final _HubBody widget;

  @override
  Widget build(BuildContext context) {
    if (state.recipients.isEmpty && state.attempts.isEmpty) {
      return AdminEmptyState(
        icon: AppIcons.notification01,
        message: S.marketingNoDeliveryData,
        hint: S.marketingHintDelivery,
      );
    }
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Text(
          S.marketingDeliveryAttempts,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        ...state.attempts.map(
          (a) => ListTile(
            title: Text('${a.channel} • attempt ${a.attemptNumber}'),
            subtitle: Text(a.errorCode ?? a.providerStatus ?? a.status),
            trailing: AdminStatusBadge(label: a.status, color: Colors.grey),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const Text('Recipients', style: TextStyle(fontWeight: FontWeight.bold)),
        ...state.recipients.map(
          (r) => ListTile(
            title: Text(r.userId),
            subtitle: Text('${r.channel} • ${r.purpose}'),
            trailing: AdminStatusBadge(
              label: r.dispatchStatus,
              color: Colors.grey,
            ),
          ),
        ),
      ],
    );
  }
}

class _TemplatesTab extends StatelessWidget {
  const _TemplatesTab();

  @override
  Widget build(BuildContext context) {
    // Templates are the approved campaign version content; editing a version
    // creates a new draft. There is no separate template engine.
    return AdminEmptyState(
      icon: AppIcons.clipboard,
      message: S.marketingTemplatesNote,
      hint: S.marketingHintTemplate,
    );
  }
}

class _ToolsTab extends StatelessWidget {
  const _ToolsTab();

  @override
  Widget build(BuildContext context) {
    // Existing growth tools remain single source of truth — no duplicates.
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: const [
        Text(
          'Existing tools stay in their sections: Coupons, Banners, Loyalty, '
          'Email Design and Reviews. Nothing here duplicates those engines.',
        ),
      ],
    );
  }
}

Widget _statusBadge(MarketingCampaignStatus status) {
  final color = switch (status) {
    MarketingCampaignStatus.draft => Colors.grey,
    MarketingCampaignStatus.pendingReview => Colors.orange,
    MarketingCampaignStatus.approved => Colors.blue,
    MarketingCampaignStatus.scheduled => Colors.indigo,
    MarketingCampaignStatus.processing => Colors.purple,
    MarketingCampaignStatus.completed => Colors.green,
    MarketingCampaignStatus.failed => Colors.red,
    MarketingCampaignStatus.cancelled => Colors.brown,
    MarketingCampaignStatus.unknown => Colors.grey,
  };
  return AdminStatusBadge(label: status.name, color: color);
}
