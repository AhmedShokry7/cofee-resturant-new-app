import 'package:admin_app/features/visual_editor/presentation/manager/visual_editor_cubit.dart'
    show OutboundMessage;
import 'package:material_ui/material_ui.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/features/visual_editor/domain/design_contract.dart';
import 'package:admin_app/features/visual_editor/domain/preview_protocol.dart';
import 'package:admin_app/features/visual_editor/domain/visual_editor_models.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/preview_panel.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/visual_editor_theme_tokens.dart';

/// مساحة المعاينة المركزية مع أدوات اختيار حجم الجهاز وإطار الهاتف.
class VisualEditorCanvas extends StatelessWidget {
  const VisualEditorCanvas({
    super.key,
    required this.pageId,
    required this.sessionId,
    required this.zoom,
    required this.device,
    required this.components,
    required this.theme,
    required this.selectedComponentId,
    required this.reloadToken,
    this.previewLanguage = PreviewLanguage.arabic,
    this.previewThemeMode = PreviewThemeMode.light,
    required this.onConnectionChanged,
    required this.onElementSelected,
    required this.onPreviewReady,
    required this.onPreviewError,
    required this.onPropertyUpdated,
    required this.onTreeUpdated,
    this.outboundMessageType,
    this.outboundPayload,
    this.outboundMessageId,
    this.takePreviewMessages,
    this.isInteractiveMode = false,
    this.onZoomChanged,
    this.onResetZoom,
    this.onDeviceChanged,
    this.onReload,
    this.onComponentDropped,
    this.isDraggingComponent = false,
  });

  final String pageId;
  final String? sessionId;
  final double zoom;
  final PreviewDevice device;
  final List<EditableComponent> components;
  final DesignTheme theme;
  final String? selectedComponentId;
  final int reloadToken;

  /// لغة ووضع تطبيق العميل كما اختارهما الموظف في أدوات المعاينة.
  final PreviewLanguage previewLanguage;
  final PreviewThemeMode previewThemeMode;

  final void Function(PreviewConnection, String?)? onConnectionChanged;
  final void Function(dynamic) onElementSelected;
  final void Function(dynamic) onPreviewReady;
  final void Function(dynamic) onPreviewError;
  final void Function(dynamic) onPropertyUpdated;
  final void Function(dynamic) onTreeUpdated;
  final VisualEditorMessageType? outboundMessageType;
  final Map<String, dynamic>? outboundPayload;
  final String? outboundMessageId;
  final List<OutboundMessage> Function()? takePreviewMessages;
  final bool isInteractiveMode;
  final ValueChanged<double>? onZoomChanged;
  final VoidCallback? onResetZoom;
  final ValueChanged<PreviewDevice>? onDeviceChanged;
  final VoidCallback? onReload;
  final ValueChanged<String>? onComponentDropped;
  final bool isDraggingComponent;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final canvasColor = dark
        ? VisualEditorTokens.darkCanvasBg
        : const Color(0xFFF4EFE6);

