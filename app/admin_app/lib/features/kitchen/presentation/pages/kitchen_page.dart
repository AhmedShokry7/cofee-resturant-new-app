import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/features/kitchen/domain/entities/admin_kitchen_ticket.dart';
import 'package:admin_app/features/kitchen/domain/repositories/kitchen_repository.dart';
import 'package:admin_app/features/kitchen/presentation/manager/admin_kitchen_cubit.dart';
import 'package:admin_app/features/kitchen/presentation/manager/admin_kitchen_state.dart';
import 'package:admin_app/features/kitchen/presentation/widgets/kitchen_format.dart';
import 'package:admin_app/features/kitchen/presentation/widgets/kitchen_page_body.dart';
import 'package:admin_app/core/search/admin_search_controller.dart';
import 'package:admin_app/shared/widgets/admin_state_view.dart';

class KitchenPage extends StatefulWidget {
  const KitchenPage({
    super.key,
    required this.searchController,
    this.cubit,
    this.canManage = false,
  });

  final AdminSearchController searchController;
  final AdminKitchenCubit? cubit;
  final bool canManage;

  @override
  State<KitchenPage> createState() => _KitchenPageState();
}

class _KitchenPageState extends State<KitchenPage> with WidgetsBindingObserver {
  late final AdminKitchenCubit _cubit;
  late final bool _ownsCubit;
  late final TextEditingController _searchText;
  Timer? _clockTimer;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _ownsCubit = widget.cubit == null;
    _cubit = widget.cubit ?? AdminKitchenCubit();
    _searchText = TextEditingController(text: _cubit.state.search);
    widget.searchController.bind(_onShellSearch);
    if (_ownsCubit) {
      WidgetsBinding.instance.addObserver(this);
      _cubit.load();
      _cubit.startLiveUpdates();
      _clockTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => _cubit.tick(),
      );
      // Realtime is the primary path; this is the safety net for a blocked
      // websocket or a project with realtime disabled.
      _pollTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => _cubit.refreshLive(),
      );
    }
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _pollTimer?.cancel();
    if (_ownsCubit) WidgetsBinding.instance.removeObserver(this);
    widget.searchController.bind(null);
    _searchText.dispose();
    if (_ownsCubit) _cubit.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _ownsCubit) {
      _cubit.tick();
      _cubit.refreshLive();
    }
  }

  void _onShellSearch(String query) {
    if (_searchText.text != query) {
      _searchText.value = TextEditingValue(
        text: query,
        selection: TextSelection.collapsed(offset: query.length),
      );
    }
    _cubit.updateSearch(query);
  }

  void _onToolbarSearch(String value) {
    _cubit.updateSearch(value);
    widget.searchController.update(value);
  }

  void _clearFilters() {
    _cubit.clearFilters();
    widget.searchController.clear();
    _searchText.clear();
  }

  Future<void> _setTicketStatus(
    AdminKitchenTicket ticket,
    KitchenTicketStatus status,
  ) async {
    final previous = ticket.status;
    final outcome = await _cubit.setTicketStatus(ticket.id, status);
    if (!mounted) return;
    if (outcome == KitchenMutationOutcome.success) {
      _showMessage(_successMessage(previous, status));
    } else {
      _showMessage(kitchenMutationErrorMessage(outcome), error: true);
    }
  }

  String _successMessage(
    KitchenTicketStatus previous,
    KitchenTicketStatus target,
  ) => switch (target) {
    KitchenTicketStatus.preparing =>
      previous == KitchenTicketStatus.queued
          ? S.kitchenTicketStarted
          : S.kitchenTicketRecalledMessage,
    KitchenTicketStatus.ready => S.kitchenTicketReadyMessage,
    KitchenTicketStatus.completed => S.kitchenTicketCompletedMessage,
    _ => S.kitchenTicketStarted,
  };

  Future<void> _toggleItem(AdminKitchenTicketItem item) async {
    final target = item.isReady
        ? KitchenItemStatus.pending
        : KitchenItemStatus.ready;
    final outcome = await _cubit.setItemStatus(item.id, target);
    if (!mounted) return;
    if (outcome != KitchenMutationOutcome.success) {
      _showMessage(kitchenMutationErrorMessage(outcome), error: true);
    }
  }

  void _showMessage(String message, {bool error = false}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? AppColor.errorColor : null,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AdminKitchenCubit>.value(
      value: _cubit,
      child: BlocBuilder<AdminKitchenCubit, AdminKitchenState>(
        builder: (context, state) {
          if (state.isLoading && !state.hasData) {
            return const AdminLoadingView();
          }
          if (state.isFailure) {
            return AdminFailureView(
              message: state.errorMessage,
              onRetry: _cubit.load,
            );
          }
          return KitchenPageBody(
            searchController: _searchText,
            tickets: state.tickets,
            filters: state.filters,
            metrics: state.metrics,
            now: state.now ?? DateTime.now(),
            branchId: state.branchId,
            isRefreshing: state.isRefreshing,
            lastUpdatedAt: state.lastUpdatedAt,
            busyTicketIds: state.busyTicketIds,
            busyItemIds: state.busyItemIds,
            hasActiveFilters: state.hasActiveFilters,
            canManage: widget.canManage,
            onSearchChanged: _onToolbarSearch,
            onBranchChanged: _cubit.setBranch,
            onClearFilters: _clearFilters,
            onRefresh: _cubit.refresh,
            onTicketStatus: _setTicketStatus,
            onToggleItem: _toggleItem,
            errorMessage: state.errorMessage,
          );
        },
      ),
    );
  }
}
