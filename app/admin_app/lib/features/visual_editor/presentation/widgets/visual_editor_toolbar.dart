import 'package:material_ui/material_ui.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/visual_editor/domain/preview_protocol.dart';
import 'package:admin_app/features/visual_editor/domain/visual_editor_models.dart';
import 'package:admin_app/features/visual_editor/data/visual_editor_repository.dart';
import 'package:admin_app/features/visual_editor/presentation/manager/visual_editor_cubit.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/preview_display_controls.dart';
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
    this.canPublish = true,
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
  final bool canPublish;
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
          tooltip:
              'إعادة تحميل المعاينة'
              '${state.previewStatusMessage == null ? '' : ' — ${state.previewStatusMessage}'}',
          onTap: onReloadPreview,
          dark: dark,
          muted: muted,
        ),
        PreviewDisplayControls(state: state, cubit: cubit),
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
          onTap: () =>
              showVisualEditorVersions(context, cubit, canPublish: canPublish),
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
          // ضغطة واحدة تبدأ النشر مباشرة؛ الخادم يتحقق من الصلاحية.
          onTap: !canPublish ? null : () => publishVisualEditor(context, cubit),
          dark: dark,
          accent: true,
          accentColor: accent,
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ حوارات مشتركة

/// حوار موحّد للنشر الفوري من الشريط الأفقي أو الشريط العلوي.
/// ضغطة الزر نفسها ترسل الطلب؛ وتظهر النتيجة في حوار واضح لا يختفي سريعًا.
Future<void> publishVisualEditor(
  BuildContext context,
  VisualEditorCubit cubit,
) async {
  final details = await showDialog<_PublishDetails>(
    context: context,
    builder: (_) => _PublishDetailsDialog(cubit: cubit),
  );
  if (details == null || !context.mounted) return;

  if (details.scope != PublishScope.wholeDocument && cubit.state.isDirty) {
    await cubit.saveDraft();
    if (!context.mounted || cubit.state.isDirty) return;
  }
  final publishing = cubit.publish(
    name: details.name,
    note: details.note,
    scope: details.scope,
  );
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Flexible(child: Text('Publishing customer app...')),
          ],
        ),
      ),
    ),
  );

  final version = await publishing;
  if (!context.mounted) return;
  Navigator.of(context, rootNavigator: true).pop();

  final succeeded = version != null;
  final message = succeeded
      ? '${S.visualEditorPublishSuccess}: ${version.name ?? details.name} '
            '(#${version.versionNumber})'
      : cubit.state.errorMessage ?? 'Could not publish the customer app.';
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(
        succeeded ? S.visualEditorPublishSuccess : S.visualEditorPublishFailed,
      ),
      content: SelectableText(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(S.close),
        ),
      ],
    ),
  );
}

class _PublishDetails {
  const _PublishDetails({
    required this.name,
    required this.note,
    required this.scope,
  });

  final String name;
  final String note;
  final PublishScope scope;
}

class _PublishDetailsDialog extends StatefulWidget {
  const _PublishDetailsDialog({required this.cubit});

  final VisualEditorCubit cubit;

  @override
  State<_PublishDetailsDialog> createState() => _PublishDetailsDialogState();
}

