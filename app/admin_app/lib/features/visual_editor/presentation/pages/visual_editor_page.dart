import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/visual_editor/presentation/manager/visual_editor_cubit.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/preview_panel.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/component_tree_panel.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/visual_editor_right_inspector.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/studio_single_row_toolbar.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/visual_editor_theme_tokens.dart';
import 'package:admin_app/shared/widgets/admin_state_view.dart';

class VisualEditorPage extends StatefulWidget {
  const VisualEditorPage({
    super.key,
    this.cubit,
    this.canPublish = true,
    this.imagePermissions = const <String>{},
  });

  final VisualEditorCubit? cubit;
  final bool canPublish;
  final Set<String> imagePermissions;

  @override
  State<VisualEditorPage> createState() => _VisualEditorPageState();
}

class _VisualEditorPageState extends State<VisualEditorPage> {
  late final VisualEditorCubit _cubit;
  String _pageId = 'home';
  PreviewDevice _device = PreviewDevice.phone;
  bool _interactive = false;
  bool _compactLayersOpen = false;
  bool _compactPropertiesOpen = false;
  int _reloadToken = 0;
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
        builder: (context, state) {
          if (state.status == VisualEditorStatus.loading) {
            return const AdminLoadingView();
          }
          if (state.status == VisualEditorStatus.failure) {
            return AdminFailureView(
              message: state.errorMessage,
              onRetry: _cubit.initialize,
            );
          }
          return ColoredBox(
            color: VisualEditorTokens.canvas(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                StudioSingleRowToolbar(
                  state: state,
                  cubit: _cubit,
                  canPublish: widget.canPublish,
                  device: _device,
                  pageId: _pageId,
                  interactive: _interactive,
                  onDeviceChanged: (value) => setState(() => _device = value),
                  onPageChanged: (value) {
                    setState(() => _pageId = value);
                    _cubit.loadPage(value);
                  },
                  onModeChanged: (value) =>
                      setState(() => _interactive = value),
                  onReloadPreview: () => setState(() => _reloadToken++),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final wideWorkspace = constraints.maxWidth >= 1180;
                      if (wideWorkspace) {
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                width: 276,
                                child: _buildLayersPanel(state),
                              ),
                              const SizedBox(width: 16),
                              Expanded(child: _buildPreviewStage(state)),
                              const SizedBox(width: 16),
                              SizedBox(
                                width: 304,
                                child: _buildPropertiesPanel(state),
                              ),
                            ],
                          ),
                        );
                      }
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(child: _buildPreviewStage(state)),
                          Positioned(
                            top: 12,
                            right: 12,
                            child: IconButton.filledTonal(
                              tooltip: S.visualEditorLayers,
                              onPressed: () => setState(() {
                                _compactLayersOpen = !_compactLayersOpen;
                              }),
                              icon: const Icon(Icons.layers_outlined),
                            ),
                          ),
                          Positioned(
                            top: 12,
                            left: 12,
                            child: IconButton.filledTonal(
                              tooltip: S.visualEditorProperties,
                              onPressed: () => setState(() {
                                _compactPropertiesOpen =
                                    !_compactPropertiesOpen;
                              }),
                              icon: const Icon(Icons.tune_outlined),
                            ),
                          ),
                          if (_compactLayersOpen)
                            Positioned(
                              top: 60,
                              bottom: 12,
                              right: 12,
                              width: constraints.maxWidth
                                  .clamp(220.0, 320.0)
                                  .toDouble(),
                              child: _buildLayersPanel(state),
                            ),
                          if (_compactPropertiesOpen)
                            Positioned(
                              top: 60,
                              bottom: 12,
                              left: 12,
                              width: constraints.maxWidth
                                  .clamp(220.0, 320.0)
                                  .toDouble(),
                              child: _buildPropertiesPanel(state),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPreviewStage(VisualEditorState state) => DecoratedBox(
    decoration: BoxDecoration(
      color: VisualEditorTokens.canvas(context),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: VisualEditorTokens.border(context)),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: PreviewPanel(
        pageId: _pageId,
        sessionId: state.sessionId,
        zoom: 1,
        device: _device,
        isInteractiveMode: _interactive,
        components: state.getComponentsForPage(_pageId),
        theme: _cubit.theme,
        selectedComponentId: state.selectedComponentId,
        reloadToken: _reloadToken,
        previewLanguage: state.previewLanguage,
        previewThemeMode: state.previewThemeMode,
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
        takePreviewMessages: _cubit.takePreviewMessages,
      ),
    ),
  );

  Widget _buildLayersPanel(VisualEditorState state) => ComponentTreePanel(
    key: ValueKey('layers-$_pageId'),
    pageId: _pageId,
    components: state.getComponentsForPage(_pageId),
    selectedComponentId: state.selectedComponentId,
    onSelect: _cubit.selectComponent,
    onReorder: _cubit.reorderComponent,
    onDelete: _cubit.deleteComponent,
    onDuplicate: _cubit.duplicateComponent,
    onToggleVisibility: (componentId) {
      final component = state.findComponent(componentId);
      if (component?.componentType == 'splashSettings') {
        final imageVisible =
            component!.properties['imageVisible'] as bool? ?? true;
        _cubit.updateProperty(
          componentId: componentId,
          propertyKey: 'imageVisible',
          value: !imageVisible,
        );
      } else {
        _cubit.toggleComponentVisibility(componentId);
      }
    },
    onAddComponent: (type) =>
        _cubit.addComponent(pageId: _pageId, componentType: type),
  );

  Widget _buildPropertiesPanel(VisualEditorState state) =>
      VisualEditorRightInspector(
        selectedComponent: state.selectedComponent,
        imagePermissions: widget.imagePermissions,
        onPropertyChanged: _cubit.updateProperty,
        onResetProperty: _cubit.resetProperty,
        onPropertiesChanged: _cubit.updateProperties,
      );
}
