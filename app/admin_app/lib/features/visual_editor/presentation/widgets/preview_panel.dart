import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/features/visual_editor/domain/design_contract.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/visual_editor/domain/preview_protocol.dart';
import 'package:admin_app/features/visual_editor/domain/visual_editor_models.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/native_design_preview.dart';

import 'preview_panel_stub.dart'
    if (dart.library.js_interop) 'preview_panel_web.dart'
    if (dart.library.io) 'preview_panel_windows.dart'
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
    this.components = const [],
    this.theme = DesignTheme.none,
    this.selectedComponentId,
    this.reloadToken = 0,
    this.onConnectionChanged,
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

  /// مكوّنات الصفحة الحالية لرسم المعاينة الأصلية على غير الويب.
  final List<EditableComponent> components;

  /// طبقة الشكل الحالية للمعاينة الأصلية.
  final DesignTheme theme;

  /// المكوّن المحدد — يُبرز في المعاينة الأصلية.
  final String? selectedComponentId;

  /// يرتفع بمقدار واحد عند طلب إعادة تحميل المعاينة (زر Reload أو ساعة
  /// الانقطاع) — التغيّر بينه وبين القديم هو الإشارة الوحيدة.
  final int reloadToken;

  /// كل انتقال في حالة قناة المعاينة يُبلّغ به المالك (الـ Cubit) ليصل
  /// للمؤشر والرسالة التشخيصية.
  final void Function(PreviewConnection connection, String? reason)?
      onConnectionChanged;

  @override
  State<PreviewPanel> createState() => _PreviewPanelState();
}

class _PreviewPanelState extends State<PreviewPanel> {
  static const _iframeViewType = 'visual-editor-preview-iframe';
  static bool _viewRegistered = false;

  /// origin لوحة الأدمن: الأب المتوقع للمعاينة في الاتجاهين.
  String? _parentOrigin;

  /// ساعة الانقطاع: بلا PREVIEW_READY خلال مهلة تعيد المحاولة تلقائيًا.
  Timer? _watchdog;
  int _autoReloads = 0;
  static const int _maxAutoReloads = 3;
  // أول إقلاع لتطبيق العميل في وضع debug يحمّل آلاف وحدات DDC وقد يتجاوز
  // الدقيقة — إقلاع أسرع من ذلك يُقتل بالساعة قبل أن يعلم جاهزيته. المحاولات
  // اللاحقة أقصر لأن الوحدات مخبّأة.
  static const Duration _firstWatchdog = Duration(seconds: 90);
  static const Duration _retryWatchdog = Duration(seconds: 30);

  /// حالة القناة للغطاء المرئي فوق الإطار، وآخر رسالة تشخيص.
  final ValueNotifier<PreviewConnection> _connection =
      ValueNotifier(PreviewConnection.connecting);
  String? _statusMessage;

