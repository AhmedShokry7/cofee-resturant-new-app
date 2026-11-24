import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/features/roles/data/models/admin_role.dart';
import 'package:admin_app/features/roles/presentation/manager/admin_role_cubit.dart';
import 'package:admin_app/features/roles/presentation/manager/admin_role_state.dart';
import 'package:admin_app/features/roles/presentation/widgets/role_editor_dialog.dart';
import 'package:admin_app/features/roles/presentation/widgets/role_permissions_dialog.dart';
import 'package:admin_app/features/roles/presentation/widgets/role_page_body.dart';
import 'package:admin_app/core/search/admin_search_controller.dart';
import 'package:admin_app/shared/widgets/admin_state_view.dart';

class RolePage extends StatefulWidget {
  const RolePage({
    super.key,
    required this.searchController,
    this.canManage = false,
    this.cubit,
  });

  static const String routeName = '/roles';

  final AdminSearchController searchController;
  final bool canManage;
  final AdminRoleCubit? cubit;

  @override
  State<RolePage> createState() => _RolePageState();
}

class _RolePageState extends State<RolePage> {
  late final AdminRoleCubit _cubit;
  late final bool _ownsCubit;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _ownsCubit = widget.cubit == null;
    _cubit = widget.cubit ?? AdminRoleCubit();
    if (_ownsCubit) _cubit.load();
    widget.searchController.bind(_onSearch);
  }

  /// The shell keeps this page alive: when it is shown again it
  /// receives a fresh widget, so it rebinds the search of the shell
  /// here instead of on a remount that would refetch everything.
  @override
  void didUpdateWidget(RolePage oldWidget) {
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

  Future<void> _manageRole(BuildContext context, AdminRole role) async {
    // The owner role is implicit and informational, and a read-only admin may
    // only inspect. Every other role opens the editor that submits the whole
    // permission set atomically.
    if (!widget.canManage || role.isOwner) {
      await showRolePermissionsDialog(
        context: context,
        cubit: _cubit,
        role: role,
        canManage: false,
      );
      return;
    }
    await showRoleEditorDialog(context: context, cubit: _cubit, role: role);
  }

  Future<void> _createRole(BuildContext context) =>
      showRoleEditorDialog(context: context, cubit: _cubit);

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AdminRoleCubit>.value(
      value: _cubit,
      child: BlocBuilder<AdminRoleCubit, AdminRoleState>(
        builder: (context, state) {
          if (state.isLoading && !state.hasRoles) {
            return const AdminLoadingView();
          }
          if (state.status == AdminRoleStatus.failure && !state.hasRoles) {
            return AdminFailureView(
              message: state.errorMessage,
              onRetry: _cubit.load,
            );
          }
          return RolePageBody(
            roles: state.roles,
            search: _searchQuery,
            onSearchChanged: widget.searchController.update,
            onManage: (role) => _manageRole(context, role),
            onCreate: widget.canManage ? () => _createRole(context) : null,
            canManage: widget.canManage,
            errorMessage: state.status == AdminRoleStatus.failure
                ? state.errorMessage
                : null,
            onRefresh: _cubit.load,
          );
        },
      ),
    );
  }
}
