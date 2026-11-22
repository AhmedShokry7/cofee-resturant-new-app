import 'package:material_ui/material_ui.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/visual_editor/domain/visual_editor_models.dart';
import 'package:admin_app/features/visual_editor/presentation/manager/visual_editor_cubit.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/preview_display_controls.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/preview_panel.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/visual_editor_theme_tokens.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/visual_editor_toolbar.dart';

/// شريط الأدوات العلوي للاستوديو — صف أفقي واحد قابل للتمرير على كل العروض.
///
/// التوزيع: كتلة الهوية وحالة الحفظ، ثم قوائم الجهاز والصفحة، ثم وضع
/// التحرير/المعاينة، ثم مجموعة الإجراءات (تراجع/إعادة/تحديث/حفظ/سجل/هوية)،
/// وفي الطرف زر النشر الرئيسي.
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
  static const double _gap = 18.0;

  @override
  Widget build(BuildContext context) {
    final cubit = widget.cubit;
    final muted = VisualEditorTokens.textMuted(context);

    Widget action(
      String id,
      IconData icon,
      String label,
      VoidCallback? run, {
      bool accent = false,
    }) {
      final foreground = accent
          ? Colors.white
          : run == null
          ? VisualEditorTokens.textMuted(context).withValues(alpha: 0.55)
          : VisualEditorTokens.text(context);
      return SizedBox(
        key: ValueKey('studio-tool-$id'),
        child: TextButton.icon(
          onPressed: run,
          icon: Icon(icon, size: 15),
          label: Text(label, maxLines: 1, softWrap: false),
          style: TextButton.styleFrom(
            foregroundColor: foreground,
            backgroundColor: accent
                ? VisualEditorTokens.primaryOliveGreen
                : Colors.transparent,
            disabledForegroundColor: accent
                ? Colors.white.withValues(alpha: 0.8)
                : foreground,
            disabledBackgroundColor: accent
                ? VisualEditorTokens.primaryOliveGreen.withValues(alpha: 0.35)
                : Colors.transparent,
            textStyle: const TextStyle(
              fontSize: AppFontSizes.size11_5,
              fontWeight: AppFontWeights.medium,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            minimumSize: const Size(0, 34),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(VisualEditorTokens.radiusMd),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: Container(
        height: VisualEditorTokens.topBarHeight,
        decoration: BoxDecoration(
          color: VisualEditorTokens.surface(context),
          border: Border(
            bottom: BorderSide(color: VisualEditorTokens.border(context)),
          ),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.black.withValues(alpha: 0.3)
                  : const Color(0x0A22332B),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  key: const ValueKey('studio-toolbar-row'),
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ——— الهوية وحالة الحفظ ———
                    _BrandBlock(
                      key: const ValueKey('studio-tool-title'),
                      title: S.studioTitle,
                      dirty: widget.state.isDirty,
                    ),
                    const SizedBox(width: _gap),
                    const _ToolbarDivider(),
                    const SizedBox(width: _gap),
                    // ——— الجهاز ———
                    _menu<PreviewDevice>(
                      'device',
                      widget.device.icon,
                      widget.device.label,
                      widget.device,
                      widget.onDeviceChanged,
                      [
                        for (final d in PreviewDevice.values)
                          PopupMenuItem(
                            value: d,
                            child: Row(
                              children: [
                                Icon(d.icon, size: d.iconSize, color: muted),
                                const SizedBox(width: 10),
                                // التسمية مرنة حتى لا يفيض صف القائمة
                                // في القوائم الضيقة قرب حواف الشاشة.
                                Flexible(
                                  child: Text(
                                    d.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  '${d.width.round()}×${d.height.round()}',
                                  style: TextStyle(
                                    fontSize: AppFontSizes.size9_5,
                                    color: muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    // ——— الصفحة ———
                    _menu<String>(
                      'pages',
                      AppIcons.menu01,
                      EditorPages.findById(widget.pageId)?.label ??
                          widget.pageId,
                      widget.pageId,
                      widget.onPageChanged,
                      [
                        for (final p in EditorPages.pages)
                          PopupMenuItem(value: p.pageId, child: Text(p.label)),
                      ],
                    ),
                    const SizedBox(width: 10),
                    // ——— القوالب ———
                    _pill(
                      'templates',
                      AppIcons.folder01,
                      S.visualEditorTemplates,
                      () => showVisualEditorTemplates(context, cubit),
                    ),
                    const SizedBox(width: _gap),
                    const _ToolbarDivider(),
                    const SizedBox(width: _gap),
                    // ——— وضع التحرير/المعاينة ———
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
                        PopupMenuItem(value: false, child: Text(S.studioEdit)),
                      ],
                    ),
                    const SizedBox(width: _gap),
                    const _ToolbarDivider(),
                    const SizedBox(width: _gap),
                    // ——— لغة ومظهر معاينة تطبيق العميل ———
                    PreviewDisplayControls(state: widget.state, cubit: cubit),
                    const SizedBox(width: _gap),
                    const _ToolbarDivider(),
                    const SizedBox(width: _gap),
                    // ——— مجموعة الإجراءات ———
                    action(
                      'undo',
                      AppIcons.undo,
                      S.visualEditorUndo,
                      cubit.canUndo ? cubit.undo : null,
                    ),
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
                    const SizedBox(width: _gap),
                    // ——— النشر ———
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
    );
  }

  /// قائمة منسدلة على هيئة زرّ كبسولة.
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(VisualEditorTokens.radiusMd),
      ),
      child: Container(
        constraints: const BoxConstraints(minHeight: 32),
        padding: const EdgeInsetsDirectional.only(start: 10, end: 6),
        decoration: BoxDecoration(
          color: VisualEditorTokens.surfaceSecondary(context),
          borderRadius: BorderRadius.circular(VisualEditorTokens.radiusPill),
          border: Border.all(color: VisualEditorTokens.border(context)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: VisualEditorTokens.textMuted(context)),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 150),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: TextStyle(
                  fontSize: AppFontSizes.size11_5,
                  fontWeight: AppFontWeights.medium,
                  color: VisualEditorTokens.text(context),
                ),
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              AppIcons.arrowDown01,
              size: 14,
              color: VisualEditorTokens.textMuted(context),
            ),
          ],
        ),
      ),
    );
  }

  /// زر كبسولة بسيط (بدون قائمة) — يشترك في الشكل مع القوائم المنسدلة.
  Widget _pill(String id, IconData icon, String label, VoidCallback onTap) {
    return SizedBox(
      key: ValueKey('studio-tool-$id'),
      child: Tooltip(
        message: label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(VisualEditorTokens.radiusPill),
            child: Container(
              constraints: const BoxConstraints(minHeight: 32),
              padding: const EdgeInsetsDirectional.only(start: 10, end: 10),
              decoration: BoxDecoration(
                color: VisualEditorTokens.surfaceSecondary(context),
                borderRadius: BorderRadius.circular(
                  VisualEditorTokens.radiusPill,
                ),
                border: Border.all(color: VisualEditorTokens.border(context)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 15,
                    color: VisualEditorTokens.textMuted(context),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      fontSize: AppFontSizes.size11_5,
                      fontWeight: AppFontWeights.medium,
                      color: VisualEditorTokens.text(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// كتلة الهوية: شارة متدرّجة + عنوان الاستوديو + حالة الحفظ.
class _BrandBlock extends StatelessWidget {
  const _BrandBlock({super.key, required this.title, required this.dirty});

  final String title;
  final bool dirty;

  @override
  Widget build(BuildContext context) {
    final statusColor = dirty
        ? VisualEditorTokens.statusWarning
        : VisualEditorTokens.statusSuccess;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            gradient: VisualEditorTokens.primaryGradient,
            borderRadius: BorderRadius.circular(9),
            boxShadow: [
              BoxShadow(
                color: VisualEditorTokens.primaryOliveGreen.withValues(
                  alpha: 0.35,
                ),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(AppIcons.paintBrush, size: 15, color: Colors.white),
        ),
        const SizedBox(width: 9),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                fontSize: AppFontSizes.size12_5,
                fontWeight: AppFontWeights.bold,
                color: VisualEditorTokens.text(context),
                height: 1.2,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  dirty ? S.studioUnsaved : S.studioSaved,
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: AppFontSizes.size10,
                    fontWeight: AppFontWeights.medium,
                    color: dirty
                        ? VisualEditorTokens.statusWarning
                        : VisualEditorTokens.textMuted(context),
                    height: 1,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

/// فاصل رأسي ناعم بين مجموعات الشريط.
class _ToolbarDivider extends StatelessWidget {
  const _ToolbarDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 22,
      color: VisualEditorTokens.border(context),
    );
  }
}
