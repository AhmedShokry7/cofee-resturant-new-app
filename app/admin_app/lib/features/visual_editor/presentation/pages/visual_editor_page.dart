import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/features/visual_editor/data/visual_editor_image_asset_repository.dart';
import 'package:admin_app/features/visual_editor/domain/component_registry.dart';
import 'package:admin_app/features/visual_editor/domain/visual_editor_models.dart';
import 'package:admin_app/features/visual_editor/presentation/manager/visual_editor_cubit.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/component_library_panel.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/component_tree_panel.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/preview_panel.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/properties_inspector_panel.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/visual_editor_image_asset_picker.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/visual_editor_theme_tokens.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/visual_editor_toolbar.dart';
import 'package:admin_app/shared/widgets/admin_empty_state.dart';
import 'package:admin_app/shared/widgets/admin_state_view.dart';

/// صفحة المحرر المرئي المطورة — واجهة احترافية بمستوى أدوات بناء التطبيقات الحديثة (Visual App Builders).
///
/// تم ترقية وتطوير الواجهة بالكامل وفق هوية تطبيق القهوة الراقية:
/// - خلفيات دافئة وهادئة: Warm Off-White
/// - أسطح وبطاقات: Soft Cream
/// - اللون الأساسي: Deep Olive Green
/// - اللون الثانوي: Coffee Brown
/// - نصوص متناسقة: Dark Charcoal و Muted Gray
/// - حدود ناعمة: Soft Warm Gray
///
/// مع هيكل متوازن:
/// 1. لوحة العمل والصفحات والمكتبة (Left/Right Workspace Panel حسب RTL/LTR)
/// 2. مساحة الكانفاس والمعاينة المركزية الفاخرة (Central Canvas)
/// 3. لوحة أدوات التحكم والطبقات والخصائص (Properties & Tools Inspector)
///
/// مع الحفاظ التام 100% على كافة وظائف المحرر والـ Cubit والصلاحيات والاختبارات.
class VisualEditorPage extends StatefulWidget {
  const VisualEditorPage({
    super.key,
    this.cubit,
    this.canPublish = true,
    this.imagePermissions = const <String>{},
  });

  /// حقن اختياري للاختبارات؛ الإنتاج يبني الـ cubit الافتراضي نفسه.
  final VisualEditorCubit? cubit;
  final bool canPublish;

  /// Permission codes used to reveal only the catalogue image actions the
  /// signed-in staff member is authorized to perform.
  final Set<String> imagePermissions;

  @override
  State<VisualEditorPage> createState() => _VisualEditorPageState();
}

class _VisualEditorPageState extends State<VisualEditorPage> {
  late final VisualEditorCubit _cubit;
  double _zoom = 1.0;
  PreviewDevice _device = PreviewDevice.phone;
  String _selectedPageId = 'home';

  /// إعادة تحميل المعاينة: يرتفع بمقدار واحد كل ضغطة على زر Reload.
  int _previewReloadToken = 0;

  /// آخر خطأ أُعلن للموظف.
  String? _lastShownError;

