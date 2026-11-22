// Non-web stub — no iframe API available on native platforms.

import 'package:flutter/widgets.dart';

import 'package:admin_app/features/visual_editor/domain/preview_protocol.dart';
import 'package:admin_app/features/visual_editor/domain/visual_editor_models.dart';

/// لا إطار حي على المنصات الأصلية بلا WebView2 — الرسم الأصلي هو المعاينة.
const bool supportsLiveWebview = false;

String defaultPreviewUrl() => 'https://ahmedshokry7.github.io/cofee-resturant-new-app/preview/';
void disposePreviewView(String viewType) {
}

void registerPreviewView({
  required String viewType,
  required String url,
  required String? sessionId,
  required String? parentOrigin,
  required void Function(dynamic) onElementSelected,
  required void Function(dynamic) onPreviewReady,
  required void Function(dynamic) onPreviewError,
  required void Function(dynamic) onPropertyUpdated,
  required void Function(dynamic) onTreeUpdated,
  void Function(PreviewConnection connection, String? reason)?
  onConnectionState,
}) {}

Widget buildPreviewView({required String viewType}) => const SizedBox.shrink();

void sendOutboundMessage({
  required String viewType,
  required VisualEditorMessageType type,
  required Map<String, dynamic> payload,
  required String sessionId,
  required String messageId,
  required String? parentOrigin,
}) {}

/// لا إطار على المنصات الأصلية — المعاينة الأصلية ترسم من الحالة مباشرة.
void reloadPreviewView({required String viewType, required String url}) {}

/// التحجيم يُطبّقه رسم Flutter نفسه هنا — لا عنصر iframe يُعدّل بـCSS.
void applyPreviewScale({
  required String viewType,
  required double scale,
  required double width,
  required double height,
}) {}