class _PublishDetailsDialogState extends State<_PublishDetailsDialog> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _note = TextEditingController();
  bool _showNameError = false;

  /// النطاق الافتراضي: المعاينة الكاملة عندما تنتظر القرار، وإلا
  /// الصفحة الحالية من آخر مسودة محفوظة.
  late PublishScope _scope = widget.cubit.hasWholePreviewDocument
      ? PublishScope.wholeDocument
      : PublishScope.currentPage;

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    super.dispose();
  }

  String _scopeLabel(PublishScope scope) => switch (scope) {
    PublishScope.currentPage => S.visualEditorPublishCurrentPage,
    PublishScope.allPages => S.visualEditorPublishAllPages,
    PublishScope.wholeDocument => S.visualEditorPublishWholePreview,
  };

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(S.visualEditorPublishTitle),
    content: SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(S.visualEditorPublishConfirm),
          const SizedBox(height: AppSpacing.md),
          // نطاق النشر: صفحة واحدة لا تلمس ما ينشر لغيرها، والنشر يعتمد
          // آخر مسودة محفوظة لا الحالة المفتوحة.
          ...PublishScope.values
              .where(
                (scope) =>
                    scope != PublishScope.wholeDocument ||
                    widget.cubit.hasWholePreviewDocument,
              )
              .map(
                (scope) => RadioListTile<PublishScope>(
                  value: scope,
                  groupValue: _scope,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    _scopeLabel(scope),
                    style: AppFonts.regular14(context),
                  ),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _scope = value);
                    }
                  },
                ),
              ),
          if (_scope == PublishScope.currentPage) ...[
            // اسم الصفحة صريح: «الصفحة الحالية» وحدها لا تقول أي صفحة، ومن
            // بدّل الصفحة بعد التحرير كان ينشر صفحة أخرى بلا أن يدري.
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                S.visualEditorPublishTarget(
                  EditorPages.findById(widget.cubit.previewPageId)?.label ??
                      widget.cubit.previewPageId,
                ),
                style: AppFonts.regular12(context),
              ),
            ),
            if (widget.cubit.currentPageHasUnsavedEdits)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  S.visualEditorSaveBeforePublish,
                  style: AppFonts.regular12(context)
                      .copyWith(color: AppColor.errorColor),
                ),
              ),
            if (widget.cubit.otherPagesWithUnsavedEdits.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  S.visualEditorPublishOtherPagesPending(
                    widget.cubit.otherPagesWithUnsavedEdits
                        .map(
                          (page) => EditorPages.findById(page)?.label ?? page,
                        )
                        .join('، '),
                  ),
                  style: AppFonts.regular12(context)
                      .copyWith(color: AppColor.errorColor),
                ),
              ),
          ],
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _name,
            autofocus: true,
            maxLength: 120,
            onChanged: (_) {
              if (_showNameError) setState(() => _showNameError = false);
            },
            decoration: InputDecoration(
              labelText: S.visualEditorVersionName,
              hintText: S.visualEditorVersionName,
              errorText: _showNameError
                  ? S.visualEditorVersionNameRequired
                  : null,
              counterText: '',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _note,
            maxLength: 500,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: S.visualEditorVersionNote,
              hintText: S.visualEditorVersionNoteHint,
              counterText: '',
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(S.cancel),
      ),
      FilledButton.icon(
        onPressed: () {
          final name = _name.text.trim();
          if (name.isEmpty) {
            setState(() => _showNameError = true);
            return;
          }
          Navigator.of(context).pop(
            _PublishDetails(name: name, note: _note.text.trim(), scope: _scope),
          );
        },
        icon: const Icon(Icons.publish_outlined),
        label: Text(S.visualEditorPublish),
      ),
    ],
  );
}

Future<void> showVisualEditorVersions(
  BuildContext context,
  VisualEditorCubit cubit, {
  bool canPublish = true,
}) async {
  final versions = await cubit.loadVersions();
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (ctx) => _VersionsDialog(
      versions: versions,
      cubit: cubit,
      canPublish: canPublish,
    ),
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
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(S.visualEditorDiscardDone)));
  }
}

class _VersionsDialog extends StatefulWidget {
  const _VersionsDialog({
    required this.versions,
    required this.cubit,
    required this.canPublish,
  });

  final List<PublishedVersionInfo> versions;
  final VisualEditorCubit cubit;
  final bool canPublish;

  @override
  State<_VersionsDialog> createState() => _VersionsDialogState();
}