    return Container(
      color: canvasColor,
      child: Stack(
        children: [
          // 1. خلفية النقش المائي لأوراق وبن القهوة
          Positioned.fill(
            child: CustomPaint(
              painter: _CoffeeLeavesWatermarkPainter(dark: dark),
            ),
          ),

          // 2. الكانفاس المركزي القابل للتكبير والإزاحة مع إطار الهاتف
          Positioned.fill(
            child: InteractiveViewer(
              scaleEnabled: false,
              boundaryMargin: const EdgeInsets.all(100),
              minScale: 0.5,
              maxScale: 2.5,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: 40,
                  ),
                  // PreviewPanel computes fitScale * zoom from the available
                  // device viewport. Passing zoom here as well applied it a
                  // second time (e.g. 80% became 64%) and made the customer
                  // app look unexpectedly small inside the editor.
                  child: SizedBox(
                    width: device.width,
                    height: device.height,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        PreviewPanel(
                          pageId: pageId,
                          zoom: zoom,
                          device: device,
                          sessionId: sessionId,
                          components: components,
                          theme: theme,
                          selectedComponentId: selectedComponentId,
                          reloadToken: reloadToken,
                          previewLanguage: previewLanguage,
                          previewThemeMode: previewThemeMode,
                          onConnectionChanged: onConnectionChanged,
                          onElementSelected: onElementSelected,
                          onPreviewReady: onPreviewReady,
                          onPreviewError: onPreviewError,
                          onPropertyUpdated: onPropertyUpdated,
                          onTreeUpdated: onTreeUpdated,
                          isDragSourceActive: isDraggingComponent,
                          isInteractiveMode: isInteractiveMode,
                          outboundMessageType: outboundMessageType,
                          outboundPayload: outboundPayload,
                          outboundMessageId: outboundMessageId,
                          takePreviewMessages: takePreviewMessages,
                        ),
                        if (isDraggingComponent)
                          DragTarget<String>(
                            onWillAcceptWithDetails: (details) =>
                                EditorPages.findById(pageId)
                                    ?.allowedComponentTypes
                                    .contains(details.data) ??
                                false,
                            onAcceptWithDetails: (details) =>
                                onComponentDropped?.call(details.data),
                            builder: (context, candidates, rejected) =>
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: candidates.isEmpty
                                        ? Colors.transparent
                                        : VisualEditorTokens.primaryOliveGreen
                                              .withAlpha(25),
                                    border: Border.all(
                                      color: candidates.isEmpty
                                          ? Colors.transparent
                                          : VisualEditorTokens
                                                .primaryOliveGreen,
                                      width: 3,
                                    ),
                                  ),
                                  child: Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 9,
                                      ),
                                      decoration: BoxDecoration(
                                        color: VisualEditorTokens
                                            .primaryOliveGreen,
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
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 3. الشريط العائم العلوي لاختيار الجهاز [📱 📱 🖥️ 🔄]
        ],
      ),
    );
  }
}

/// رسم مائي أنيق وفخم لأوراق وبذور القهوة على خلفية الكانفاس
class _CoffeeLeavesWatermarkPainter extends CustomPainter {
  const _CoffeeLeavesWatermarkPainter({required this.dark});

  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = dark
          ? Colors.white.withAlpha(7)
          : const Color(0xFF6E473B).withAlpha(12)
      ..style = PaintingStyle.fill;

    // رسم ورقة قهوة في الزاوية العلوية اليمنى
    _drawLeaf(
      canvas,
      paint,
      Offset(size.width * 0.82, size.height * 0.12),
      48,
      22,
      -0.4,
    );
    _drawLeaf(
      canvas,
      paint,
      Offset(size.width * 0.86, size.height * 0.18),
      38,
      18,
      0.3,
    );

    // رسم ورقة في الزاوية العلوية اليسرى
    _drawLeaf(
      canvas,
      paint,
      Offset(size.width * 0.15, size.height * 0.22),
      52,
      24,
      0.6,
    );

    // رسم ورقة في الزاوية السفلية اليسرى
    _drawLeaf(
      canvas,
      paint,
      Offset(size.width * 0.12, size.height * 0.78),
      60,
      28,
      -0.7,
    );

    // رسم ورقة في الزاوية السفلية اليمنى
    _drawLeaf(
      canvas,
      paint,
      Offset(size.width * 0.88, size.height * 0.82),
      65,
      30,
      0.5,
    );
  }

  void _drawLeaf(
    Canvas canvas,
    Paint paint,
    Offset center,
    double length,
    double width,
    double angle,
  ) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);

    final path = Path()
      ..moveTo(0, -length / 2)
      ..quadraticBezierTo(width, 0, 0, length / 2)
      ..quadraticBezierTo(-width, 0, 0, -length / 2);

    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CoffeeLeavesWatermarkPainter oldDelegate) =>
      oldDelegate.dark != dark;
}
