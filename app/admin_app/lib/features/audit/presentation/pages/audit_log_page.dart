import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/features/audit/data/models/admin_audit_log.dart';
import 'package:admin_app/features/audit/presentation/manager/admin_audit_cubit.dart';
import 'package:admin_app/features/audit/presentation/manager/admin_audit_state.dart';
import 'package:admin_app/features/audit/presentation/widgets/audit_details_dialog.dart';
import 'package:admin_app/features/audit/presentation/widgets/audit_directory.dart';
import 'package:admin_app/features/audit/presentation/widgets/audit_page_body.dart';
import 'package:admin_app/core/search/admin_search_controller.dart';
import 'package:admin_app/shared/widgets/admin_state_view.dart';

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

  void _onSearch(String query) => _cubit.updateSearch(query);

  void _onDirectorySearch(String value) {
    _cubit.updateSearch(value);
    widget.searchController.update(value);
  }

  void _clearFilters() {
    _cubit.clearFilters();
    widget.searchController.clear();
  }

  Future<void> _refresh() => _cubit.refresh();

  Future<void> _openDetails(AdminAuditLog log) =>
      showAuditDetailsDialog(context: context, log: log);

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AdminAuditCubit>.value(
      value: _cubit,
      child: BlocBuilder<AdminAuditCubit, AdminAuditState>(
        builder: (context, state) {
          if (state.isLoading && !state.hasData) {
            return const AdminLoadingView();
          }
          if (state.isFailure && !state.hasData) {
            return AdminFailureView(
              message: state.errorMessage,
              onRetry: _cubit.load,
            );
          }
          return AuditPageBody(
            metrics: state.metrics,
            refreshing: state.isRefreshingRows,
            onRefresh: _refresh,
            errorMessage: state.isFailure ? state.errorMessage : null,
            directory: AuditDirectory(
              logs: state.logs,
              total: state.total,
              page: state.page,
              pages: state.pages,
              pageSize: state.pageSize,
              search: state.search,
              domain: state.domain,
              criticalOnly: state.criticalOnly,
              isRefreshingRows: state.isRefreshingRows,
              onSearchChanged: _onDirectorySearch,
              onDomainChanged: _cubit.setDomain,
              onCriticalChanged: _cubit.setCriticalOnly,
              onClearFilters: _clearFilters,
              onPageChanged: _cubit.setPage,
              onOpen: _openDetails,
            ),
          );
        },
      ),
    );
  }
}
