import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/features/notifications/data/models/admin_notification.dart';
import 'package:admin_app/features/notifications/presentation/models/notification_filters.dart';
import 'package:admin_app/features/notifications/presentation/widgets/notification_actions_menu.dart';
import 'package:admin_app/features/notifications/presentation/widgets/notification_cards.dart';
import 'package:admin_app/features/notifications/presentation/widgets/notification_table.dart';
import 'package:admin_app/features/notifications/presentation/widgets/notification_toolbar.dart';
import 'package:admin_app/shared/widgets/admin_directory_panel.dart';
import 'package:admin_app/shared/widgets/admin_empty_state.dart';
import 'package:admin_app/shared/widgets/admin_pagination.dart';

class NotificationDirectory extends StatefulWidget {
  const NotificationDirectory({
    super.key,
    required this.notifications,
    required this.total,
    required this.page,
    required this.pages,
    required this.pageSize,
    required this.search,
    required this.type,
    required this.readFilter,
    required this.pushFilter,
    required this.isRefreshingRows,
    required this.canSend,
    required this.canManage,
    required this.onSearchChanged,
    required this.onTypeChanged,
    required this.onReadChanged,
    required this.onPushChanged,
    required this.onClearFilters,
    required this.onPageChanged,
    required this.onOpen,
    required this.onAction,
  });

  final List<AdminNotification> notifications;

  /// The server-side total across every page.
  final int total;
  final int page;
  final int pages;
  final int pageSize;
  final String search;
  final NotificationTypeFilter type;
  final NotificationReadFilter readFilter;
  final NotificationPushFilter pushFilter;
  final bool isRefreshingRows;
  final bool canSend;
  final bool canManage;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<NotificationTypeFilter> onTypeChanged;
  final ValueChanged<NotificationReadFilter> onReadChanged;
  final ValueChanged<NotificationPushFilter> onPushChanged;
  final VoidCallback onClearFilters;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<AdminNotification> onOpen;
  final void Function(AdminNotification notification, NotificationAction action)
  onAction;

  @override
  State<NotificationDirectory> createState() => _NotificationDirectoryState();
}

class _NotificationDirectoryState extends State<NotificationDirectory> {
  static const _cardsBreakpoint = 1120.0;

  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.search);
  }

  @override
  void didUpdateWidget(NotificationDirectory oldWidget) {
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
      widget.type != NotificationTypeFilter.all ||
      widget.readFilter != NotificationReadFilter.all ||
      widget.pushFilter != NotificationPushFilter.all;

  void _clearAll() {
    _searchController.clear();
    widget.onClearFilters();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AdminDirectoryPanel(
      padding: const EdgeInsets.symmetric(horizontal: 19, vertical: 17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NotificationToolbar(
            searchController: _searchController,
            onSearchChanged: widget.onSearchChanged,
            type: widget.type,
            onTypeChanged: widget.onTypeChanged,
            readFilter: widget.readFilter,
            onReadChanged: widget.onReadChanged,
            pushFilter: widget.pushFilter,
            onPushChanged: widget.onPushChanged,
            onClearFilters: widget.onClearFilters,
          ),
          const SizedBox(height: 9),
          SizedBox(
            height: 2,
            child: widget.isRefreshingRows
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(1),
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
          const SizedBox(height: 9),
          Expanded(
            child: widget.total == 0
                ? _emptyState()
                : LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth < _cardsBreakpoint) {
                        return NotificationCards(
                          notifications: widget.notifications,
                          canSend: widget.canSend,
                          canManage: widget.canManage,
                          onOpen: widget.onOpen,
                          onAction: widget.onAction,
                        );
                      }
                      return NotificationTable(
                        notifications: widget.notifications,
                        canSend: widget.canSend,
                        canManage: widget.canManage,
                        onOpen: widget.onOpen,
                        onAction: widget.onAction,
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
              labelBuilder: S.notificationsRowsLabel,
              onChanged: widget.onPageChanged,
            ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return AdminEmptyState(
      icon: HugeIcons.strokeRoundedNotification01,
      message: _hasActiveFilters
          ? S.notificationsNoMatches
          : S.notificationsEmpty,
      hint: _hasActiveFilters ? null : S.notificationsEmptyHint,
      action: _hasActiveFilters
          ? TextButton(onPressed: _clearAll, child: Text(S.clearFilters))
          : null,
    );
  }
}
