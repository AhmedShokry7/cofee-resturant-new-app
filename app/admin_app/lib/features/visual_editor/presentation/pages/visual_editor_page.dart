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

/// صفحة المحرر المرئي — مساحة عمل استوديو كاملة:
/// شريط أدوات علوي، لوحة الطبقات، مسرح معاينة حيّة، ومفتش الخصائص.
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
  String? _splashGroup;
  bool _compactLayersOpen = false;
  bool _compactPropertiesOpen = false;
  int _reloadToken = 0;
  String? _lastShownError;
  PageConflict? _lastShownConflict;

  Future<void> _showConflictDialog(PageConflict conflict) async {
    if (!mounted) return;
    final decision = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('تعارض في مراجعة الصفحة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'القاعدة تحمل مراجعة أحدث لصفحة «${conflict.pageId}» '
              '(مراجعة ${conflict.serverRevision}) من مرجعك '
              '(مراجعة ${conflict.knownRevision}) — جلسة أخرى عدّلت هذه '
              'الصفحة بعد تحميلك. اختر:',
            ),
            const SizedBox(height: 12),
            const Text(
              '• تحميل نسخة القاعدة: تفقد تعديلاتك المحلية على هذه الصفحة '
              'فقط، ولا تُلمس صفحات أخرى.\n'
              '• إجبار الحفظ: تكتب نسختك وتتجاوز ما كتبته الجلسة الأخرى '
              'على هذه الصفحة.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('reload'),
            child: const Text('تحميل نسخة القاعدة'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop('force'),
            child: const Text('إجبار الحفظ'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (decision == 'reload') {
      await _cubit.reloadConflictedFromServer();
    } else if (decision == 'force') {
      await _cubit.forceSaveConflicted();
    }
  }

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
          } else if (error != _lastShownError) {
            _lastShownError = error;
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(error),
                  duration: const Duration(seconds: 6),
                ),
              );
          }
          // تعارض مراجعة: حوار قرار لا شريط إشعار — الهدف حسم مصير
          // الصفحة: نسخة القاعدة أو الإجبار. بلا قرار لا يُحفظ شيئًا.
          final conflict = state.conflict;
          if (conflict != null && conflict != _lastShownConflict) {
            _lastShownConflict = conflict;
            _showConflictDialog(conflict);
          } else if (conflict == null) {
            _lastShownConflict = null;
          }
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
                    setState(() { _pageId = value; _splashGroup = null; });
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
                              // اللوحتان متناظرتان في العرض فلا يُقرأ
                              // المسرح أنه مائل لأحدهما مهما تغيّر الجهاز.
                              SizedBox(
                                width: (constraints.maxWidth * .23)
                                    .clamp(300.0, 380.0)
                                    .toDouble(),
                                child: _buildLayersPanel(state),
                              ),
                              const SizedBox(width: 16),
                              Expanded(child: _buildPreviewStage(state)),
                              const SizedBox(width: 16),
                              SizedBox(
                                width: (constraints.maxWidth * .23)
                                    .clamp(300.0, 380.0)
                                    .toDouble(),
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
                            top: 14,
                            right: 14,
                            child: _FloatingPanelButton(
                              tooltip: S.visualEditorLayers,
                              icon: Icons.layers_outlined,
                              active: _compactLayersOpen,
                              onPressed: () => setState(() {
                                _compactLayersOpen = !_compactLayersOpen;
                                if (_compactLayersOpen) {
                                  _compactPropertiesOpen = false;
                                }
                              }),
                            ),
                          ),
                          Positioned(
                            top: 14,
                            left: 14,
                            child: _FloatingPanelButton(
                              tooltip: S.visualEditorProperties,
                              icon: Icons.tune_outlined,
                              active: _compactPropertiesOpen,
                              onPressed: () => setState(() {
                                _compactPropertiesOpen =
                                    !_compactPropertiesOpen;
                                if (_compactPropertiesOpen) {
                                  _compactLayersOpen = false;
                                }
                              }),
                            ),
                          ),
                          Positioned(
                            top: 62,
                            bottom: 14,
                            right: 14,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              transitionBuilder: (child, animation) =>
                                  FadeTransition(
                                    opacity: animation,
                                    child: ScaleTransition(
                                      scale: Tween(
                                        begin: 0.96,
                                        end: 1.0,
                                      ).animate(animation),
                                      child: child,
                                    ),
                                  ),
                              child: _compactLayersOpen
                                  ? SizedBox(
                                      key: const ValueKey('compact-layers'),
                                      width: constraints.maxWidth
                                          .clamp(220.0, 320.0)
                                          .toDouble(),
                                      child: _buildLayersPanel(state),
                                    )
                                  : const SizedBox.shrink(
                                      key: ValueKey('compact-layers-empty'),
                                    ),
                            ),
                          ),
                          Positioned(
                            top: 62,
                            bottom: 14,
                            left: 14,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              transitionBuilder: (child, animation) =>
                                  FadeTransition(
                                    opacity: animation,
                                    child: ScaleTransition(
                                      scale: Tween(
                                        begin: 0.96,
                                        end: 1.0,
                                      ).animate(animation),
                                      child: child,
                                    ),
                                  ),
                              child: _compactPropertiesOpen
                                  ? SizedBox(
                                      key: const ValueKey('compact-properties'),
                                      width: constraints.maxWidth
                                          .clamp(220.0, 320.0)
                                          .toDouble(),
                                      child: _buildPropertiesPanel(state),
                                    )
                                  : const SizedBox.shrink(
                                      key: ValueKey('compact-properties-empty'),
                                    ),
                            ),
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

  /// مسرح المعاينة: خلفية بنقاط خفيفة وإطار مستدير يحيط بالجهاز.
  Widget _buildPreviewStage(VisualEditorState state) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: VisualEditorTokens.canvas(context),
        borderRadius: BorderRadius.circular(VisualEditorTokens.radiusPanel),
        border: Border.all(color: VisualEditorTokens.border(context)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(VisualEditorTokens.radiusPanel),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: _DotGridPainter(VisualEditorTokens.canvasDot(context)),
            ),
            PreviewPanel(
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
              onElementSelected: (data) {
                _cubit.handleElementSelected(data);
                if (_cubit.state.selectedComponent != null) _showProperties();
              },
              onPreviewReady: _cubit.handlePreviewReady,
              onPreviewError: _cubit.handlePreviewError,
              onPropertyUpdated: _cubit.handlePropertyUpdated,
              onTreeUpdated: _cubit.handleTreeUpdated,
              outboundMessageType: _cubit.pendingMessage?.type,
              outboundPayload: _cubit.pendingMessage?.payload,
              outboundMessageId: _cubit.pendingMessage?.messageId,
              takePreviewMessages: _cubit.takePreviewMessages,
            ),
          ],
        ),
      ),
    );
  }

  void _showProperties([String? splashGroup]) {
    setState(() {
      _splashGroup = splashGroup;
      _compactLayersOpen = false;
      _compactPropertiesOpen = true;
    });
  }

  Widget _buildLayersPanel(VisualEditorState state) => ComponentTreePanel(
    key: ValueKey('layers-$_pageId'),
    pageId: _pageId,
    components: state.getComponentsForPage(_pageId),
    selectedComponentId: state.selectedComponentId,
    splashGroup: _splashGroup,
    onSplashGroup: (id, group) { _cubit.selectComponent(id); _showProperties(group); },
    onSelect: (id) { _cubit.selectComponent(id); _showProperties(); },
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
        splashGroup: _splashGroup,
        selectedComponent: state.selectedComponent,
        imagePermissions: widget.imagePermissions,
        onPropertyChanged: _cubit.updateProperty,
        onResetProperty: _cubit.resetProperty,
        onPropertiesChanged: _cubit.updateProperties,
      );
}

