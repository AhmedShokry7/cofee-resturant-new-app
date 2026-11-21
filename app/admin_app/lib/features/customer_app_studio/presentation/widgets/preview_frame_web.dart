import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:material_ui/material_ui.dart';
import 'package:web/web.dart' as web;

import '../../data/models/preview_protocol.dart';

class StudioPreviewFrame extends StatelessWidget {
  static const publishedAppUrl = String.fromEnvironment(
    'STUDIO_PREVIEW_URL',
    defaultValue:
        'https://ahmedshokry7.github.io/cofee-resturant-new-app/preview/',
  );

  const StudioPreviewFrame({
    super.key,
    required this.pageId,
    required this.designDocument,
    required this.selectedElementId,
    required this.darkMode,
    required this.width,
    this.runtimeReleaseAvailable = true,
    this.onStatusChanged,
  });

  final String pageId;
  final Map<String, Object?> designDocument;
  final String? selectedElementId;
  final bool darkMode;
  final int width;
  final bool runtimeReleaseAvailable;
  final ValueChanged<String>? onStatusChanged;

  @override
  Widget build(BuildContext context) {
    if (publishedAppUrl.isEmpty || !runtimeReleaseAvailable) {
      return const _PreviewLockedPanel();
    }
    return _ActivePreviewFrame(
      pageId: pageId,
      designDocument: designDocument,
      selectedElementId: selectedElementId,
      darkMode: darkMode,
      width: width,
      onStatusChanged: onStatusChanged,
    );
  }
}

class _PreviewLockedPanel extends StatelessWidget {
  const _PreviewLockedPanel();

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.lock_outline, size: 34, color: Color(0xffA76B10)),
              SizedBox(height: 12),
              Text(
                'Customer runtime preview is locked',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 8),
              Text(
                'Studio Preview is not configured. Build and release the isolated customer runtime at the Studio Preview path before enabling live preview.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ActivePreviewFrame extends StatefulWidget {
  const _ActivePreviewFrame({
    required this.pageId,
    required this.designDocument,
    required this.selectedElementId,
    required this.darkMode,
    required this.width,
    this.onStatusChanged,
  });

  final String pageId;
  final Map<String, Object?> designDocument;
  final String? selectedElementId;
  final bool darkMode;
  final int width;
  final ValueChanged<String>? onStatusChanged;

  @override
  State<_ActivePreviewFrame> createState() => _ActivePreviewFrameState();
}

class _ActivePreviewFrameState extends State<_ActivePreviewFrame> {
  static int _nextView = 0;
  static const _baseUrl = StudioPreviewFrame.publishedAppUrl;
  late final String _viewType;
  late final String _sessionId;
  late final Uri _runtimeUri;
  late final String _expectedOrigin;
  web.HTMLIFrameElement? _frame;
  JSFunction? _listener;
  Timer? _handshakeTimer;
  bool _ready = false;
  String? _pendingDocumentMessageId;
  static const _noHandshakeDetails =
      'The Customer App is displayed using the Visual Editor preview URL '
      'parameters (mode, sessionId and parentOrigin). To enable editing, its '
      'bridge must return PREVIEW_READY from this iframe with the matching '
      'origin and session, then acknowledge the design document.';
  String _status = 'Loading customer app';

