import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/features/roles/presentation/manager/admin_role_cubit.dart';
import 'package:admin_app/features/roles/presentation/manager/admin_role_state.dart';
import 'package:admin_app/features/roles/presentation/widgets/role_permissions_dialog.dart';
import 'package:admin_app/features/roles/presentation/widgets/role_page_body.dart';
import 'package:admin_app/features/shell/presentation/models/admin_search_controller.dart';
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
            canManage: widget.canManage,
            onManage: widget.canManage
                ? (role) => showRolePermissionsDialog(
                    context: context,
                    cubit: _cubit,
                    role: role,
                    canManage: widget.canManage,
                  )
                : (_) {},
          );
        },
      ),
    );
  }
}