  /// آخر رسالة صادرة مُرسلة فعليًا — إعادة البناء المتكرر للوحة لا يعني
  /// رسالة جديدة، والمعرّف نفسه يُرسل مرة واحدة لا في كل إطار.
  String? _lastSentMessageId;

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
    if (preview_platform.supportsLiveWebview) {
      if (kIsWeb) {
        _parentOrigin = Uri.base.origin;
      } else {
        // داخل WebView2 لا يوجد أب حقيقي: origin العميل نفسه هو مصدر
        // الرسائل في الاتجاهين، فنمرّه ليتحقق جسر العميل منه كما على الويب.
        _parentOrigin = previewOriginOf(
          _buildPreviewUrl(widget.sessionId, null),
        );
      }
      if (!_viewRegistered) {
        _registerIframeView();
        _viewRegistered = true;
      }
      _armWatchdog(first: true);
    } else {
      // المعاينة الأصلية ترسم من الحالة مباشرة — القناة حيّة بلا إطار.
      widget.onConnectionChanged?.call(PreviewConnection.connected, null);
    }
  }

  void _armWatchdog({bool first = false}) {
    if (!preview_platform.supportsLiveWebview) return;
    _watchdog?.cancel();
    _watchdog = Timer(
      first ? _firstWatchdog : _retryWatchdog,
      _onWatchdogExpired,
    );
  }

  /// بلا جاهزية خلال المهلة: محاولتان تلقائيّتان بإعادة تحميل الإطار ثم
  /// حالة Error برسالة مفهومة — بدل شاشة بيضاء صامتة.
  void _onWatchdogExpired() {
    if (!mounted || !preview_platform.supportsLiveWebview) return;
    if (_autoReloads >= _maxAutoReloads) {
      widget.onConnectionChanged?.call(
        PreviewConnection.error,
        'لم تستجب المعاينة بعد عدة محاولات — تأكد أن تطبيق العميل يعمل '
        'على منفذ المعاينة ثم اضغط إعادة التحميل',
      );
      return;
    }
    _autoReloads++;
    widget.onConnectionChanged?.call(
      PreviewConnection.connecting,
      'المعاينة لم تستجب — إعادة اتصال تلقائية ($_autoReloads/$_maxAutoReloads)',
    );
    preview_platform.reloadPreviewView(
      viewType: _iframeViewType,
      url: _buildPreviewUrl(widget.sessionId, _parentOrigin),
    );
    _armWatchdog();
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
      onConnectionState: (connection, reason) {
        // الغطاء والمؤشر يقرآن نفس الحالة: تحديث موحّد بلا مسارين.
        if (_connection.value != connection) {
          _statusMessage = reason;
          _connection.value = connection;
        } else if (reason != null) {
          _statusMessage = reason;
          _connection.value = connection;
        }
        if (connection == PreviewConnection.connected) {
          // وصلت إشارة حياة: الساعة تُفصل والمحاولات تعود صفر.
          _watchdog?.cancel();
          _autoReloads = 0;
        }
        widget.onConnectionChanged?.call(connection, reason);
      },
    );
  }

  @override
  void didUpdateWidget(PreviewPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reloadToken != oldWidget.reloadToken) {
      if (preview_platform.supportsLiveWebview) {
        _autoReloads = 0;
        _reloadManually();
      }
    }
    _deliverOutbound();
  }

  /// إعادة التحميل بيد الموظف (زر Reload) — الطابور يُحفظ فآخر مستند
  /// يعود أول ما تعلن المعاينة الجديدة جاهزيتها.
  void _reloadManually() {
    _statusMessage = 'إعادة تحميل المعاينة…';
    _connection.value = PreviewConnection.connecting;
    preview_platform.reloadPreviewView(
      viewType: _iframeViewType,
      url: _buildPreviewUrl(widget.sessionId, _parentOrigin),
    );
    _armWatchdog();
  }

  @override
  void dispose() {
    _watchdog?.cancel();
    _connection.dispose();
    super.dispose();
  }

  /// رسالة صادرة واحدة لكل معرّف: اللقطة نفسها قد تُبني عدة مرات دون أن
  /// تعني إرسالًا جديدًا.
  /// الإطار مع غطاء الحالة: أثناء الاتصال أو عند الخطأ يظهر تفسير مفهوم
  /// فوق الإطار بدل شاشة بيضاء صامتة، ويختفي أول ما تصل المعاينة.
  Widget _buildWebPreviewWithStatus(bool dark) {
    return Stack(
      fit: StackFit.expand,
      children: [
        preview_platform.buildPreviewView(viewType: _iframeViewType),
        ValueListenableBuilder<PreviewConnection>(
          valueListenable: _connection,
          builder: (context, connection, _) {
            if (connection == PreviewConnection.connected) {
              return const SizedBox.shrink();
            }
            return _PreviewStatusOverlay(
              connection: connection,
              message: _statusMessage,
              dark: dark,
              onRetry: _reloadManually,
            );
          },
        ),
      ],
    );
  }

  void _deliverOutbound() {
    final messageId = widget.outboundMessageId;
    final type = widget.outboundMessageType;
    final payload = widget.outboundPayload;
    if (messageId == null || type == null || payload == null) return;
    if (!preview_platform.supportsLiveWebview) return;
    if (messageId == _lastSentMessageId) return;
    _lastSentMessageId = messageId;
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
      child: preview_platform.supportsLiveWebview
          ? _buildWebPreviewWithStatus(dark)
          : _buildNativePreview(),
    );
  }


  /// على غير الويب لا يوجد iframe: يرسم المحرّر مستند التصميم نفسه بمكوّنات
  /// Flutter — نفس التسلسل والخصائص وطبقة الشكل، والنقر يحدد العنصر.
  Widget _buildNativePreview() {
    return NativeDesignPreview(
      components: widget.components,
      theme: widget.theme,
      selectedComponentId: widget.selectedComponentId,
      onElementSelected: (componentId) =>
          widget.onElementSelected({'componentId': componentId}),
    );
  }
}

