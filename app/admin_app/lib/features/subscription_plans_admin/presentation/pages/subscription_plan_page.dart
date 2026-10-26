import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/core/search/admin_search_controller.dart';
import 'package:admin_app/features/subscription_plans_admin/domain/entities/admin_subscription_plan.dart';
import 'package:admin_app/features/subscription_plans_admin/domain/entities/admin_subscription_plan_metrics.dart';
import 'package:admin_app/features/subscription_plans_admin/presentation/manager/admin_subscription_plan_cubit.dart';
import 'package:admin_app/features/subscription_plans_admin/presentation/manager/admin_subscription_plan_state.dart';
import 'package:admin_app/features/subscription_plans_admin/presentation/widgets/subscription_plan_dialog.dart';
import 'package:admin_app/features/subscription_plans_admin/presentation/widgets/subscription_plan_page_body.dart';
import 'package:admin_app/shared/widgets/admin_state_view.dart';

class SubscriptionPlanPage extends StatefulWidget {
  const SubscriptionPlanPage({
    super.key,
    required this.searchController,
    this.cubit,
  });

  static const String routeName = '/subscriptionPlansAdmin';

  final AdminSearchController searchController;
  final AdminSubscriptionPlanCubit? cubit;

  @override
  State<SubscriptionPlanPage> createState() => _SubscriptionPlanPageState();
}

class _SubscriptionPlanPageState extends State<SubscriptionPlanPage> {
  late final AdminSubscriptionPlanCubit _cubit;
  late final bool _ownsCubit;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _ownsCubit = widget.cubit == null;
    _cubit = widget.cubit ?? AdminSubscriptionPlanCubit();
    if (_ownsCubit) _cubit.load();
    widget.searchController.bind(_onSearch);
  }

  @override
  void dispose() {
    widget.searchController.bind(null);
    if (_ownsCubit) _cubit.close();
    super.dispose();
  }

  void _onSearch(String query) {
    setState(() => _searchQuery = query.trim());
  }

  Future<void> _openDialog([AdminSubscriptionPlan? plan]) {
    return showSubscriptionPlanDialog(
      context: context,
      cubit: _cubit,
      plan: plan,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AdminSubscriptionPlanCubit>.value(
      value: _cubit,
      child:
          BlocBuilder<AdminSubscriptionPlanCubit, AdminSubscriptionPlanState>(
            builder: (context, state) {
              if (state.isLoading && !state.hasPlans) {
                return const AdminLoadingView();
              }
              if (state.status == AdminSubscriptionPlanStatus.failure &&
                  !state.hasPlans) {
                return AdminFailureView(
                  message: state.errorMessage,
                  onRetry: _cubit.load,
                );
              }
              return SubscriptionPlanPageBody(
                plans: state.plans,
                metrics: AdminSubscriptionPlanMetrics.from(state.plans),
                search: _searchQuery,
                onSearchChanged: widget.searchController.update,
                onAdd: _openDialog,
                onEdit: _openDialog,
                errorMessage:
                    state.status == AdminSubscriptionPlanStatus.failure
                    ? state.errorMessage
                    : null,
                onRefresh: _cubit.load,
              );
            },
          ),
    );
  }
}
