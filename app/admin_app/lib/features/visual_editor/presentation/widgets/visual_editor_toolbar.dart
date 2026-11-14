import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/visual_editor/data/visual_editor_repository.dart';
import 'package:admin_app/features/visual_editor/presentation/manager/visual_editor_cubit.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/preview_panel.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/templates_dialog.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/theme_studio_dialog.dart';

/// شريط أدوات المحرر المرئي.
///
/// يحتوي على التكبير/التصغير، واختيار حجم الشاشة، وأزرار المسودة والنشر.
class VisualEditorToolbar extends StatelessWidget {
  const VisualEditorToolbar({
    super.key,
    required this.state,
    required this.cubit,
    required this.zoom,
    required this.device,
    required this.selectedPageId,
    required this.onZoom,
    required this.onDeviceChanged,
    required this.onPageChanged,
  });

  final VisualEditorState state;
  final VisualEditorCubit cubit;
  final double zoom;
  final PreviewDevice device;
  final String? selectedPageId;
  final void Function(double) onZoom;
  final void Function(PreviewDevice) onDeviceChanged;
  final void Function(String) onPageChanged;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark ? AppColor.darkTextSecondary : AppColor.adminMuted;
    final accent = dark ? AppColor.secondaryColor : AppColor.adminAccent;

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // --- حجم الشاشة ---
        _ScreenSizeSelector(
          dark: dark,
          muted: muted,
          selected: device,
          onSelected: onDeviceChanged,
        ),
        _Divider(),

        // --- تحكم التكبير ---
        _ZoomControls(
          zoom: zoom,
          dark: dark,
          muted: muted,
          onZoom: onZoom,
        ),
        _Divider(),

        // --- حالة الاتصال ---
        _ConnectionStatus(previewReady: state.previewReady, dark: dark),
        _Divider(),

        // --- تراجع وإعادة ---
        _IconBtn(
          icon: AppIcons.undo,
          tooltip: S.visualEditorUndo,
          onTap: cubit.canUndo ? cubit.undo : null,
          dark: dark,
          muted: muted,
        ),
        _IconBtn(
          icon: AppIcons.redo,
          tooltip: S.visualEditorRedo,
          onTap: cubit.canRedo ? cubit.redo : null,
          dark: dark,
          muted: muted,
        ),
        _Divider(),

        // --- سجل الإصدارات ---
        _IconBtn(
          icon: AppIcons.time01,
          tooltip: S.visualEditorVersions,
          onTap: () => _showVersions(context),
          dark: dark,
          muted: muted,
        ),
        _IconBtn(
          icon: AppIcons.folder01,
          tooltip: S.visualEditorTemplates,
          onTap: () => _showTemplates(context),
          dark: dark,
          muted: muted,
        ),
        _IconBtn(
          icon: AppIcons.paintBrush,
          tooltip: S.visualEditorThemeStudio,
          onTap: () => _showThemeStudio(context),
          dark: dark,
          muted: muted,
        ),
        _Divider(),

        // --- التخلص من المسودة ---
        _IconBtn(
          icon: AppIcons.delete02,
          tooltip: S.visualEditorDiscard,
          onTap: () => _confirmDiscard(context),
          dark: dark,
          muted: muted,
        ),
        _Divider(),

        // --- حفظ ونشر ---
        _ToolbarButton(
          icon: AppIcons.upload01,
          label: S.visualEditorSaveDraft,
          onTap: state.isDirty ? cubit.saveDraft : null,
          dark: dark,
        ),
        _ToolbarButton(
          icon: AppIcons.sent,
          label: S.visualEditorPublish,
          onTap: () => _confirmPublish(context),
          dark: dark,
          accent: true,
          accentColor: accent,
        ),
      ],
    );
  }

  Future<void> _confirmPublish(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.visualEditorPublishTitle),
        content: Text(S.visualEditorPublishConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(S.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(S.visualEditorPublish),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final version = await cubit.publish();
      if (version != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم النشر كإصدار ${version.versionNumber}')),
        );
      }
    }
  }

  /// سجل الإصدارات: قائمة بأرقام الإصدارات وأوقاتها مع استرجاع.
  Future<void> _showVersions(BuildContext context) async {
    final versions = await cubit.loadVersions();
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => _VersionsDialog(versions: versions, cubit: cubit),
    );
  }

  Future<void> _showTemplates(BuildContext context) => showDialog<void>(
    context: context,
    builder: (_) => const TemplatesDialog(),
  );

  Future<void> _showThemeStudio(BuildContext context) => showDialog<void>(
    context: context,
    builder: (_) => ThemeStudioDialog(initialTheme: cubit.theme),
  );

  /// التخلص من المسودة بتأكيد: يمسح صف المسودة فقط عبر الـ RPC، وما
  /// يراه الزبون لا يُلمس.
  Future<void> _confirmDiscard(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.visualEditorDiscardTitle),
        content: Text(S.visualEditorDiscardConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(S.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(S.visualEditorDiscard),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await cubit.discardDraft();
    if (ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.visualEditorDiscardDone)),
      );
    }
  }
}

class _VersionsDialog extends StatelessWidget {
  const _VersionsDialog({required this.versions, required this.cubit});