/// الإطار المرئي حول المعاينة: خلفية محايدة + ظل + تحكم بالتكبير.
///
/// الإطار يُضبط تلقائيًا ليملأ المساحة المتاحة دون قص: نحسب نسبة
/// الملاءمة من أبعاد الجهاز مقابل المساحة الفعلية، ثم نضربها في تكبير
/// الموظف. عند التكبير 1 تبقى شاشة التطبيق كاملة ظاهرة ومتوسطة دومًا،
/// وحجم الجهاز الأكبر من اللوحة يُصغّر تلقائيًا بدل التمرير إليه.
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          // المساحة الفعلية للوحة بعد الحواف الداخلية.
          final available = Size(
            (constraints.maxWidth - AppSpacing.xxl * 2).clamp(1.0, 100000.0),
            (constraints.maxHeight - AppSpacing.xxl * 2).clamp(1.0, 100000.0),
          );
          // نسبة الملاءمة: أصغر عامل يجعل الإطار كاملًا داخل المساحة.
          final fitScale = math.min(
            available.width / device.width,
            available.height / device.height,
          );
          final scale = math.max(fitScale * zoom, 0.05);
          final frameWidth = device.width * scale;
          final frameHeight = device.height * scale;
          // الإطار نفسه بحجم الجهاز الطبيعي، موسّطًا ومصغّرًا بالتحويل —
          // OverflowBox يُبقي قيود الرسم الطبيعية داخل بصمة الحجم المرئي.
          Widget frame = SizedBox(
            width: frameWidth,
            height: frameHeight,
            child: OverflowBox(
              // القيود الدنيا صفر حتى لا يرث الأب الحجم المُكيّف كحد أدنى
              // فوق أبعاد جهاز أصغر — كان يكسر التخطيط عند التكبير > 1
              // مع الأجهزة الأصغر من الموبايل الافتراضي.
              minWidth: 0,
              minHeight: 0,
              maxWidth: device.width,
              maxHeight: device.height,
              child: Transform.scale(
                scale: scale,
                alignment: Alignment.center,
                child: Container(
                  width: device.width,
                  height: device.height,
                  decoration: BoxDecoration(
                    color: AppColor.deviceChrome,
                    borderRadius:
                        BorderRadius.circular(AppRadius.phoneBody),
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
                      borderRadius:
                          BorderRadius.circular(AppRadius.phoneScreen),
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          );
          final padded = Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: frame,
          );
          // التمركز الحقيقي في المنتصف: لا تمرير ما دام الإطار يسع
          // المساحة — داخل التمرير يفقد Center معناه ويتموضع المحتوى
          // في أول الاتجاه (يمين الشاشة في RTL).
          if (frameWidth <= available.width &&
              frameHeight <= available.height) {
            return Center(child: padded);
          }
          // التكبير فوق الملاءمة فقط يفتح تمرير الإطار؛ لا يُقتطع أبدًا.
          return SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: padded,
            ),
          );
        },
      ),
    );
  }
}

/// غطاء حالة المعاينة فوق الإطار: جارٍ الاتصال/انقطاع/خطأ برسالة مفهومة
/// وزر إعادة — لا شاشة بيضاء صامتة مهما كان العطل.
class _PreviewStatusOverlay extends StatelessWidget {
  const _PreviewStatusOverlay({
    required this.connection,
    required this.message,
    required this.dark,
    required this.onRetry,
  });

  final PreviewConnection connection;
  final String? message;
  final bool dark;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final muted = dark ? AppColor.darkTextSecondary : AppColor.adminMuted;
    final accent = dark ? AppColor.secondaryColor : AppColor.adminAccent;
    final (icon, title) = switch (connection) {
      PreviewConnection.connecting => (Icons.hourglass_top, 'جارٍ تحميل تطبيق العميل…'),
      PreviewConnection.disconnected => (Icons.cloud_off, 'انقطع الاتصال بالمعاينة'),
      PreviewConnection.error => (Icons.error_outline, 'تعذر إكمال الاتصال بالمعاينة'),
      PreviewConnection.connected => (Icons.check_circle, ''),
    };
    return Container(
      color: dark
          ? AppColor.darkBackground.withAlpha(230)
          : AppColor.whiteColor.withAlpha(240),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (connection == PreviewConnection.connecting)
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          else
            Icon(icon, size: 40, color: muted),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppFontSizes.size13,
              fontWeight: AppFontWeights.semiBold,
              color: dark ? AppColor.darkText : AppColor.adminBody,
            ),
          ),
          if (message != null && message!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppFontSizes.size11,
                height: AppTextHeights.line1_5,
                color: muted,
              ),
            ),
          ],
          if (connection != PreviewConnection.connecting) ...[
            const SizedBox(height: AppSpacing.lg),
            TextButton.icon(
              onPressed: onRetry,
              icon: Icon(Icons.refresh, size: 16, color: accent),
              label: Text(
                'إعادة تحميل المعاينة',
                style: TextStyle(
                  fontSize: AppFontSizes.size12,
                  color: accent,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
