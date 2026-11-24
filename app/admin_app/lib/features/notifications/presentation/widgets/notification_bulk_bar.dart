import 'package:material_ui/material_ui.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

class NotificationBulkBar extends StatelessWidget {
  const NotificationBulkBar({
    super.key,
    required this.selectedCount,
    required this.selectedAllMatching,
    required this.pageSelectedCount,
    required this.pageDeletableCount,
    required this.isBulkBusy,
    required this.onTogglePageSelection,
    required this.onSelectAllMatching,
    required this.onClearSelection,
    required this.onBulkDelete,
  });

  final int selectedCount;
  final bool selectedAllMatching;
  final int pageSelectedCount;
  final int pageDeletableCount;
  final bool isBulkBusy;
  final ValueChanged<bool> onTogglePageSelection;
  final VoidCallback onSelectAllMatching;
  final VoidCallback onClearSelection;
  final VoidCallback onBulkDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final busy = isBulkBusy;
    final pageAllSelected =
        pageDeletableCount > 0 && pageSelectedCount == pageDeletableCount;
    final pageIndeterminate =
        pageSelectedCount > 0 && !pageAllSelected;
    return Container(
      key: const Key('notification-bulk-bar'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: adminTintedSurfaceColor(theme),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: adminCardBorderColor(theme)),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: Checkbox(
              key: const Key('notification-select-page'),
              tristate: true,
              value: pageIndeterminate ? null : pageAllSelected,
              onChanged: busy
                  ? null
                  : (value) => onTogglePageSelection(
                        pageIndeterminate ? true : (value ?? false),
                      ),
            ),
          ),
          Text(
            S.notificationsSelectPage,
            style: TextStyle(
              color: adminBodyColor(theme),
              fontSize: AppFontSizes.size10,
              fontWeight: AppFontWeights.semiBold,
            ),
          ),
          if (!selectedAllMatching)
            TextButton(
              key: const Key('notification-select-all-matching'),
              onPressed: busy ? null : onSelectAllMatching,
              child: Text(S.notificationsSelectAllMatching),
            ),
          Text(
            selectedCount == 0
                ? S.notificationsBulkScopePage
                : selectedAllMatching
                ? '${S.notificationsBulkSelectedCount(selectedCount)} · ${S.notificationsBulkScopeAllMatching}'
                : S.notificationsBulkSelectedCount(selectedCount),
            style: TextStyle(
              color: adminMutedColor(theme),
              fontSize: AppFontSizes.size9_5,
            ),
          ),
          const SizedBox(width: AppSizes.px16),
          TextButton(
            key: const Key('notification-clear-selection'),
            onPressed: (busy || selectedCount == 0) ? null : onClearSelection,
            child: Text(S.notificationsClearSelection),
          ),
          FilledButton.icon(
            key: const Key('notification-bulk-delete'),
            onPressed: (busy || selectedCount == 0) ? null : onBulkDelete,
            style: FilledButton.styleFrom(
              backgroundColor: AppColor.errorColor,
              minimumSize: const Size(0, 38),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            icon: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const AppIcon(AppIcons.delete02, size: 16, color: Colors.white),
            label: Text(
              S.notificationsBulkDelete,
              style: const TextStyle(
                fontSize: AppFontSizes.size11,
                fontWeight: AppFontWeights.semiBold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<bool?> showNotificationBulkDeleteDialog(
  BuildContext context, {
  required int count,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) {
      final theme = Theme.of(context);
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Text(
          S.notificationsBulkDeleteTitle,
          style: TextStyle(
            fontSize: AppFontSizes.size15,
            fontWeight: AppFontWeights.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        content: Text(
          S.notificationsBulkDeleteMessage(count),
          style: const TextStyle(
            fontSize: AppFontSizes.size11_5,
            height: AppTextHeights.line1_6,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(S.cancel),
          ),
          FilledButton(
            key: const Key('notification-bulk-delete-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColor.errorColor,
              minimumSize: const Size(0, 38),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            child: Text(
              S.notificationsBulkDeleteConfirm,
              style: const TextStyle(
                fontSize: AppFontSizes.size11,
                fontWeight: AppFontWeights.semiBold,
              ),
            ),
          ),
        ],
      );
    },
  );
}
