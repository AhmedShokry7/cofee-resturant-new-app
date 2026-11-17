import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/visual_editor/domain/design_contract.dart';
import 'package:admin_app/features/visual_editor/domain/preview_protocol.dart';
import 'package:admin_app/features/visual_editor/domain/visual_editor_models.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/preview_panel.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/visual_editor_theme_tokens.dart';

/// منطقة العمل والمعاينة المركزية (Central Canvas — Customer Preview).
///
/// تمثل الجزء الأكبر والأهم في الصفحة:
/// - خلفية Canvas دافئة وهادئة
/// - إطار هاتف احترافي فخم مع حواف وزوايا حقيقية وظل ثلاثي الأبعاد واقعي
/// - تحكم كامل بالأبعاد والمقياس
/// - عدم قص الهاتف أو إخفاء أي جزء منه
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
    required this.onConnectionChanged,
    required this.onElementSelected,
    required this.onPreviewReady,
    required this.onPreviewError,
    required this.onPropertyUpdated,
    required this.onTreeUpdated,
    this.outboundMessageType,
    this.outboundPayload,
    this.outboundMessageId,
    this.isInteractiveMode = false,
    this.onZoomChanged,
    this.onResetZoom,
    this.onDeviceChanged,
  });

  final String pageId;
  final String? sessionId;
  final double zoom;
  final PreviewDevice device;
  final List<EditableComponent> components;
  final DesignTheme theme;
  final String? selectedComponentId;
  final int reloadToken;
  final void Function(PreviewConnection, String?)? onConnectionChanged;
  final void Function(dynamic) onElementSelected;
  final void Function(dynamic) onPreviewReady;
  final void Function(dynamic) onPreviewError;
  final void Function(dynamic) onPropertyUpdated;
  final void Function(dynamic) onTreeUpdated;
  final VisualEditorMessageType? outboundMessageType;
  final Map<String, dynamic>? outboundPayload;
  final String? outboundMessageId;
  final bool isInteractiveMode;
  final ValueChanged<double>? onZoomChanged;
  final VoidCallback? onResetZoom;
  final ValueChanged<PreviewDevice>? onDeviceChanged;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final canvasColor = VisualEditorTokens.canvas(context);

    return Container(
      color: canvasColor,
      child: Stack(
        children: [
          // 1. الكانفاس المتمركز القابل للتحريك والتكبير
          Positioned.fill(
            child: InteractiveViewer(
              boundaryMargin: const EdgeInsets.all(120),
              minScale: 0.4,
              maxScale: 2.5,
              transformationController: null,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  child: _buildDeviceFrame(context, dark),
                ),
              ),
            ),
          ),

          // 2. مؤشر أبعاد الشاشة والجهاز في الأعلى
          Positioned(
            top: AppSpacing.sm,
            left: 0,
            right: 0,
            child: Center(
              child: _buildDeviceDimensionsPill(context, dark),
            ),
          ),

          // 3. شريط عائم سفلي سريع للمعاينة والزوم
          Positioned(
            bottom: AppSpacing.md,
            left: 0,
            right: 0,
            child: Center(
              child: _buildFloatingCanvasBar(context, dark),
            ),
          ),
        ],
      ),
    );
  }

  // --- مؤشر أبعاد الجهاز ---
  Widget _buildDeviceDimensionsPill(BuildContext context, bool dark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: dark
            ? VisualEditorTokens.darkSurface.withOpacity(0.85)
            : Colors.white.withOpacity(0.88),
        borderRadius: BorderRadius.circular(VisualEditorTokens.radiusXl),
        border: Border.all(
          color: dark ? VisualEditorTokens.darkBorder : VisualEditorTokens.borderWarmGray,
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            device.icon,
            size: 13,
            color: VisualEditorTokens.primaryOliveGreen,
          ),
          const SizedBox(width: 5),
          Text(
            '${device.label} • ${device.width.toInt()} × ${device.height.toInt()} px',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: AppFontWeights.medium,
              color: VisualEditorTokens.textMuted(context),
            ),
          ),
          if (isInteractiveMode) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: VisualEditorTokens.statusSuccess.withOpacity(0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'تفاعل مباشر',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: AppFontWeights.bold,
                  color: VisualEditorTokens.statusSuccess,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- إطار الجهاز الاحترافي ---
  Widget _buildDeviceFrame(BuildContext context, bool dark) {
    // الأبعاد الأصلية للجهاز المختار
    final targetWidth = device.width * zoom;
    final targetHeight = device.height * zoom;

    // سمك الإطار الخارجي للهاتف
    const double frameBezel = 12.0;
    const double frameCornerRadius = 44.0;

    return Container(
      width: targetWidth + (frameBezel * 2),
      height: targetHeight + (frameBezel * 2),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2220), // هيكل معدني أسود داكن وفخم
        borderRadius: BorderRadius.circular(frameCornerRadius),
        border: Border.all(
          color: const Color(0xFF3B443F),
          width: 2.5,
        ),
        boxShadow: VisualEditorTokens.deviceElevation(context),
      ),
      padding: const EdgeInsets.all(frameBezel),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(frameCornerRadius - frameBezel),
        child: Stack(
          children: [
            // شاشة العميل الفعلية عبر PreviewPanel
            Positioned.fill(
              child: PreviewPanel(
                pageId: pageId,
                zoom: zoom,
                device: device,
                sessionId: sessionId,
                components: components,
                theme: theme,
                selectedComponentId: selectedComponentId,
                reloadToken: reloadToken,
                onConnectionChanged: onConnectionChanged,
                onElementSelected: onElementSelected,
                onPreviewReady: onPreviewReady,
                onPreviewError: onPreviewError,
                onPropertyUpdated: onPropertyUpdated,
                onTreeUpdated: onTreeUpdated,
                outboundMessageType: outboundMessageType,
                outboundPayload: outboundPayload,
                outboundMessageId: outboundMessageId,
              ),
            ),

            // محاكاة الجزيرة الديناميكية / الكاميرا الأمامية
            Positioned(
              top: 8,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 90 * zoom.clamp(0.7, 1.0),
                  height: 22 * zoom.clamp(0.7, 1.0),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: const BoxDecoration(
                          color: Color(0xFF1A2130),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- شريط عائم سفلي سريع للمعاينة ---
  Widget _buildFloatingCanvasBar(BuildContext context, bool dark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: dark
            ? VisualEditorTokens.darkSurface.withOpacity(0.92)
            : Colors.white.withOpacity(0.94),
        borderRadius: BorderRadius.circular(VisualEditorTokens.radiusXl),
        border: Border.all(
          color: dark ? VisualEditorTokens.darkBorder : VisualEditorTokens.borderWarmGray,
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // تصغير
          IconButton(
            onPressed: onZoomChanged != null && zoom > 0.5 ? () => onZoomChanged!(zoom - 0.1) : null,
            icon: const Icon(Icons.remove_rounded, size: 16),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            tooltip: 'تصغير (-)',
          ),
          // نسبة التكبير الحالية
          InkWell(
            onTap: onResetZoom,
            borderRadius: BorderRadius.circular(VisualEditorTokens.radiusSm),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              child: Text(
                '${(zoom * 100).round()}%',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: AppFontWeights.bold,
                  color: VisualEditorTokens.text(context),
                ),
              ),
            ),
          ),
          // تكبير
          IconButton(
            onPressed: onZoomChanged != null && zoom < 2.0 ? () => onZoomChanged!(zoom + 0.1) : null,
            icon: const Icon(Icons.add_rounded, size: 16),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            tooltip: 'تكبير (+)',
          ),
          Container(
            width: 1,
            height: 16,
            color: dark ? VisualEditorTokens.darkBorder : VisualEditorTokens.borderWarmGray,
            margin: const EdgeInsets.symmetric(horizontal: 4),
          ),
          // إعادة الضبط إلى الحجم الحقيقي 100%
          Tooltip(
            message: 'الحجم الطبيعي 100%',
            child: InkWell(
              onTap: onResetZoom,
              borderRadius: BorderRadius.circular(VisualEditorTokens.radiusSm),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                child: Text(
                  '1:1',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: AppFontWeights.semiBold,
                    color: VisualEditorTokens.primaryOliveGreen,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
