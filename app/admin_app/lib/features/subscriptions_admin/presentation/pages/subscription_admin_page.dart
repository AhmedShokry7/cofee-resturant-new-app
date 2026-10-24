import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/subscriptions_admin/presentation/manager/admin_subscription_cubit.dart';
import 'package:admin_app/features/subscriptions_admin/presentation/manager/admin_subscription_state.dart';
import 'package:admin_app/features/subscriptions_admin/presentation/widgets/subscription_records.dart';
import 'package:admin_app/features/shell/presentation/models/admin_search_controller.dart';
import 'package:admin_app/shared/widgets/admin_page_title.dart';
import 'package:admin_app/shared/widgets/admin_state_view.dart';

class SubscriptionAdminPage extends StatefulWidget {
  const SubscriptionAdminPage({
    super.key,
    required this.searchController,
    this.cubit,
  });

  static const String routeName = '/subscriptionsAdmin';

  final AdminSearchController searchController;
  final AdminSubscriptionCubit? cubit;

  @override
  State<SubscriptionAdminPage> createState() => _SubscriptionAdminPageState();
}

class _SubscriptionAdminPageState extends State<SubscriptionAdminPage> {
  late final AdminSubscriptionCubit _cubit;
  late final bool _ownsCubit;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _ownsCubit = widget.cubit == null;
    _cubit = widget.cubit ?? AdminSubscriptionCubit();
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
    setState(() => _searchQuery = query.trim().toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AdminSubscriptionCubit>.value(
      value: _cubit,
      child: BlocBuilder<AdminSubscriptionCubit, AdminSubscriptionState>(
        builder: (context, state) {
          if (state.isLoading && !state.hasSubscriptions) {
            return const AdminLoadingView();
          }
          if (state.status == AdminSubscriptionStatus.failure &&
              !state.hasSubscriptions) {
            return AdminFailureView(
              message: state.errorMessage,
              onRetry: _cubit.load,
            );
          }
          return Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.pageHorizontalPadding,
              vertical: AppDimensions.pageVerticalPadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AdminPageTitle(S.subscriptions),
                const SizedBox(height: AppDimensions.lg),
                Expanded(
                  child: SubscriptionRecords(
                    subscriptions: state.subscriptions,
                    search: _searchQuery,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
