// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

class PreviewSurface extends StatefulWidget {
  const PreviewSurface({super.key, required this.url});

  final String url;

  @override
  State<PreviewSurface> createState() => _PreviewSurfaceState();
}

class _PreviewSurfaceState extends State<PreviewSurface> {
  static const String _viewType = 'customer-preview-iframe';
  static bool _registered = false;
  static html.IFrameElement? _iframe;
  static String? _pendingUrl;

  @override
  void initState() {
    super.initState();
    if (!_registered) {
      ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
        final element = html.IFrameElement()
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%';
        _iframe = element;
        if (_pendingUrl != null) element.src = _pendingUrl!;
        return element;
      });
      _registered = true;
    }
    _pendingUrl = widget.url;
    if (_iframe != null) _iframe!.src = widget.url;
  }

  @override
  void didUpdateWidget(covariant PreviewSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _pendingUrl = widget.url;
      if (_iframe != null) _iframe!.src = widget.url;
    }
  }

  @override
  Widget build(BuildContext context) {
    return const HtmlElementView(viewType: _viewType);
  }
}
