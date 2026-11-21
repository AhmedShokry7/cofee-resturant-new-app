import 'package:material_ui/material_ui.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/features/visual_editor/domain/visual_editor_models.dart';
import 'package:admin_app/features/visual_editor/presentation/manager/visual_editor_cubit.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/preview_panel.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/visual_editor_theme_tokens.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/visual_editor_toolbar.dart';

/// A single, horizontally scrollable row at every viewport width.
class StudioSingleRowToolbar extends StatefulWidget {
  const StudioSingleRowToolbar({
    super.key,
    required this.state,
    required this.cubit,
    required this.canPublish,
    required this.device,
    required this.pageId,
    required this.interactive,
    required this.onDeviceChanged,
    required this.onPageChanged,
    required this.onModeChanged,
    required this.onReloadPreview,
  });

  final VisualEditorState state;
  final VisualEditorCubit cubit;
  final bool canPublish;
  final PreviewDevice device;
  final String pageId;
  final bool interactive;
  final ValueChanged<PreviewDevice> onDeviceChanged;
  final ValueChanged<String> onPageChanged;
  final ValueChanged<bool> onModeChanged;
  final VoidCallback onReloadPreview;

  @override
  State<StudioSingleRowToolbar> createState() => _StudioSingleRowToolbarState();
}

class _StudioSingleRowToolbarState extends State<StudioSingleRowToolbar> {
  @override
  Widget build(BuildContext context) {
    final cubit = widget.cubit;
    Widget action(
      String id,
      IconData icon,
      String label,
      VoidCallback? run, {
      bool accent = false,
    }) => SizedBox(
      key: ValueKey('studio-tool-$id'),
      child: TextButton.icon(
        onPressed: run,
        icon: Icon(icon, size: AppDimensions.iconSizeSm),
        label: Text(label, maxLines: 1, softWrap: false),
        style: TextButton.styleFrom(
          foregroundColor: accent
              ? Colors.white
              : VisualEditorTokens.text(context),
          backgroundColor: accent ? VisualEditorTokens.primaryOliveGreen : null,
          textStyle: const TextStyle(fontSize: 12),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        ),
      ),
    );

    return SizedBox(
      width: double.infinity,
      child: Material(
        color: VisualEditorTokens.surface(context),
        child: SizedBox(
          height: VisualEditorTokens.topBarHeight,
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Row(
                    key: const ValueKey('studio-toolbar-row'),
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        key: const ValueKey('studio-tool-title'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            S.studioTitle,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            widget.state.isDirty
                                ? S.studioUnsaved
                                : S.studioSaved,
                            style: TextStyle(
                              fontSize: 11,
                              color: VisualEditorTokens.textMuted(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 24),
                      _menu<PreviewDevice>(
                        'device',
                        widget.device.icon,
                        widget.device.label,
                        widget.device,
                        widget.onDeviceChanged,
                        [
                          for (final d in PreviewDevice.values)
                            PopupMenuItem(value: d, child: Text(d.label)),
                        ],
                      ),
                      const SizedBox(width: 24),
                      _menu<String>(
                        'pages',
                        AppIcons.menu01,
                        EditorPages.findById(widget.pageId)?.label ??
                            widget.pageId,
                        widget.pageId,
                        widget.onPageChanged,
                        [
                          for (final p in EditorPages.pages)
                            PopupMenuItem(
                              value: p.pageId,
                              child: Text(p.label),
                            ),
                        ],
                      ),
                      const SizedBox(width: 24),
                      action(
                        'templates',
                        AppIcons.folder01,
                        S.visualEditorTemplates,
                        () => showVisualEditorTemplates(context, cubit),
                      ),
                      const SizedBox(width: 24),
                      _menu<bool>(
                        'mode',
                        widget.interactive ? AppIcons.eyeIcon : AppIcons.edit01,
                        widget.interactive ? S.studioPreview : S.studioEdit,
                        widget.interactive,
                        widget.onModeChanged,
                        [
                          PopupMenuItem(
                            value: true,
                            child: Text(S.studioPreview),
                          ),
                          PopupMenuItem(
                            value: false,
                            child: Text(S.studioEdit),
                          ),
                        ],
                      ),
                      const SizedBox(width: 24),
                      action(
                        'undo',
                        AppIcons.undo,
                        S.visualEditorUndo,
                        cubit.canUndo ? cubit.undo : null,
                      ),
                      const SizedBox(width: 24),
                      action(
                        'redo',
                        AppIcons.redo,
                        S.visualEditorRedo,
                        cubit.canRedo ? cubit.redo : null,
                      ),
                      action(
                        'reload',
                        AppIcons.refresh,
                        S.refresh,
                        widget.onReloadPreview,
                      ),
                      action(
                        'save',
                        AppIcons.upload01,
                        S.visualEditorSaveDraft,
                        widget.state.isDirty ? cubit.saveDraft : null,
                      ),
                      action(
                        'history',
                        AppIcons.time01,
                        S.visualEditorVersions,
                        () => showVisualEditorVersions(
                          context,
                          cubit,
                          canPublish: widget.canPublish,
                        ),
                      ),
                      action(
                        'identity',
                        AppIcons.paintBrush,
                        S.studioIdentity,
                        () => showVisualEditorThemeStudio(context, cubit),
                      ),
                      const SizedBox(width: 24),
                      action(
                        'publish',
                        AppIcons.sent,
                        S.visualEditorPublish,
                        widget.canPublish
                            ? () => publishVisualEditor(context, cubit)
                            : null,
                        accent: true,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _menu<T>(
    String id,
    IconData icon,
    String label,
    T value,
    ValueChanged<T> onSelected,
    List<PopupMenuEntry<T>> items,
  ) {
    return PopupMenuButton<T>(
      key: ValueKey('studio-tool-$id'),
      tooltip: label,
      initialValue: value,
      onSelected: onSelected,
      itemBuilder: (_) => items,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: AppDimensions.iconSizeSm),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              maxLines: 1,
              softWrap: false,
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(width: AppSpacing.xs),
            const Icon(AppIcons.arrowDown01, size: AppDimensions.iconSizeSm),
          ],
        ),
      ),
    );
  }
}
