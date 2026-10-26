import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/notifications/presentation/models/notification_filters.dart';
import 'package:admin_app/features/notifications/presentation/widgets/notification_format.dart';
import 'package:admin_app/shared/widgets/admin_toolbar.dart';

class NotificationToolbar extends StatelessWidget {
  const NotificationToolbar({
    super.key,
    required this.searchController,
    required this.onSearchChanged,
    required this.type,
    required this.onTypeChanged,
    required this.readFilter,
    required this.onReadChanged,
    required this.pushFilter,
    required this.onPushChanged,
    required this.onClearFilters,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final NotificationTypeFilter type;
  final ValueChanged<NotificationTypeFilter> onTypeChanged;
  final NotificationReadFilter readFilter;
  final ValueChanged<NotificationReadFilter> onReadChanged;
  final NotificationPushFilter pushFilter;
  final ValueChanged<NotificationPushFilter> onPushChanged;
  final VoidCallback onClearFilters;

  bool get _hasActiveFilters =>
      type != NotificationTypeFilter.all ||
      readFilter != NotificationReadFilter.all ||
      pushFilter != NotificationPushFilter.all;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 780;
        final search = AdminSearchField(
          controller: searchController,
          onChanged: onSearchChanged,
          hintText: S.searchNotificationsHint,
        );
        final actions = Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _FilterMenu<NotificationTypeFilter>(
              tooltip: S.notificationsFilterType,
              icon: HugeIcons.strokeRoundedTag01,
              selected: type,
              active: type != NotificationTypeFilter.all,
              options: NotificationTypeFilter.values,
              labelBuilder: _typeLabel,
              onSelected: onTypeChanged,
              compact: compact,
            ),
            _FilterMenu<NotificationReadFilter>(
              tooltip: S.notificationsFilterRead,
              icon: HugeIcons.strokeRoundedEye,
              selected: readFilter,
              active: readFilter != NotificationReadFilter.all,
              options: NotificationReadFilter.values,
              labelBuilder: _readLabel,
              onSelected: onReadChanged,
              compact: compact,
            ),
            _FilterMenu<NotificationPushFilter>(
              tooltip: S.notificationsFilterPush,
              icon: HugeIcons.strokeRoundedSent,
              selected: pushFilter,
              active: pushFilter != NotificationPushFilter.all,
              options: NotificationPushFilter.values,
              labelBuilder: _pushLabel,
              onSelected: onPushChanged,
              compact: compact,
            ),
            if (_hasActiveFilters)
              IconButton(
                tooltip: S.clearFilters,
                onPressed: onClearFilters,
                style: IconButton.styleFrom(
                  fixedSize: const Size(32, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: EdgeInsets.zero,
                ),
                icon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedCancel01,
                  size: 18,
                  color: AppColor.adminMuted,
                ),
              ),
          ],
        );
        if (constraints.maxWidth < 660) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              search,
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: actions,
              ),
            ],
          );
        }
        return Row(
          children: [
            SizedBox(
              width: constraints.maxWidth >= 900 ? 320 : 240,
              child: search,
            ),
            const Spacer(),
            actions,
          ],
        );
      },
    );
  }

  String _typeLabel(NotificationTypeFilter filter) {
    final type = filter.value;
    return type == null
        ? S.notificationsFilterAllTypes
        : notificationTypeLabel(type);
  }

  String _readLabel(NotificationReadFilter filter) => switch (filter) {
    NotificationReadFilter.all => S.notificationsFilterAllRead,
    NotificationReadFilter.unread => S.notificationsFilterUnread,
    NotificationReadFilter.read => S.notificationsFilterReadOnly,
  };

  String _pushLabel(NotificationPushFilter filter) => switch (filter) {
    NotificationPushFilter.all => S.notificationsFilterAllPush,
    NotificationPushFilter.sent => S.notificationsFilterSent,
    NotificationPushFilter.failed => S.notificationsFilterFailed,
    NotificationPushFilter.skipped => S.notificationsFilterSkipped,
    NotificationPushFilter.none => S.notificationsFilterNoPush,
  };
}

class _FilterMenu<T> extends StatelessWidget {
  const _FilterMenu({
    required this.tooltip,
    required this.icon,
    required this.selected,
    required this.active,
    required this.options,
    required this.labelBuilder,
    required this.onSelected,
    required this.compact,
  });

  final String tooltip;
  final IconData icon;
  final T selected;
  final bool active;
  final List<T> options;
  final String Function(T option) labelBuilder;
  final ValueChanged<T> onSelected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      tooltip: tooltip,
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final option in options)
          PopupMenuItem<T>(
            value: option,
            child: Row(
              children: [
                SizedBox(
                  width: 18,
                  child: option == selected
                      ? const HugeIcon(
                          icon: HugeIcons.strokeRoundedTick01,
                          size: 15,
                          color: AppColor.adminAccent,
                        )
                      : null,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    labelBuilder(option),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: AppFontSizes.size12,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
      child: compact
          ? AdminToolbarIcon(icon: icon, active: active)
          : AdminToolbarSurface(
              label: labelBuilder(selected),
              icon: icon,
              active: active,
            ),
    );
  }
}