class _VersionsDialogState extends State<_VersionsDialog> {
  late List<PublishedVersionInfo> _versions;
  final Map<String, TextEditingController> _names = {};
  final Map<String, TextEditingController> _notes = {};
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _versions = List.of(widget.versions);
    for (final version in _versions) {
      _names[version.id] = TextEditingController(
        text:
            version.name ??
            '${S.visualEditorVersionLabel} ${version.versionNumber}',
      );
      _notes[version.id] = TextEditingController(text: version.note ?? '');
    }
  }

  @override
  void dispose() {
    for (final controller in _names.values) {
      controller.dispose();
    }
    for (final controller in _notes.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AlertDialog(
      title: Text(S.visualEditorVersionsTitle),
      content: SizedBox(
        width: 620,
        height: 520,
        child: _versions.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  S.visualEditorNoVersions,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: dark
                        ? AppColor.darkTextSecondary
                        : AppColor.adminMuted,
                  ),
                ),
              )
            : ListView.builder(
                itemCount: _versions.length,
                itemBuilder: (context, index) {
                  final version = _versions[index];
                  final when = version.publishedAt;
                  final busy = _busy.contains(version.id);
                  return Card(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _names[version.id],
                                  maxLength: 120,
                                  decoration: InputDecoration(
                                    isDense: true,
                                    labelText: S.visualEditorVersionName,
                                    counterText: '',
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: widget.canPublish
                                    ? () => _preview(context, version)
                                    : null,
                                child: Text(S.visualEditorVersionPreview),
                              ),
                              IconButton(
                                tooltip: S.visualEditorDeleteVersion,
                                onPressed: widget.canPublish && !busy
                                    ? () => _delete(context, version)
                                    : null,
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                          Text(
                            '${when.year}-${when.month.toString().padLeft(2, '0')}-'
                            '${when.day.toString().padLeft(2, '0')} '
                            '${when.hour.toString().padLeft(2, '0')}:'
                            '${when.minute.toString().padLeft(2, '0')}',
                            style: TextStyle(fontSize: AppFontSizes.size11),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _notes[version.id],
                                  maxLength: 500,
                                  minLines: 1,
                                  maxLines: 2,
                                  decoration: InputDecoration(
                                    isDense: true,
                                    labelText: S.visualEditorVersionNote,
                                    hintText: S.visualEditorVersionNoteHint,
                                    counterText: '',
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              IconButton(
                                tooltip: S.save,
                                onPressed: busy
                                    ? null
                                    : () => _saveNote(version),
                                icon: busy
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.save_outlined),
                              ),
                            ],
                          ),
                        ],
                      ),
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

  Future<void> _preview(
    BuildContext context,
    PublishedVersionInfo version,
  ) async {
    final loaded = await widget.cubit.previewVersion(version.id);
    if (loaded && context.mounted) Navigator.of(context).pop();
  }

  Future<void> _saveNote(PublishedVersionInfo version) async {
    setState(() => _busy.add(version.id));
    try {
      await widget.cubit.updateVersionDetails(
        version.id,
        _names[version.id]!.text,
        _notes[version.id]!.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.visualEditorVersionDetailsSaved)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(S.visualEditorVersionNoteFailed)));
    } finally {
      if (mounted) setState(() => _busy.remove(version.id));
    }
  }

  Future<void> _delete(
    BuildContext context,
    PublishedVersionInfo version,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(S.visualEditorDeleteVersion),
        content: Text(S.visualEditorDeleteVersionConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(S.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(S.visualEditorDeleteVersion),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || !context.mounted) return;
    setState(() => _busy.add(version.id));
    try {
      await widget.cubit.deleteVersion(version.id);
      if (!mounted || !context.mounted) return;
      setState(() {
        _versions.removeWhere((item) => item.id == version.id);
        _names.remove(version.id)?.dispose();
        _notes.remove(version.id)?.dispose();
        _busy.remove(version.id);
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(S.visualEditorVersionDeleted)));
    } catch (_) {
      if (!mounted || !context.mounted) return;
      setState(() => _busy.remove(version.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.visualEditorVersionDeleteFailed)),
      );
    }
  }
}

class EditorScreenSizeSelector extends StatelessWidget {
  const EditorScreenSizeSelector({
    super.key,
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
                      ? (dark ? AppColor.secondaryColor : AppColor.adminAccent)
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
    super.key,
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
    super.key,
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
      PreviewConnection.error => (AppColor.errorColor, 'خطأ في المعاينة'),
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
    super.key,
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
    final disabledColor = dark
        ? AppColor.darkTextSecondary
        : AppColor.adminMuted;

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
    super.key,
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
  const EditorDivider({super.key});

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