/// زر طافٍ مستدير لتبديل اللوحات في العرض الضيق — بطاقة مرتفعة بظل ناعم
/// وتمييز واضح عند كون اللوحة مفتوحة.
class _FloatingPanelButton extends StatelessWidget {
  const _FloatingPanelButton({
    required this.tooltip,
    required this.icon,
    required this.active,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: active
            ? VisualEditorTokens.primaryOliveGreen
            : VisualEditorTokens.surface(context),
        borderRadius: BorderRadius.circular(VisualEditorTokens.radiusLg),
        elevation: 0,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(VisualEditorTokens.radiusLg),
            border: Border.all(
              color: active
                  ? Colors.transparent
                  : VisualEditorTokens.border(context),
            ),
            boxShadow: VisualEditorTokens.panelShadow(context),
          ),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(VisualEditorTokens.radiusLg),
            child: Padding(
              padding: const EdgeInsets.all(11),
              child: Icon(
                icon,
                size: 19,
                color: active
                    ? Colors.white
                    : VisualEditorTokens.textMuted(context),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// شبكة نقاط خفيفة لخلفية مسرح المعاينة — تضيف إحساس «الكانفس» الاحترافي
/// دون أن تنافس محتوى المعاينة.
class _DotGridPainter extends CustomPainter {
  const _DotGridPainter(this.dotColor);

  final Color dotColor;

  static const double _spacing = 18;
  static const double _radius = 1.1;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = dotColor;
    for (var y = _spacing / 2; y < size.height; y += _spacing) {
      for (var x = _spacing / 2; x < size.width; x += _spacing) {
        canvas.drawCircle(Offset(x, y), _radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter oldDelegate) =>
      oldDelegate.dotColor != dotColor;
}
