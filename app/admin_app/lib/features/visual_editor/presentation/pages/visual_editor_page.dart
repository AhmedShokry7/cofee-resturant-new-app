import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/features/visual_editor/domain/component_registry.dart';
import 'package:admin_app/features/visual_editor/domain/visual_editor_models.dart';
import 'package:admin_app/features/visual_editor/presentation/manager/visual_editor_cubit.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/component_library_panel.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/component_tree_panel.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/preview_panel.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/properties_inspector_panel.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/visual_editor_toolbar.dart';
import 'package:admin_app/shared/widgets/admin_empty_state.dart';
import 'package:admin_app/shared/widgets/admin_page_header.dart';
import 'package:admin_app/shared/widgets/admin_state_view.dart';

/// صفحة المحرر المرئي — نقطة الدخول الوحيدة للميزة.
///
/// تُنشئ [VisualEditorCubit] وتُهيئه، وتبني التخطيط المناسب للعرض:
/// - عريض جدًا: ثلاث لوحات متجاورة (مكتبة | معاينة | شجرة + خصائص).
/// - متوسط: معاينة + تبويبات جانبية.
/// - ضيق: كل لوحة تحت الأخرى.
class VisualEditorPage extends StatefulWidget {
  const VisualEditorPage({super.key});

  @override
  State<VisualEditorPage> createState() => _VisualEditorPageState();
}

class _VisualEditorPageState extends State<VisualEditorPage> {
  late final VisualEditorCubit _cubit;
  double _zoom = 1.0;
  String _selectedPageId = 'home';

  @override
  void initState() {
    super.initState();
    _cubit = VisualEditorCubit();
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
      child: BlocBuilder<VisualEditorCubit, VisualEditorState>(
        builder: (context, state) => Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.pageHorizontalPadding,
            vertical: AppDimensions.pageVerticalPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AdminPageHeader(
                title: S.visualEditor,
                subtitle: S.visualEditorHint,
                footer: VisualEditorToolbar(
                  state: state,
                  cubit: _cubit,
                  zoom: _zoom,
                  selectedPageId: _selectedPageId,
                  onZoom: (v) => setState(() => _zoom = v.clamp(0.5, 2.0)),
                  onPageChanged: (pageId) {
                    setState(() => _selectedPageId = pageId);
                    _cubit.loadPage(pageId);
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Expanded(child: _buildBody(context, state)),
            ],
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

  Widget _buildWideLayout(BuildContext context, VisualEditorState state) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 300,
          child: _componentLibrary(context, state),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          flex: 3,
          child: _previewSection(context, state),
        ),
        const SizedBox(width: AppSpacing.lg),
        SizedBox(
          width: 360,
          child: _rightSidebar(context, state),
        ),
      ],
    );
  }

  Widget _buildMediumLayout(BuildContext context, VisualEditorState state) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: _previewSection(context, state),
        ),
        const SizedBox(width: AppSpacing.lg),
        SizedBox(
          width: 360,
          child: _rightSidebar(context, state),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout(BuildContext context, VisualEditorState state) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 600, child: _previewSection(context, state)),
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

  // ------------------------------------------------------------------ panels

  Widget _previewSection(BuildContext context, VisualEditorState state) {
    return Column(
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
        Expanded(
          child: PreviewPanel(
            pageId: _selectedPageId,
            zoom: _zoom,
            sessionId: state.sessionId,
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
      ],
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
    );
  }

  Widget _rightSidebar(BuildContext context, VisualEditorState state) {
    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TabBar(
            tabs: [
              Tab(
                icon: const Icon(Icons.layers, size: 16),
                text: S.visualEditorLayers,
              ),
              Tab(
                icon: Icon(AppIcons.tune, size: 16),
                text: S.visualEditorProperties,
              ),
            ],
            labelStyle: const TextStyle(fontSize: 11),
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
    );
  }
}

// ---------------------------------------------------------------------- misc

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
          for (final page in EditorPages.pages)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: AppSpacing.xs),
              child: ChoiceChip(
                label: Text(page.label),
                selected: selectedPageId == page.pageId,
                onSelected: page.isEditable
                    ? (_) => onChanged(page.pageId)
                    : null,
                avatar: page.isEditable
                    ? null
                    : Icon(AppIcons.lock, size: 12),
                labelStyle: const TextStyle(fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }
}