  final List<PublishedVersionInfo> versions;
  final VisualEditorCubit cubit;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AlertDialog(
      title: Text(S.visualEditorVersionsTitle),
      content: SizedBox(
        width: 420,
        child: versions.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  S.visualEditorNoVersions,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: dark ? AppColor.darkTextSecondary : AppColor.adminMuted,
                  ),
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                itemCount: versions.length,
                itemBuilder: (context, index) {
                  final version = versions[index];
                  final when = version.publishedAt;
                  return ListTile(
                    dense: true,
                    title: Text(
                      'الإصدار ${version.versionNumber}'
                      '${version.note == null ? '' : ' — ${version.note}'}',
                      style: TextStyle(
                        fontSize: AppFontSizes.size13,
                        color: dark ? AppColor.darkText : AppColor.adminBody,
                      ),
                    ),
                    subtitle: Text(
                      '${when.year}-${when.month.toString().padLeft(2, '0')}-'
                      '${when.day.toString().padLeft(2, '0')} '
                      '${when.hour.toString().padLeft(2, '0')}:'
                      '${when.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(fontSize: AppFontSizes.size11),
                    ),
                    trailing: TextButton(
                      onPressed: () => _restore(context, version),
                      child: Text(S.visualEditorRestore),
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(S.close),
        ),
      ],
    );
  }

  Future<void> _restore(BuildContext context, PublishedVersionInfo version) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.visualEditorRestoreTitle),
        content: Text(S.visualEditorRestoreConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(S.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(S.visualEditorRestore),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final restored = await cubit.restoreVersion(version.id);
    if (restored != null && context.mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('استُرجع كإصدار ${restored.versionNumber}'),
        ),
      );
    }
  }
}

class _ScreenSizeSelector extends StatelessWidget {
  const _ScreenSizeSelector({
    required this.dark,
    required this.muted,
    required this.selected,
    required this.onSelected,
  });

  final bool dark;
  final Color muted;
  final PreviewDevice selected;
  final void Function(PreviewDevice) onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final device in PreviewDevice.values)
          Tooltip(
            message: device.label,
            child: InkWell(
              onTap: () => onSelected(device),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: selected == device
                      ? (dark
                          ? AppColor.darkSurfaceContainer
                          : AppColor.adminAccentSurface)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(
                  device.icon,
                  size: AppDimensions.iconSizeSm,
                  color: selected == device
                      ? (dark
                          ? AppColor.secondaryColor
                          : AppColor.adminAccent)
                      : muted,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ZoomControls extends StatelessWidget {
  const _ZoomControls({
    required this.zoom,
    required this.dark,
    required this.muted,
    required this.onZoom,
  });

  final double zoom;
  final bool dark;
  final Color muted;
  final void Function(double) onZoom;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _IconBtn(
          icon: AppIcons.zoomOutArea,
          tooltip: S.visualEditorZoomOut,
          onTap: zoom > 0.5 ? () => onZoom(zoom - 0.1) : null,
          dark: dark,
          muted: muted,
        ),
        SizedBox(
          width: 42,
          child: Text(
            '${(zoom * 100).round()}%',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppFontSizes.size11,
              fontWeight: AppFontWeights.medium,
              color: dark ? AppColor.darkText : AppColor.adminBody,
            ),
          ),
        ),
        _IconBtn(
          icon: AppIcons.zoomInArea,
          tooltip: S.visualEditorZoomIn,
          onTap: zoom < 2.0 ? () => onZoom(zoom + 0.1) : null,
          dark: dark,
          muted: muted,
        ),
        _IconBtn(
          icon: AppIcons.refresh,
          tooltip: S.visualEditorZoomReset,
          onTap: () => onZoom(1.0),
          dark: dark,
          muted: muted,
        ),
      ],
    );
  }
}

class _ConnectionStatus extends StatelessWidget {
  const _ConnectionStatus({required this.previewReady, required this.dark});

  final bool previewReady;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final color = previewReady
        ? AppColor.trendPositive
        : (dark ? AppColor.darkTextSecondary : AppColor.adminMuted);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          previewReady
              ? S.visualEditorPreviewConnected
              : S.visualEditorPreviewDisconnected,
          style: TextStyle(fontSize: AppFontSizes.size11, color: color),
        ),
      ],
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.dark,
    this.accent = false,
    this.accentColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool dark;
  final bool accent;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final fg = accent
        ? (dark ? AppColor.darkText : AppColor.whiteColor)
        : (dark ? AppColor.darkText : AppColor.adminBody);
    final bg = accent
        ? (accentColor ?? AppColor.adminAccent)
        : Colors.transparent;
    final disabledColor =
        dark ? AppColor.darkTextSecondary : AppColor.adminMuted;

    return Material(
      color: disabled ? Colors.transparent : bg,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: AppDimensions.iconSizeSm,
                color: disabled ? disabledColor : fg,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                label,
                style: TextStyle(
                  fontSize: AppFontSizes.size12,
                  fontWeight: AppFontWeights.medium,
                  color: disabled ? disabledColor : fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.dark,
    required this.muted,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool dark;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xs),
          child: Icon(
            icon,
            size: AppDimensions.iconSizeSm,
            color: onTap == null ? muted.withAlpha(100) : muted,
          ),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: AppSizes.px16,
      child: VerticalDivider(
        width: 1,
        thickness: 1,
        color: dark ? AppColor.darkBorder : AppColor.adminControlBorder,
      ),
    );
  }
}