  @override
  void initState() {
    super.initState();
    _cubit = widget.cubit ?? VisualEditorCubit();
    _cubit.initialize();
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<VisualEditorCubit>.value(
      value: _cubit,
      child: BlocConsumer<VisualEditorCubit, VisualEditorState>(
        listener: (context, state) {
          final error = state.errorMessage;
          if (error == null || error.isEmpty) {
            _lastShownError = null;
            return;
          }
          if (error == _lastShownError) return;
          _lastShownError = error;
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(error),
                duration: const Duration(seconds: 6),
              ),
            );
        },
        builder: (context, state) => Container(
          color: VisualEditorTokens.bg(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.pageHorizontalPadding,
              vertical: AppDimensions.pageVerticalPadding,
            ),
            child: _buildBody(context, state),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, VisualEditorState state) {
    if (state.status == VisualEditorStatus.loading) {
      return const AdminLoadingView();
    }
    if (state.status == VisualEditorStatus.failure) {
      return AdminFailureView(
        message: state.errorMessage,
        onRetry: _cubit.initialize,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        if (w >= 1400) return _buildWideLayout(context, state);
        if (w >= 900) return _buildMediumLayout(context, state);
        return _buildNarrowLayout(context, state);
      },
    );
  }

  // ------------------------------------------------------------------ layouts

  /// العرض العريض (≥ 1400px): تجربة SaaS ثلاثية الأعمدة فخمة ومتوازنة.
  Widget _buildWideLayout(BuildContext context, VisualEditorState state) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: 280, child: _pagesSidePanel(context, state)),
        const SizedBox(width: AppSpacing.lg),
        Expanded(child: _previewSection(context, state)),
        const SizedBox(width: AppSpacing.lg),
        SizedBox(width: 270, child: _toolsSidePanel(context, state)),
      ],
    );
  }

  /// العرض المتوسط (900px - 1400px): نفس التوزيع الثلاثي بأبعاد مدروسة.
  Widget _buildMediumLayout(BuildContext context, VisualEditorState state) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: 235, child: _pagesSidePanel(context, state)),
        const SizedBox(width: AppSpacing.lg),
        Expanded(child: _previewSection(context, state)),
        const SizedBox(width: AppSpacing.lg),
        SizedBox(width: 225, child: _toolsSidePanel(context, state)),
      ],
    );
  }

  /// العرض الضيق (< 900px): ترتيب رأسي متكامل لا يفقد أي أداة.
  Widget _buildNarrowLayout(BuildContext context, VisualEditorState state) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PageTabs(
            selectedPageId: _selectedPageId,
            onChanged: (pageId) {
              setState(() => _selectedPageId = pageId);
              _cubit.loadPage(pageId);
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(height: 620, child: _previewSection(context, state)),
          const SizedBox(height: AppSpacing.lg),
          VisualEditorToolbar(
            state: state,
            cubit: _cubit,
            canPublish: widget.canPublish,
            zoom: _zoom,
            device: _device,
            selectedPageId: _selectedPageId,
            onZoom: (v) => setState(() => _zoom = v.clamp(0.5, 2.0)),
            onDeviceChanged: (device) => setState(() => _device = device),
            onPageChanged: (pageId) {
              setState(() => _selectedPageId = pageId);
              _cubit.loadPage(pageId);
            },
            onReloadPreview: () => setState(() => _previewReloadToken++),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(height: 400, child: _componentTreePanel(context, state)),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(height: 400, child: _componentLibrary(context, state)),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(height: 400, child: _propertiesPanel(context, state)),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ side cards

  /// بطاقة عمل احترافية موحدة بهوية الألوان الدافئة والناعمة.
  Widget _sideCard(BuildContext context, Widget child) {
    return Container(
      decoration: BoxDecoration(
        color: VisualEditorTokens.surface(context),
        borderRadius: BorderRadius.circular(VisualEditorTokens.radiusLg),
        border: Border.all(
          color: VisualEditorTokens.border(context),
          width: 1.0,
        ),
        boxShadow: VisualEditorTokens.softShadow(context),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: child,
    );
  }

  /// عنوان قسم صغير وأنيق داخل اللوحة.
  Widget _panelLabel(BuildContext context, String label) {
    final textMuted = VisualEditorTokens.textMuted(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          fontWeight: AppFontWeights.semiBold,
          letterSpacing: 0.4,
          color: textMuted,
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ panels

  /// الجانب الأول (RTL: اليمين): هوية المحرر، صفحات تطبيق العميل، ثم مكتبة المكونات.
  Widget _pagesSidePanel(BuildContext context, VisualEditorState state) {
    final textPrimary = VisualEditorTokens.text(context);
    final textMuted = VisualEditorTokens.textMuted(context);

    return _sideCard(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: VisualEditorTokens.primaryOliveGreen,
                  borderRadius: BorderRadius.circular(VisualEditorTokens.radiusSm),
                ),
                child: const Icon(
                  Icons.coffee_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: AppSpacing.xs + 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      S.visualEditor,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: AppFontWeights.bold,
                        color: textPrimary,
                      ),
                    ),
                    Text(
                      'مقهى القهوة المختصة',
                      style: TextStyle(
                        fontSize: 10,
                        color: textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            S.visualEditorHint,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              color: textMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          EditorDivider(),
          const SizedBox(height: AppSpacing.sm),
          _panelLabel(context, 'صفحات تطبيق العميل'),
          Expanded(
            flex: 5,
            child: _PageList(
              selectedPageId: _selectedPageId,
              onChanged: (pageId) {
                setState(() => _selectedPageId = pageId);
                _cubit.loadPage(pageId);
              },
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          EditorDivider(),
          const SizedBox(height: AppSpacing.sm),
          Expanded(flex: 4, child: _componentLibrary(context, state)),
        ],
      ),
    );
  }

  /// الجانب المقابل: أدوات الجهاز والمعاينة والاتصال وتراجع/إعادة والطبقات والخصائص.
  Widget _toolsSidePanel(BuildContext context, VisualEditorState state) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textMuted = VisualEditorTokens.textMuted(context);
    final accent = VisualEditorTokens.primaryOliveGreen;

    return _sideCard(
      context,
      DefaultTabController(
        length: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _panelLabel(context, 'الجهاز والمعاينة'),
            EditorScreenSizeSelector(
              dark: dark,
              muted: textMuted,
              selected: _device,
              onSelected: (device) => setState(() => _device = device),
            ),
            const SizedBox(height: AppSpacing.sm),
            EditorZoomControls(
              zoom: _zoom,
              dark: dark,
              muted: textMuted,
              onZoom: (v) => setState(() => _zoom = v.clamp(0.5, 2.0)),
            ),
            const SizedBox(height: AppSpacing.sm),
            // حالة الاتصال وإعادة التحميل
            Row(
              children: [
                Expanded(
                  child: EditorConnectionStatus(
                    connection: state.previewConnection,
                    reason: state.previewStatusMessage,
                    dark: dark,
                  ),
                ),
                EditorIconBtn(
                  icon: AppIcons.refresh,
                  tooltip:
                      'إعادة تحميل المعاينة'
                      '${state.previewStatusMessage == null ? '' : ' — ${state.previewStatusMessage}'}',
                  onTap: () => setState(() => _previewReloadToken++),
                  dark: dark,
                  muted: textMuted,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            EditorDivider(),
            const SizedBox(height: AppSpacing.sm),
            // تراجع وإعادة + سجل الإصدارات والقوالب والاستوديو والتخلص.
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                EditorIconBtn(
                  icon: AppIcons.undo,
                  tooltip: S.visualEditorUndo,
                  onTap: _cubit.canUndo ? _cubit.undo : null,
                  dark: dark,
                  muted: textMuted,
                ),
                EditorIconBtn(
                  icon: AppIcons.redo,
                  tooltip: S.visualEditorRedo,
                  onTap: _cubit.canRedo ? _cubit.redo : null,
                  dark: dark,
                  muted: textMuted,
                ),
                EditorIconBtn(
                  icon: AppIcons.time01,
                  tooltip: S.visualEditorVersions,
                  onTap: () => showVisualEditorVersions(
                    context,
                    _cubit,
                    canPublish: widget.canPublish,
                  ),
                  dark: dark,
                  muted: textMuted,
                ),
                EditorIconBtn(
                  icon: AppIcons.folder01,
                  tooltip: S.visualEditorTemplates,
                  onTap: () => showVisualEditorTemplates(context, _cubit),
                  dark: dark,
                  muted: textMuted,
                ),
                EditorIconBtn(
                  icon: AppIcons.paintBrush,
                  tooltip: S.visualEditorThemeStudio,
                  onTap: () => showVisualEditorThemeStudio(context, _cubit),
                  dark: dark,
                  muted: textMuted,
                ),
                EditorIconBtn(
                  icon: AppIcons.delete02,
                  tooltip: S.visualEditorDiscard,
                  onTap: () => confirmVisualEditorDiscard(context, _cubit),
                  dark: dark,
                  muted: textMuted,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            // زر حفظ المسودة
            EditorToolbarButton(
              icon: AppIcons.upload01,
              label: S.visualEditorSaveDraft,
              onTap: state.isDirty ? _cubit.saveDraft : null,
              dark: dark,
            ),
            const SizedBox(height: AppSpacing.xs + 2),
            // زر النشر البارز باللون الأخضر الأساسي Deep Olive Green
            EditorToolbarButton(
              icon: AppIcons.sent,
              label: S.visualEditorPublish,
              onTap: widget.canPublish
                  ? () => confirmVisualEditorPublish(context, _cubit)
                  : null,
              dark: dark,
              accent: true,
              accentColor: accent,
            ),
            const SizedBox(height: AppSpacing.sm),
            EditorDivider(),
            TabBar(
              isScrollable: false,
              labelColor: VisualEditorTokens.primaryOliveGreen,
              unselectedLabelColor: textMuted,
              indicatorColor: VisualEditorTokens.primaryOliveGreen,
              tabs: [
                Tab(
                  icon: const Icon(Icons.layers_rounded, size: 16),
                  text: S.visualEditorLayers,
                ),
                Tab(
                  icon: Icon(AppIcons.tune, size: 16),
                  text: S.visualEditorProperties,
                ),
              ],
              labelStyle: const TextStyle(fontSize: 11, fontWeight: AppFontWeights.bold),
              unselectedLabelStyle: const TextStyle(fontSize: 11),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _componentTreePanel(context, state),
                  _propertiesPanel(context, state),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// المنطقة الوسطى الفاخرة المخصصة للمعاينة كبطل رئيسي (Hero Central Canvas).
  Widget _previewSection(BuildContext context, VisualEditorState state) {
    return Container(
      decoration: BoxDecoration(
        color: VisualEditorTokens.canvas(context),
        borderRadius: BorderRadius.circular(VisualEditorTokens.radiusLg),
        border: Border.all(
          color: VisualEditorTokens.border(context),
          width: 1.0,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(VisualEditorTokens.radiusLg - 1),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Container(
              decoration: BoxDecoration(
                boxShadow: VisualEditorTokens.deviceElevation(context),
                borderRadius: BorderRadius.circular(32),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: PreviewPanel(
                  pageId: _selectedPageId,
                  zoom: _zoom,
                  device: _device,
                  sessionId: state.sessionId,
                  components: state.getComponentsForPage(_selectedPageId),
                  theme: _cubit.theme,
                  selectedComponentId: state.selectedComponentId,
                  reloadToken: _previewReloadToken,
                  onConnectionChanged: (connection, reason) =>
                      _cubit.updatePreviewConnection(connection, reason: reason),
                  onElementSelected: _cubit.handleElementSelected,
                  onPreviewReady: _cubit.handlePreviewReady,
                  onPreviewError: _cubit.handlePreviewError,
                  onPropertyUpdated: _cubit.handlePropertyUpdated,
                  onTreeUpdated: _cubit.handleTreeUpdated,
                  outboundMessageType: _cubit.pendingMessage?.type,
                  outboundPayload: _cubit.pendingMessage?.payload,
                  outboundMessageId: _cubit.pendingMessage?.messageId,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _componentTreePanel(BuildContext context, VisualEditorState state) {
    return ComponentTreePanel(
      pageId: _selectedPageId,
      components: state.getComponentsForPage(_selectedPageId),
      selectedComponentId: state.selectedComponentId,
      onSelect: _cubit.selectComponent,
      onReorder: _cubit.reorderComponent,
      onDelete: _cubit.deleteComponent,
      onDuplicate: _cubit.duplicateComponent,
      onToggleVisibility: _cubit.toggleComponentVisibility,
    );
  }

  Widget _componentLibrary(BuildContext context, VisualEditorState state) {
    return ComponentLibraryPanel(
      pageId: _selectedPageId,
      availableComponents: ComponentRegistry.getForPage(_selectedPageId),
      onAddComponent: _cubit.addComponent,
    );
  }

  Widget _propertiesPanel(BuildContext context, VisualEditorState state) {
    final selected = state.selectedComponent;
    if (selected == null) {
      return AdminEmptyState(
        icon: AppIcons.tune,
        message: S.visualEditorNoSelection,
        hint: S.visualEditorSelectHint,
      );
    }
    return PropertiesInspectorPanel(
      component: selected,
      onPropertyChanged: _cubit.updateProperty,
      onResetProperty: _cubit.resetProperty,
      onBrowseImages: () => showVisualEditorImageAssetPicker(
        context: context,
        repository: VisualEditorImageAssetRepository(),
        permissions: widget.imagePermissions,
      ),
    );
  }
}

// ---------------------------------------------------------------------- misc

/// قائمة الصفحات العمودية المصممة بعناية ورقائق ChoiceChip مطابقة تماماً.
class _PageList extends StatelessWidget {
  const _PageList({required this.selectedPageId, required this.onChanged});

  final String selectedPageId;
  final void Function(String) onChanged;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final page in PreviewPages.all)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: ChoiceChip(
                  label: Text(page.label),
                  selected: selectedPageId == page.pageId,
                  onSelected: (_) => onChanged(page.pageId),
                  avatar: page.isEditable
                      ? null
                      : const Icon(AppIcons.lock, size: 12),
                  labelStyle: TextStyle(
                    fontSize: 11.5,
                    fontWeight: selectedPageId == page.pageId
                        ? AppFontWeights.bold
                        : AppFontWeights.regular,
                    color: selectedPageId == page.pageId
                        ? (dark ? Colors.white : VisualEditorTokens.primaryOliveGreen)
                        : VisualEditorTokens.text(context),
                  ),
                  selectedColor: dark
                      ? VisualEditorTokens.primaryOliveGreen.withAlpha(70)
                      : VisualEditorTokens.primaryOliveGreenLight,
                  backgroundColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(VisualEditorTokens.radiusSm),
                    side: BorderSide(
                      color: selectedPageId == page.pageId
                          ? VisualEditorTokens.primaryOliveGreen
                          : VisualEditorTokens.border(context),
                      width: selectedPageId == page.pageId ? 1.0 : 0.6,
                    ),
                  ),
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PageTabs extends StatelessWidget {
  const _PageTabs({required this.selectedPageId, required this.onChanged});

  final String selectedPageId;
  final void Function(String) onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final page in PreviewPages.all)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: AppSpacing.xs),
              child: ChoiceChip(
                label: Text(page.label),
                selected: selectedPageId == page.pageId,
                onSelected: (_) => onChanged(page.pageId),
                avatar: page.isEditable ? null : const Icon(AppIcons.lock, size: 12),
                labelStyle: const TextStyle(fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }
}