  @override
  void initState() {
    super.initState();
    _sessionId = StudioPreviewSession().id;
    final base = Uri.parse(_baseUrl);
    _expectedOrigin = base.origin;
    _runtimeUri = base.replace(
      queryParameters: <String, String>{
        'mode': 'preview',
        'sessionId': _sessionId,
        'parentOrigin': web.window.location.origin,
        'language': 'ar',
        'theme': widget.darkMode ? 'dark' : 'light',
        // The isolated entry point uses this marker; legacy preview builds
        // ignore it while rendering, as they did for the Visual Editor.
        'previewSafety': '1',
      },
    );
    _viewType = 'studio-customer-preview-${_nextView++}';
    _handshakeTimer = Timer(const Duration(seconds: 15), () {
      if (mounted && !_ready) {
        _setStatus('Disconnected: PREVIEW_READY not received');
      }
    });
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final frame = web.HTMLIFrameElement()
        ..src = _runtimeUri.toString()
        ..title = 'Customer app preview'
        ..referrerPolicy = 'no-referrer'
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.pointerEvents = 'none';
      frame.onLoad.listen((_) {
        if (mounted && !_ready) {
          _setStatus('Customer app loaded; waiting for PREVIEW_READY');
        }
      });
      _frame = frame;
      return frame;
    });
    void handle(web.MessageEvent event) {
      final frame = _frame;
      if (frame == null ||
          event.source != frame.contentWindow ||
          event.origin != _expectedOrigin) {
        return;
      }
      final message = StudioPreviewMessage.decode(
        event.data.dartify(),
        sessionId: _sessionId,
      );
      if (message == null) return;
      switch (message.type) {
        case StudioPreviewMessageType.previewReady:
          _ready = true;
          _handshakeTimer?.cancel();
          _sendDocument(initial: true);
        case StudioPreviewMessageType.previewError:
          _setStatus('Preview error: ${message.payload['error'] ?? 'unknown'}');
        case StudioPreviewMessageType.propertyUpdated:
          if (message.payload['requestId'] == _pendingDocumentMessageId) {
            _setStatus(
              message.payload['success'] == true
                  ? 'Connected: design draft applied'
                  : 'Preview error: ${message.payload['error'] ?? 'design apply failed'}',
            );
          } else if (message.payload['success'] != true) {
            _setStatus(
              'Preview error: ${message.payload['error'] ?? 'apply_failed'}',
            );
          }
        default:
          break;
      }
    }

    _listener = handle.toJS;
    web.window.addEventListener('message', _listener!);
  }

  @override
  void didUpdateWidget(covariant _ActivePreviewFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_ready) return;
    if (widget.pageId != oldWidget.pageId) {
      _send(StudioPreviewMessageType.loadPage, <String, Object?>{
        'pageId': widget.pageId,
      });
    }
    if (widget.designDocument != oldWidget.designDocument ||
        widget.pageId == 'home') {
      _sendDocument();
    }
    if (widget.selectedElementId != oldWidget.selectedElementId &&
        widget.selectedElementId != null) {
      _send(StudioPreviewMessageType.selectElement, <String, Object?>{
        'componentId': widget.selectedElementId,
      });
    }
    if (widget.darkMode != oldWidget.darkMode) {
      _send(StudioPreviewMessageType.setThemeMode, <String, Object?>{
        'mode': widget.darkMode ? 'dark' : 'light',
      });
    }
  }

  void _sendDocument({bool initial = false}) {
    final messageId = _send(
      initial
          ? StudioPreviewMessageType.previewInitialize
          : StudioPreviewMessageType.applyDesignConfig,
      <String, Object?>{
        'pageId': widget.pageId,
        'designDocument': widget.designDocument,
        'previewLanguage': 'ar',
        'previewThemeMode': widget.darkMode ? 'dark' : 'light',
      },
    );
    if (messageId == null) return;
    _pendingDocumentMessageId = messageId;
    _setStatus('Bridge connected; applying design draft');
    _send(StudioPreviewMessageType.setInteractiveMode, const <String, Object?>{
      'enabled': false,
    });
  }

  String? _send(StudioPreviewMessageType type, Map<String, Object?> payload) {
    if (!_ready && type != StudioPreviewMessageType.previewInitialize) {
      return null;
    }
    final target = _frame?.contentWindow;
    if (target == null) return null;
    final message = StudioPreviewMessage(
      sessionId: _sessionId,
      type: type,
      payload: payload,
      messageId: DateTime.now().microsecondsSinceEpoch.toString(),
    );
    target.postMessage(message.toJson().jsify()!, _expectedOrigin.toJS);
    return message.messageId;
  }

  void _setStatus(String value) {
    if (!mounted) return;
    setState(() => _status = value);
    widget.onStatusChanged?.call(value);
  }

  @override
  void dispose() {
    _handshakeTimer?.cancel();
    if (_listener != null) {
      web.window.removeEventListener('message', _listener!);
    }
    _frame?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.centerLeft,
        color: Colors.white,
        child: Row(
          children: [
            Icon(
              _ready ? Icons.check_circle : Icons.sync,
              size: 14,
              color: _ready ? const Color(0xff267660) : const Color(0xffA76B10),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Tooltip(
                message: _ready ? _status : '$_status\n\n$_noHandshakeDetails',
                child: Text(
                  _status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ),
            Text('${widget.width}px', style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
      Expanded(child: HtmlElementView(viewType: _viewType)),
    ],
  );
}
