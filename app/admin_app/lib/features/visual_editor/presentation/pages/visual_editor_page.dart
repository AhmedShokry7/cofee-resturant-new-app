import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/features/visual_editor/data/visual_editor_image_asset_repository.dart';
import 'package:admin_app/features/visual_editor/domain/component_registry.dart';
import 'package:admin_app/features/visual_editor/domain/design_document_codec.dart';
import 'package:admin_app/features/visual_editor/domain/visual_editor_models.dart';
import 'package:admin_app/features/visual_editor/presentation/manager/visual_editor_cubit.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/component_library_panel.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/component_tree_panel.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/preview_panel.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/properties_inspector_panel.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/visual_editor_canvas.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/visual_editor_image_asset_picker.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/visual_editor_left_panel.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/visual_editor_right_inspector.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/visual_editor_theme_tokens.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/visual_editor_toolbar.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/visual_editor_top_bar.dart';
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
  bool _isInteractiveMode = false;
  bool _isDraggingComponent = false;
  bool _isLeftPanelOpen = true;
  bool _isRightPanelOpen = true;

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
          child: _buildBody(context, state),
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

  /// العرض العريض (≥ 1400px): تجربة المتصفح الكاملة المطابقة للتصميم المرجعي تماماً.
  Widget _buildWideLayout(BuildContext context, VisualEditorState state) {
    return Column(
      children: [
        VisualEditorTopBar(
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
          onFitToScreen: () => setState(() => _zoom = 1.0),
          isInteractiveMode: _isInteractiveMode,
          onToggleInteractiveMode: (v) =>
              setState(() => _isInteractiveMode = v),
          onToggleLeftPanel: () =>
              setState(() => _isLeftPanelOpen = !_isLeftPanelOpen),
          isLeftPanelOpen: _isLeftPanelOpen,
          onToggleRightPanel: () =>
              setState(() => _isRightPanelOpen = !_isRightPanelOpen),
          isRightPanelOpen: _isRightPanelOpen,
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              VisualEditorLeftPanel(
                state: state,
                cubit: _cubit,
                selectedPageId: _selectedPageId,
                onPageSelected: (pageId) {
                  setState(() => _selectedPageId = pageId);
                  _cubit.loadPage(pageId);
                },
                onAddComponent: _addComponentToSelection,
                onDragStateChanged: (dragging) =>
                    setState(() => _isDraggingComponent = dragging),
                isOpen: _isLeftPanelOpen,
                onToggleOpen: () =>
                    setState(() => _isLeftPanelOpen = !_isLeftPanelOpen),
                imagePermissions: widget.imagePermissions,
                canPublish: widget.canPublish,
              ),
              Expanded(
                child: VisualEditorCanvas(
                  pageId: _selectedPageId,
                  sessionId: state.sessionId,
                  zoom: _zoom,
                  device: _device,
                  components: state.getComponentsForPage(_selectedPageId),
                  theme: _cubit.theme,
                  selectedComponentId: state.selectedComponentId,
                  reloadToken: _previewReloadToken,
                  previewLanguage: state.previewLanguage,
                  previewThemeMode: state.previewThemeMode,
                  onConnectionChanged: (connection, reason) => _cubit
                      .updatePreviewConnection(connection, reason: reason),
                  onElementSelected: _cubit.handleElementSelected,
                  onPreviewReady: _cubit.handlePreviewReady,
                  onPreviewError: _cubit.handlePreviewError,
                  onPropertyUpdated: _cubit.handlePropertyUpdated,
                  onTreeUpdated: _cubit.handleTreeUpdated,
                  outboundMessageType: _cubit.pendingMessage?.type,
                  outboundPayload: _cubit.pendingMessage?.payload,
                  outboundMessageId: _cubit.pendingMessage?.messageId,
                  isInteractiveMode: _isInteractiveMode,
                  onZoomChanged: (v) =>
                      setState(() => _zoom = v.clamp(0.5, 2.0)),
                  onResetZoom: () => setState(() => _zoom = 1.0),
                  onDeviceChanged: (d) => setState(() => _device = d),
                  onReload: () => setState(() => _previewReloadToken++),
                  onComponentDropped: _addComponentToSelection,
                  isDraggingComponent: _isDraggingComponent,
                ),
              ),
              VisualEditorRightInspector(
                selectedComponent: state.selectedComponent,
                onPropertyChanged: _cubit.updateProperty,
                onResetProperty: _cubit.resetProperty,
                imagePermissions: widget.imagePermissions,
                onClose: () => _cubit.selectComponent(''),
                onSaveDraft: _cubit.saveDraft,
                isDirty: state.isDirty,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// العرض المتوسط (900px - 1400px): نفس التوزيع بكفاءة تامة.
  Widget _buildMediumLayout(BuildContext context, VisualEditorState state) {
    return _buildWideLayout(context, state);
  }

  void _addComponentToSelection(String componentType) {
    final selected = _cubit.state.selectedComponent;
    final parentId =
        selected != null &&
            selected.pageId == _selectedPageId &&
            DesignDocumentCodec.canNest(
              childType: componentType,
              parentType: selected.componentType,
            )
        ? selected.componentId
        : null;
    _cubit.addComponent(
      pageId: _selectedPageId,
      componentType: componentType,
      parentId: parentId,
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
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    PreviewPanel(
                      pageId: _selectedPageId,
                      zoom: _zoom,
                      device: _device,
                      sessionId: state.sessionId,
                      components: state.getComponentsForPage(_selectedPageId),
                      theme: _cubit.theme,
                      selectedComponentId: state.selectedComponentId,
                      reloadToken: _previewReloadToken,
                      previewLanguage: state.previewLanguage,
                      previewThemeMode: state.previewThemeMode,
                      onConnectionChanged: (connection, reason) => _cubit
                          .updatePreviewConnection(connection, reason: reason),
                      onElementSelected: _cubit.handleElementSelected,
                      onPreviewReady: _cubit.handlePreviewReady,
                      onPreviewError: _cubit.handlePreviewError,
                      onPropertyUpdated: _cubit.handlePropertyUpdated,
                      onTreeUpdated: _cubit.handleTreeUpdated,
                      outboundMessageType: _cubit.pendingMessage?.type,
                      outboundPayload: _cubit.pendingMessage?.payload,
                      outboundMessageId: _cubit.pendingMessage?.messageId,
                      isDragSourceActive: _isDraggingComponent,
                    ),
                    if (_isDraggingComponent)
                      DragTarget<String>(
                        onWillAcceptWithDetails: (details) =>
                            EditorPages.findById(_selectedPageId)
                                ?.allowedComponentTypes
                                .contains(details.data) ??
                            false,
                        onAcceptWithDetails: (details) =>
                            _addComponentToSelection(details.data),
                        builder: (context, candidates, rejected) => Container(
                          alignment: Alignment.center,
                          color: candidates.isEmpty
                              ? Colors.transparent
                              : VisualEditorTokens.primaryOliveGreen.withAlpha(
                                  25,
                                ),
                          child: candidates.isEmpty
                              ? const SizedBox.shrink()
                              : Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 9,
                                  ),
                                  decoration: BoxDecoration(
                                    color: VisualEditorTokens.primaryOliveGreen,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    'أفلت المكوّن لإضافته إلى الصفحة',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                        ),
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

  Future<void> _confirmDeleteComponent(
    BuildContext context,
    String componentId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(S.visualEditorDelete),
        content: Text(S.visualEditorDeleteComponentConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(S.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColor.errorColor),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(S.visualEditorDelete),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) _cubit.deleteComponent(componentId);
  }

  Widget _componentTreePanel(BuildContext context, VisualEditorState state) {
    return ComponentTreePanel(
      pageId: _selectedPageId,
      components: state.getComponentsForPage(_selectedPageId),
      selectedComponentId: state.selectedComponentId,
      onSelect: _cubit.selectComponent,
      onReorder: _cubit.reorderComponent,
      onDelete: (id) => _confirmDeleteComponent(context, id),
      onDuplicate: _cubit.duplicateComponent,
      onToggleVisibility: _cubit.toggleComponentVisibility,
    );
  }

  Widget _componentLibrary(BuildContext context, VisualEditorState state) {
    return ComponentLibraryPanel(
      pageId: _selectedPageId,
      availableComponents: ComponentRegistry.getForPage(_selectedPageId),
      onDragStateChanged: (dragging) =>
          setState(() => _isDraggingComponent = dragging),
      onAddComponent: ({
        required pageId,
        required componentType,
        parentId,
        index,
      }) => _addComponentToSelection(componentType),
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
                avatar: page.isEditable
                    ? null
                    : const Icon(AppIcons.lock, size: 12),
                labelStyle: const TextStyle(fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }
}
