import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/core/search/admin_search_controller.dart';
import 'package:admin_app/features/staff/presentation/manager/admin_staff_cubit.dart';
import 'package:admin_app/features/staff/presentation/manager/admin_staff_state.dart';
import 'package:admin_app/features/staff/presentation/widgets/staff_permissions_dialog.dart';
import 'package:admin_app/features/staff/presentation/widgets/staff_page_body.dart';
import 'package:admin_app/shared/widgets/admin_state_view.dart';

class StaffPage extends StatefulWidget {
  const StaffPage({
    super.key,
    required this.searchController,
    this.canManagePermissions = false,
    this.cubit,
  });

  static const String routeName = '/staff';

  final AdminSearchController searchController;
  final bool canManagePermissions;
  final AdminStaffCubit? cubit;

  @override
  State<StaffPage> createState() => _StaffPageState();
}

class _StaffPageState extends State<StaffPage> {
  late final AdminStaffCubit _cubit;
  late final bool _ownsCubit;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _ownsCubit = widget.cubit == null;
    _cubit = widget.cubit ?? AdminStaffCubit();
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

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AdminStaffCubit>.value(
      value: _cubit,
      child: BlocBuilder<AdminStaffCubit, AdminStaffState>(
        builder: (context, state) {
          if (state.isLoading && !state.hasStaff) {
            return const AdminLoadingView();
          }
          if (state.status == AdminStaffStatus.failure && !state.hasStaff) {
            return AdminFailureView(
              message: state.errorMessage,
              onRetry: _cubit.load,
            );
          }
          return StaffPageBody(
            staff: state.staff,
            search: _searchQuery,
            onSearchChanged: widget.searchController.update,
            canManagePermissions: widget.canManagePermissions,
            onManage: (member) => showStaffPermissionsDialog(
              context: context,
              cubit: _cubit,
              member: member,
              canManage: widget.canManagePermissions,
            ),
            errorMessage: state.status == AdminStaffStatus.failure
                ? state.errorMessage
                : null,
            onRefresh: _cubit.load,
          );
        },
      ),
    );
  }
}
