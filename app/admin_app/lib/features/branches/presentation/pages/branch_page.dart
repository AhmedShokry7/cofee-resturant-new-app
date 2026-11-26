import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/models/admin_branch.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/features/branches/domain/entities/branch_mutation_outcome.dart';
import 'package:admin_app/features/branches/presentation/manager/admin_branch_cubit.dart';
import 'package:admin_app/features/branches/presentation/manager/admin_branch_state.dart';
import 'package:admin_app/features/branches/presentation/widgets/branch_data_dialog.dart';
import 'package:admin_app/features/branches/presentation/widgets/branch_delivery_settings_dialog.dart';
import 'package:admin_app/features/branches/presentation/widgets/branch_image_dialog.dart';
import 'package:admin_app/features/branches/presentation/widgets/branch_messages.dart';
import 'package:admin_app/features/branches/presentation/widgets/branch_page_actions.dart';
import 'package:admin_app/features/branches/presentation/widgets/branch_page_body.dart';
import 'package:admin_app/features/branches/presentation/widgets/branch_product_pricing_dialog.dart';
import 'package:admin_app/core/search/admin_search_controller.dart';
import 'package:admin_app/shared/widgets/admin_state_view.dart';
import 'package:admin_app/features/branches/presentation/widgets/pickup_schedule_dialog.dart';
import 'package:admin_app/features/branches/presentation/widgets/reservation_cancellation_policy_dialog.dart';

class BranchPage extends StatefulWidget {
  const BranchPage({
    super.key,
    required this.searchController,
    this.cubit,
    this.canManage = false,
    this.canManagePricing = false,
  });

  static const String routeName = '/branches';

  final AdminSearchController searchController;
  final AdminBranchCubit? cubit;
  final bool canManage;
  final bool canManagePricing;

  @override
  State<BranchPage> createState() => _BranchPageState();
}

class _BranchPageState extends State<BranchPage> {
  late final AdminBranchCubit _cubit;
  late final bool _ownsCubit;
  String _searchQuery = '';
  final Set<String> _pendingBranches = <String>{};

  @override
  void initState() {
    super.initState();
    _ownsCubit = widget.cubit == null;
    _cubit = widget.cubit ?? AdminBranchCubit();
    if (_ownsCubit) _cubit.load();
    widget.searchController.bind(_onSearch);
  }

  /// The shell keeps this page alive: when it is shown again it
  /// receives a fresh widget, so it rebinds the search of the shell
  /// here instead of on a remount that would refetch everything.
  @override
  void didUpdateWidget(BranchPage oldWidget) {
    super.didUpdateWidget(oldWidget);
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

  Future<void> _openEditor([AdminBranch? branch]) async {
    if (!widget.canManage) return;
    final saved = branch == null
        ? await showBranchCreateDialog(context: context, cubit: _cubit)
        : await showBranchEditDialog(
            context: context,
            cubit: _cubit,
            branch: branch,
          );
    if (saved != true || !mounted) return;
    _showMessage(branch == null ? S.branchCreated : S.branchUpdated);
  }

  Future<void> _changeImage(AdminBranch branch) async {
    if (!widget.canManage) return;
    final changed = await showBranchImageDialog(
      context: context,
      cubit: _cubit,
      branchId: branch.id,
      imageUrl: branch.imageUrl,
    );
    if (changed != true || !mounted) return;
    _showMessage(S.saved);
  }

  Future<void> _toggleActive(AdminBranch branch) async {
    if (!widget.canManage || _pendingBranches.contains(branch.id)) return;
    if (branch.isActive) {
      final confirmed = await confirmBranchDeactivation(context, branch);
      if (!confirmed || !mounted) return;
    }
    _pendingBranches.add(branch.id);
    try {
      final outcome = await _cubit.setActive(branch, !branch.isActive);
      if (!mounted) return;
      if (outcome == BranchMutationOutcome.success) {
        _showMessage(branch.isActive ? S.branchDeactivated : S.branchActivated);
      } else {
        _showMessage(branchMutationErrorMessage(outcome), error: true);
      }
    } finally {
      _pendingBranches.remove(branch.id);
    }
  }

  Future<void> _delete(AdminBranch branch) async {
    if (!widget.canManage || _pendingBranches.contains(branch.id)) return;
    final confirmed = await confirmBranchDeletion(context, branch);
    if (!confirmed || !mounted) return;
    _pendingBranches.add(branch.id);
    try {
      final outcome = await _cubit.deleteBranch(branch.id);
      if (!mounted) return;
      if (outcome == BranchMutationOutcome.success) {
        _showMessage(S.branchDeleted);
      } else {
        _showMessage(branchMutationErrorMessage(outcome), error: true);
      }
    } finally {
      _pendingBranches.remove(branch.id);
    }
  }

  void _manageDelivery(AdminBranch branch) {
    if (!widget.canManage) return;
    showBranchDeliverySettingsDialog(
      context: context,
      branch: branch,
      onEditBranch: () => _openEditor(branch),
    );
  }

  void _managePricing(AdminBranch branch) {
    if (!widget.canManagePricing) return;
    showBranchProductPricingDialog(context: context, branch: branch);
  }

  Future<void> _managePickupSchedules(List<AdminBranch> branches) async {
    if (!widget.canManage || branches.isEmpty) return;
    final branch = await showDialog<AdminBranch>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(S.pickupScheduleTitle),
        children: [
          for (final item in branches)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, item),
              child: Text(item.nameFor(AppLocale.instance.language)),
            ),
        ],
      ),
    );
    if (branch == null || !mounted) return;
    await showPickupScheduleDialog(context: context, branch: branch);
  }

  Future<void> _manageCancellationPolicy(List<AdminBranch> branches) async {
    if (!widget.canManage || branches.isEmpty) return;
    final branch = await showDialog<AdminBranch>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(S.reservationCancellationPolicy),
        children: [
          for (final item in branches)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, item),
              child: Text(item.nameFor(AppLocale.instance.language)),
            ),
        ],
      ),
    );
    if (branch == null || !mounted) return;
    await showReservationCancellationPolicyDialog(context: context, branch: branch);
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
    return BlocProvider<AdminBranchCubit>.value(
      value: _cubit,
      child: BlocBuilder<AdminBranchCubit, AdminBranchState>(
        builder: (context, state) {
          if (state.isLoading && !state.hasBranches) {
            return const AdminLoadingView();
          }
          if (state.status == AdminBranchStatus.failure && !state.hasBranches) {
            return AdminFailureView(
              message: state.errorMessage,
              onRetry: _cubit.load,
            );
          }
          return BranchPageBody(
            branches: state.branches,
            metrics: state.metrics,
            search: _searchQuery,
            onSearchChanged: widget.searchController.update,
            canManage: widget.canManage,
            canManagePricing: widget.canManagePricing,
            onAdd: _openEditor,
            onEdit: _openEditor,
            onChangeImage: _changeImage,
            onManageDelivery: _manageDelivery,
            onManagePricing: widget.canManagePricing ? _managePricing : null,
            onManagePickupSchedules: () => _managePickupSchedules(state.branches),
            onManageCancellationPolicy: () => _manageCancellationPolicy(state.branches),
            onToggleActive: _toggleActive,
            onDelete: _delete,
            errorMessage: state.errorMessage,
            onRefresh: _cubit.load,
          );
        },
      ),
    );
  }
}
