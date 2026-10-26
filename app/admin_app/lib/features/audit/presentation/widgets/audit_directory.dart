import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/features/audit/data/models/admin_audit_log.dart';
import 'package:admin_app/features/audit/presentation/models/audit_filters.dart';
import 'package:admin_app/features/audit/presentation/widgets/audit_cards.dart';
import 'package:admin_app/features/audit/presentation/widgets/audit_table.dart';
import 'package:admin_app/features/audit/presentation/widgets/audit_toolbar.dart';
import 'package:admin_app/shared/widgets/admin_directory_panel.dart';
import 'package:admin_app/shared/widgets/admin_empty_state.dart';
import 'package:admin_app/shared/widgets/admin_pagination.dart';

class AuditDirectory extends StatefulWidget {
  const AuditDirectory({
    super.key,
    required this.logs,
    required this.total,
    required this.page,
    required this.pages,
    required this.pageSize,
    required this.search,
    required this.domain,
    required this.criticalOnly,
    required this.isRefreshingRows,
    required this.onSearchChanged,
    required this.onDomainChanged,
    required this.onCriticalChanged,
    required this.onClearFilters,
    required this.onPageChanged,
    required this.onOpen,
  });

  final List<AdminAuditLog> logs;

  /// The server-side total across every page.
  final int total;
  final int page;
  final int pages;
  final int pageSize;
  final String search;
  final AuditDomainFilter domain;
  final bool criticalOnly;
  final bool isRefreshingRows;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<AuditDomainFilter> onDomainChanged;
  final ValueChanged<bool> onCriticalChanged;
  final VoidCallback onClearFilters;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<AdminAuditLog> onOpen;

  @override
  State<AuditDirectory> createState() => _AuditDirectoryState();
}

class _AuditDirectoryState extends State<AuditDirectory> {
  static const _cardsBreakpoint = 1120.0;

  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.search);
  }

  @override
  void didUpdateWidget(AuditDirectory oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.search != widget.search &&
        _searchController.text.trim() != widget.search) {
      _searchController.value = TextEditingValue(
        text: widget.search,
        selection: TextSelection.collapsed(offset: widget.search.length),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _hasActiveFilters =>
      widget.search.trim().isNotEmpty ||
      widget.domain != AuditDomainFilter.all ||
      widget.criticalOnly;

  void _clearAll() {
    _searchController.clear();
    widget.onClearFilters();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AdminDirectoryPanel(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuditToolbar(
            searchController: _searchController,
            onSearchChanged: widget.onSearchChanged,
            domain: widget.domain,
            onDomainChanged: widget.onDomainChanged,
            criticalOnly: widget.criticalOnly,
            onCriticalChanged: widget.onCriticalChanged,
            onClearFilters: widget.onClearFilters,
          ),
          const SizedBox(height: AppSizes.px10),
          SizedBox(
            height: AppSizes.px2,
            child: widget.isRefreshingRows
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                    child: LinearProgressIndicator(
                      minHeight: 2,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColor.adminAccent,
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(height: AppSizes.px10),
          Expanded(
            child: widget.total == 0
                ? _emptyState()
                : LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth < _cardsBreakpoint) {
                        return AuditCards(
                          logs: widget.logs,
                          onOpen: widget.onOpen,
                        );
                      }
                      return AuditTable(
                        logs: widget.logs,
                        onOpen: widget.onOpen,
                      );
                    },
                  ),
          ),
          if (widget.total > 0)
            AdminPagination(
              page: widget.page,
              pages: widget.pages,
              count: widget.total,
              pageSize: widget.pageSize,
              labelBuilder: S.auditRowsLabel,
              onChanged: widget.onPageChanged,
            ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return AdminEmptyState(
      icon: AppIcons.clipboard,
      message: _hasActiveFilters ? S.auditNoMatches : S.auditEmpty,
      hint: _hasActiveFilters ? null : S.auditEmptyHint,
      action: _hasActiveFilters
          ? TextButton(onPressed: _clearAll, child: Text(S.clearFilters))
          : null,
    );
  }
}
