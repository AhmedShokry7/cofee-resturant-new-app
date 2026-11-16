import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/visual_editor/domain/preview_protocol.dart';
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
    required this.onReloadPreview,
  });

  final VisualEditorState state;
  final VisualEditorCubit cubit;
  final double zoom;
  final PreviewDevice device;
  final String? selectedPageId;
  final void Function(double) onZoom;
  final void Function(PreviewDevice) onDeviceChanged;
  final void Function(String) onPageChanged;

  /// إعادة تحميل المعاينة بيد الموظف — الإطار يعاد تحميله والطابور يحفظ
  /// آخر مستند حتى تعلن المعاينة الجديدة جاهزيتها.
  final VoidCallback onReloadPreview;

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
        EditorScreenSizeSelector(
          dark: dark,
          muted: muted,
          selected: device,
          onSelected: onDeviceChanged,
        ),
        EditorDivider(),

        // --- تحكم التكبير ---
        EditorZoomControls(
          zoom: zoom,
          dark: dark,
          muted: muted,
          onZoom: onZoom,
        ),
        EditorDivider(),

        // --- حالة الاتصال وإعادة التحميل ---
        // على غير الويب لا يوجد iframe: المعاينة الأصلية ترسم من الحالة نفسها
        // فهي حيّة دائمًا، ولا معنى لضوء «غير متصلة» كاذب.
        EditorConnectionStatus(
          connection: state.previewConnection,
          reason: state.previewStatusMessage,
          dark: dark,
        ),
        EditorIconBtn(
          icon: AppIcons.refresh,
          tooltip: 'إعادة تحميل المعاينة'
              '${state.previewStatusMessage == null ? '' : ' — ${state.previewStatusMessage}'}',
          onTap: onReloadPreview,
          dark: dark,
          muted: muted,
        ),
        EditorDivider(),

        // --- تراجع وإعادة ---
        EditorIconBtn(
          icon: AppIcons.undo,
          tooltip: S.visualEditorUndo,
          onTap: cubit.canUndo ? cubit.undo : null,
          dark: dark,
          muted: muted,
        ),
        EditorIconBtn(
          icon: AppIcons.redo,
          tooltip: S.visualEditorRedo,
          onTap: cubit.canRedo ? cubit.redo : null,
          dark: dark,
          muted: muted,
        ),
        EditorDivider(),

        // --- سجل الإصدارات ---
        EditorIconBtn(
          icon: AppIcons.time01,
          tooltip: S.visualEditorVersions,
          onTap: () => showVisualEditorVersions(context, cubit),
          dark: dark,
          muted: muted,
        ),
        EditorIconBtn(
          icon: AppIcons.folder01,
          tooltip: S.visualEditorTemplates,
          onTap: () => showVisualEditorTemplates(context, cubit),
          dark: dark,
          muted: muted,
        ),
        EditorIconBtn(
          icon: AppIcons.paintBrush,
          tooltip: S.visualEditorThemeStudio,
          onTap: () => showVisualEditorThemeStudio(context, cubit),
          dark: dark,
          muted: muted,
        ),
        EditorDivider(),

        // --- التخلص من المسودة ---
        EditorIconBtn(
          icon: AppIcons.delete02,
          tooltip: S.visualEditorDiscard,
          onTap: () => confirmVisualEditorDiscard(context, cubit),
          dark: dark,
          muted: muted,
        ),
        EditorDivider(),

        // --- حفظ ونشر ---
        EditorToolbarButton(
          icon: AppIcons.upload01,
          label: S.visualEditorSaveDraft,
          onTap: state.isDirty ? cubit.saveDraft : null,
          dark: dark,
        ),
        EditorToolbarButton(
          icon: AppIcons.sent,
          label: S.visualEditorPublish,
          onTap: () => confirmVisualEditorPublish(context, cubit),
          dark: dark,
          accent: true,
          accentColor: accent,
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ حوارات مشتركة

/// حوارات الأدوات مشتركة بين الشريط الأفقي (العرض الضيق) والعمود الجانبي
/// (العرض الواسع) — نفس الوظائف، لا نسخ للمنطق.

Future<void> confirmVisualEditorPublish(
  BuildContext context,
  VisualEditorCubit cubit,
) async {
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
Future<void> showVisualEditorVersions(
  BuildContext context,
  VisualEditorCubit cubit,
) async {
    final versions = await cubit.loadVersions();
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => _VersionsDialog(versions: versions, cubit: cubit),
    );
}

Future<void> showVisualEditorTemplates(
  BuildContext context,
  VisualEditorCubit cubit,
) => showDialog<void>(
  context: context,
  builder: (_) => TemplatesDialog(cubit: cubit),
);

Future<void> showVisualEditorThemeStudio(
  BuildContext context,
  VisualEditorCubit cubit,
) => showDialog<void>(
  context: context,
  builder: (_) => ThemeStudioDialog(initialTheme: cubit.theme, cubit: cubit),
);

/// التخلص من المسودة بتأكيد: يمسح صف المسودة فقط عبر الـ RPC، وما
/// يراه الزبون لا يُلمس.
Future<void> confirmVisualEditorDiscard(
  BuildContext context,
  VisualEditorCubit cubit,
) async {
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

class EditorScreenSizeSelector extends StatelessWidget {
  const EditorScreenSizeSelector({
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

class EditorZoomControls extends StatelessWidget {
  const EditorZoomControls({
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
        EditorIconBtn(
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
        EditorIconBtn(
          icon: AppIcons.zoomInArea,
          tooltip: S.visualEditorZoomIn,
          onTap: zoom < 2.0 ? () => onZoom(zoom + 0.1) : null,
          dark: dark,
          muted: muted,
        ),
        EditorIconBtn(
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

class EditorConnectionStatus extends StatelessWidget {
  const EditorConnectionStatus({
    required this.connection,
    this.reason,
    required this.dark,
  });

  final PreviewConnection connection;
  final String? reason;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (connection) {
      PreviewConnection.connected => (
        AppColor.trendPositive,
        S.visualEditorPreviewConnected,
      ),
      PreviewConnection.connecting => (
        AppColor.adminAccent,
        'جارٍ الاتصال بالمعاينة…',
      ),
      PreviewConnection.disconnected => (
        AppColor.trendNegative,
        'انقطع الاتصال بالمعاينة',
      ),
      PreviewConnection.error => (
        AppColor.errorColor,
        'خطأ في المعاينة',
      ),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Tooltip(
            message: reason ?? label,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: AppFontSizes.size11, color: color),
            ),
          ),
        ),
      ],
    );
  }
}

class EditorToolbarButton extends StatelessWidget {
  const EditorToolbarButton({
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

class EditorIconBtn extends StatelessWidget {
  const EditorIconBtn({
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

class EditorDivider extends StatelessWidget {
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
