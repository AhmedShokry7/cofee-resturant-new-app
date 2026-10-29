import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/search/admin_search_controller.dart';
import 'package:admin_app/features/staff/data/models/admin_staff.dart';
import 'package:admin_app/features/staff/presentation/manager/admin_staff_cubit.dart';
import 'package:admin_app/features/staff/presentation/manager/admin_staff_state.dart';
import 'package:admin_app/features/staff/presentation/widgets/staff_edit_dialog.dart';
import 'package:admin_app/features/staff/presentation/widgets/staff_invite_dialog.dart';
import 'package:admin_app/features/staff/presentation/widgets/staff_invitations_dialog.dart';
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

  /// Opens the profile editor and only speaks when the account changed: the
  /// dialog itself reports every refusal it got from the database.
  Future<void> _editMember(
    BuildContext context,
    AdminStaffMember member,
  ) async {
    final changed = await showStaffEditDialog(
      context: context,
      cubit: _cubit,
      member: member,
    );
    if (changed != true || !context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(S.staffEdited)));
  }

  /// دعوة موظف جديد: الحوار يعرض الرمز ويحكي كل رفض من القاعدة، فلا تضيف
  /// الصفحة رسالة إلا حين كُتبت الدعوة فعلًا.
  Future<void> _invite() async {
    final invited = await showStaffInviteDialog(
      context: context,
      cubit: _cubit,
    );
    if (invited != true || !mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(S.staffInvited)));
  }

  Future<void> _showInvitations() async {
    final cancelled = await showStaffInvitationsDialog(
      context: context,
      cubit: _cubit,
      canManage: widget.canManagePermissions,
    );
    if (cancelled != true || !mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(S.staffInvitationCancelledDone)));
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
            onEdit: (member) => _editMember(context, member),
            onInvite: _invite,
            onShowInvitations: _showInvitations,
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
