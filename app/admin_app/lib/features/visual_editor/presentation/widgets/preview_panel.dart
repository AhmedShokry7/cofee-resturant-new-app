import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/visual_editor/domain/visual_editor_models.dart';

import 'preview_panel_stub.dart'
    if (dart.library.js_interop) 'preview_panel_web.dart'
    as preview_platform;

/// أحجام المعاينة: خمسة أجهزة، عرضها وارتفاعها المنطقي هو المرسوم، فما
/// يراه الموظف في المحرّر هو ما سيراه الزبون على جهاز مثله.
enum PreviewDevice {
  phoneSmall('موبايل صغير', AppIcons.smartPhone01, 360, 740),
  phone('موبايل', AppIcons.smartPhone01, 390, 844),
  phoneLarge('موبايل كبير', AppIcons.smartPhone01, 430, 932),
  tabletPortrait('تابلت عمودي', Icons.tablet_outlined, 768, 1024),
  tabletLandscape('تابلت أفقي', Icons.tablet, 1024, 768);

  const PreviewDevice(
    this.label,
    this.icon,
    this.width,
    this.height,
  );

  final String label;
  final IconData icon;
  final double width;
  final double height;
}

/// حاوية المعاينة المركزية.
///
/// على Web تعرض Customer Flutter Web داخل HtmlElementView (iframe).
/// على غير Web تعرض لوحة توجيهية بدلًا منه.
///
/// الرسائل الصادرة تلتقط من الحالة: كل رسالة يُطلقها الـ Cubit تُرسل مرة
/// واحدة بمعرفّها، والرسائل الواردة تمر عبر منصة المعاينة.
class PreviewPanel extends StatefulWidget {
  const PreviewPanel({
    super.key,
    required this.pageId,
    required this.sessionId,
    required this.zoom,
    this.device = PreviewDevice.phone,
    required this.onElementSelected,
    required this.onPreviewReady,
    required this.onPreviewError,
    required this.onPropertyUpdated,
    required this.onTreeUpdated,
    this.outboundMessageType,
    this.outboundPayload,
    this.outboundMessageId,
  });

  final String pageId;
  final String? sessionId;
  final double zoom;

  /// الجهاز المعروض — يحكم عرض الإطار وارتفاعه لا رقم مخفي.
  final PreviewDevice device;
  final void Function(dynamic data) onElementSelected;
  final void Function(dynamic data) onPreviewReady;
  final void Function(dynamic data) onPreviewError;
  final void Function(dynamic data) onPropertyUpdated;
  final void Function(dynamic data) onTreeUpdated;

  /// آخر رسالة صادرة ترسلها الـ Cubit عبر الحالة.
  final VisualEditorMessageType? outboundMessageType;
  final Map<String, dynamic>? outboundPayload;
  final String? outboundMessageId;

  @override
  State<PreviewPanel> createState() => _PreviewPanelState();
}

class _PreviewPanelState extends State<PreviewPanel> {
  static const _iframeViewType = 'visual-editor-preview-iframe';
  static bool _viewRegistered = false;

  /// origin لوحة الأدمن: الأب المتوقع للمعاينة في الاتجاهين.
  String? _parentOrigin;

  /// عنوان URL لـ Customer Flutter Web في وضع المعاينة.
  ///
  /// الهدف يُقرأ من إعداد بيئة التشغيل (flutter build/run مع
  /// `--dart-define=PREVIEW_BASE_URL=...`)، ومنه تُبنى معلمات الجلسة:
  /// `mode=preview` يفعّل نقطة الدخول، و`sessionId` يربط الجلسة، و
  /// `parentOrigin` هو الأصل الوحيد الذي يثق به الطرفان.
  static String _buildPreviewUrl(String? sessionId, String? parentOrigin) {
    const baseUrl = String.fromEnvironment(
      'PREVIEW_BASE_URL',
      defaultValue: 'http://localhost:5000',
    );
    final params = {
      'mode': 'preview',
      'sessionId': ?sessionId,
      'parentOrigin': ?parentOrigin,
    };
    return '$baseUrl/?${Uri(queryParameters: params).query}';
  }

  @override
  void initState() {
    super.initState();
    if (kIsWeb && !_viewRegistered) {
      _parentOrigin = Uri.base.origin;
      _registerIframeView();
      _viewRegistered = true;
    }
  }

  void _registerIframeView() {
    preview_platform.registerPreviewView(
      viewType: _iframeViewType,
      url: _buildPreviewUrl(widget.sessionId, _parentOrigin),
      sessionId: widget.sessionId,
      parentOrigin: _parentOrigin,
      onElementSelected: widget.onElementSelected,
      onPreviewReady: widget.onPreviewReady,
      onPreviewError: widget.onPreviewError,
      onPropertyUpdated: widget.onPropertyUpdated,
      onTreeUpdated: widget.onTreeUpdated,
    );
  }

  @override
  void didUpdateWidget(PreviewPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _deliverOutbound();
  }

  /// رسالة صادرة واحدة لكل معرّف: اللقطة نفسها قد تُبني عدة مرات دون أن
  /// تعني إرسالًا جديدًا.
  void _deliverOutbound() {
    final messageId = widget.outboundMessageId;
    final type = widget.outboundMessageType;
    final payload = widget.outboundPayload;
    if (messageId == null || type == null || payload == null) return;
    if (!kIsWeb) return;
    preview_platform.sendOutboundMessage(
      viewType: _iframeViewType,
      type: type,
      payload: payload,
      sessionId: widget.sessionId ?? '',
      messageId: messageId,
      parentOrigin: _parentOrigin,
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return _PreviewFrame(
      zoom: widget.zoom,
      device: widget.device,
      dark: dark,
      child: kIsWeb ? _buildWebPreview() : _buildNonWebPlaceholder(context),
    );
  }

  Widget _buildWebPreview() {
    return preview_platform.buildPreviewView(viewType: _iframeViewType);
  }

  Widget _buildNonWebPlaceholder(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark ? AppColor.darkTextSecondary : AppColor.adminMuted;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AppIcons.smartPhone01, size: 48, color: muted),
          const SizedBox(height: AppSpacing.md),
          Text(
            S.visualEditorPreviewWebOnly,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: muted,
              fontSize: AppFontSizes.size13,
              height: AppTextHeights.line1_5,
            ),
          ),
        ],
      ),
    );
  }
}

/// الإطار المرئي حول المعاينة: خلفية محايدة + ظل + تحكم بالتكبير.
class _PreviewFrame extends StatelessWidget {
  const _PreviewFrame({
    required this.zoom,
    required this.device,
    required this.dark,
    required this.child,
  });

  final double zoom;
  final PreviewDevice device;
  final bool dark;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: dark ? AppColor.darkBackground : AppColor.lightGreyColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      alignment: Alignment.center,
      child: SingleChildScrollView(
        // جهاز أكبر من اللوحة أو تكبير فوق الواحد يُقلّب لا يُقتطع.
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Transform.scale(
              scale: zoom,
              child: Container(
                width: device.width,
                height: device.height,
                decoration: BoxDecoration(
                  color: AppColor.deviceChrome,
                  borderRadius: BorderRadius.circular(AppRadius.phoneBody),
                  boxShadow: [
                    BoxShadow(
                      color: AppColor.black20,
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.phoneScreen),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
