import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/features/visual_editor/domain/component_registry.dart';
import 'package:admin_app/features/visual_editor/domain/visual_editor_models.dart';
import 'package:admin_app/features/visual_editor/presentation/manager/visual_editor_cubit.dart';
import 'package:admin_app/features/visual_editor/presentation/manager/visual_editor_state.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/component_tree_panel.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/component_library_panel.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/preview_panel.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/properties_inspector_panel.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/visual_editor_toolbar.dart';
import 'package:admin_app/shared/widgets/admin_page_header.dart';
import 'package:admin_app/shared/widgets/admin_state_view.dart';

/// صفحة المحرر المرئي الجديدة - Visual Editor
///
/// تحل محل المحاكي القديم (CustomerPreviewPage و AppBuilderPage).
/// تعتمد على تشغيل Customer App Flutter Web داخل iframe والتواصل عبر postMessage.
class VisualEditorPage extends StatefulWidget {
  const VisualEditorPage({super.key});

  @override
  State<VisualEditorPage> createState() => _VisualEditorPageState();
}

class _VisualEditorPageState extends State<VisualEditorPage> {
  late final VisualEditorCubit _cubit;
  double _zoom = 1.0;
  String? _selectedPageId = 'home';

  @override
  void initState() {
    super.initState();
    _cubit = VisualEditorCubit();
    _cubit.initialize();
    ComponentRegistry.initialize();
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
        builder: (context, state) {
          return Padding(
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
                    onZoom: (next) => setState(() => _zoom = next.clamp(0.5, 2.0)),
                    onPageChanged: (pageId) => setState(() => _selectedPageId = pageId),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Expanded(
                  child: _buildBody(context, state),
                ),
              ],
            ),
          );
        },
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

    final selectedPageId = _selectedPageId ?? 'home';
    final page = EditorPages.findById(selectedPageId);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1400;
        final isMedium = constraints.maxWidth >= 1000;

        if (!isMedium) {
          // Mobile layout: stacked panels
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildPreviewSection(context, state, selectedPageId),
                const SizedBox(height: AppSpacing.lg),
                _buildComponentTreeSection(context, state, selectedPageId),
                const SizedBox(height: AppSpacing.lg),
                _buildComponentLibrarySection(context, state, selectedPageId),
                const SizedBox(height: AppSpacing.lg),
                _buildPropertiesSection(context, state),
              ],
            ),
          );
        }

        if (!isWide) {
          // Medium layout: preview + sidebar with tabs
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: _buildPreviewSection(context, state, selectedPageId),
              ),
              const SizedBox(width: AppSpacing.lg),
              SizedBox(
                width: 380,
                child: _buildSidebarTabs(context, state, selectedPageId),
              ),
            ],
          );
        }

        // Wide layout: three panels
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left: Component Library
            SizedBox(
              width: 320,
              child: _buildComponentLibrarySection(context, state, selectedPageId),
            ),
            const SizedBox(width: AppSpacing.lg),
            // Center: Preview
            Expanded(
              flex: 3,
              child: _buildPreviewSection(context, state, selectedPageId),
            ),
            const SizedBox(width: AppSpacing.lg),
            // Right: Component Tree + Properties
            SizedBox(
              width: 380,
              child: _buildSidebarTabs(context, state, selectedPageId),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPreviewSection(
    BuildContext context,
    VisualEditorState state,
    String pageId,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Page selector tabs
        _buildPageTabs(context, state),
        const SizedBox(height: AppSpacing.md),
        // Preview iframe
        Expanded(
          child: PreviewPanel(
            pageId: pageId,
            zoom: _zoom,
            sessionId: state.sessionId,
            onElementSelected: _cubit.handleElementSelected,
            onPreviewReady: _cubit.handlePreviewReady,
            onPreviewError: _cubit.handlePreviewError,
          ),
        ),
      ],
    );
  }

  Widget _buildPageTabs(BuildContext context, VisualEditorState state) {
    final editablePages = EditorPages.editablePages;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final page in editablePages)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: ChoiceChip(
                label: Text(page.label),
                selected: _selectedPageId == page.pageId,
                onSelected: (_) {
                  setState(() => _selectedPageId = page.pageId);
                  _cubit.loadPage(page.pageId);
                },
                avatar: page.isEditable
                    ? null
                    : Icon(AppIcons.lock, size: 14),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildComponentTreeSection(
    BuildContext context,
    VisualEditorState state,
    String pageId,
  ) {
    return ComponentTreePanel(
      pageId: pageId,
      components: state.getComponentsForPage(pageId),
      selectedComponentId: state.selectedComponentId,
      onSelect: _cubit.selectComponent,
      onReorder: _cubit.reorderComponent,
      onDelete: _cubit.deleteComponent,
      onDuplicate: _cubit.duplicateComponent,
      onToggleVisibility: _cubit.toggleComponentVisibility,
    );
  }

  Widget _buildComponentLibrarySection(
    BuildContext context,
    VisualEditorState state,
    String pageId,
  ) {
    return ComponentLibraryPanel(
      pageId: pageId,
      availableComponents: ComponentRegistry.getForPage(pageId),
      onAddComponent: _cubit.addComponent,
    );
  }

  Widget _buildPropertiesSection(
    BuildContext context,
    VisualEditorState state,
  ) {
    final selectedComponent = state.selectedComponent;
    if (selectedComponent == null) {
      return _buildNoSelectionPlaceholder(context);
    }

    return PropertiesInspectorPanel(
      component: selectedComponent,
      onPropertyChanged: _cubit.updateProperty,
      onResetProperty: _cubit.resetProperty,
    );
  }

  Widget _buildSidebarTabs(
    BuildContext context,
    VisualEditorState state,
    String pageId,
  ) {
    return DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TabBar(
            tabs: const [
              Tab(text: 'الطبقات', icon: Icon(Icons.layers)),
              Tab(text: 'المكتبة', icon: Icon(Icons.widgets)),
              Tab(text: 'الخصائص', icon: Icon(Icons.tune)),
            ],
            labelStyle: const TextStyle(fontSize: 12),
            unselectedLabelStyle: const TextStyle(fontSize: 12),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildComponentTreeSection(context, state, pageId),
                _buildComponentLibrarySection(context, state, pageId),
                _buildPropertiesSection(context, state),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoSelectionPlaceholder(BuildContext context) {
    return AdminEmptyState(
      icon: AppIcons.layers,
      message: S.visualEditorNoSelection,
      actionLabel: S.visualEditorSelectElement,
      onAction: () {
        // Focus the component tree
      },
    );
  }
}