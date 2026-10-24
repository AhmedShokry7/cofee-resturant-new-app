import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/audit/data/models/admin_audit_log.dart';
import 'package:admin_app/features/audit/presentation/manager/admin_audit_cubit.dart';
import 'package:admin_app/features/audit/presentation/manager/admin_audit_state.dart';
import 'package:admin_app/features/audit/presentation/widgets/audit_log_records.dart';
import 'package:admin_app/shared/widgets/admin_page_title.dart';
import 'package:admin_app/shared/widgets/admin_state_view.dart';
import 'package:admin_app/features/shell/presentation/models/admin_search_controller.dart';

class AuditLogPage extends StatefulWidget {
  const AuditLogPage({super.key, required this.searchController, this.cubit});

  static const String routeName = '/auditLog';

  final AdminSearchController searchController;
  final AdminAuditCubit? cubit;

  @override
  State<AuditLogPage> createState() => _AuditLogPageState();
}

class _AuditLogPageState extends State<AuditLogPage> {
  late final AdminAuditCubit _cubit;
  late final bool _ownsCubit;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _ownsCubit = widget.cubit == null;
    _cubit = widget.cubit ?? AdminAuditCubit();
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

  List<AdminAuditLog> _filtered(List<AdminAuditLog> logs) {
    if (_searchQuery.isEmpty) return logs;
    return logs
        .where((log) {
          return log.action.toLowerCase().contains(_searchQuery) ||
              log.entityType.toLowerCase().contains(_searchQuery) ||
              (log.actorName ?? '').toLowerCase().contains(_searchQuery);
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AdminAuditCubit>.value(
      value: _cubit,
      child: BlocBuilder<AdminAuditCubit, AdminAuditState>(
        builder: (context, state) {
          if (state.isLoading && !state.hasLogs) {
            return const AdminLoadingView();
          }
          if (state.status == AdminAuditStatus.failure && !state.hasLogs) {
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
                AdminPageTitle(S.auditLog),
                const SizedBox(height: AppDimensions.lg),
                Expanded(child: AuditLogRecords(logs: _filtered(state.logs))),
              ],
            ),
          );
        },
      ),
    );
  }
}
