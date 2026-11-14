import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:admin_app/features/visual_editor/domain/design_contract.dart';
import 'package:admin_app/features/visual_editor/domain/design_document_codec.dart';
import 'package:admin_app/features/visual_editor/domain/visual_editor_models.dart';

/// عقد مخزن المحرر المرئي.
///
/// كل القراءة والكتابة تمر عبر الـ RPCs المعتمدة في migration 226، لا عبر
/// جدول مباشر: كل دالة تفحص `identity.is_staff()` ثم صلاحية
/// `design.edit` أو `design.publish`، وتكتب audit، وتدقق المستند قبل النشر
/// بـ `core.app_design_is_valid`، وتكتب كل إصدار في `core.app_design_versions`
/// داخل معاملة واحدة. تجاوز هذه الطبقة يعني نشرًا بلا تدقيق ولا سجل.
abstract class VisualEditorRepository {
  /// قراءة المسودة المحفوظة؛ تعيد null إن لم توجد.
  Future<EditorDraft?> loadDraft();

  /// حفظ مسودة عبر `admin_save_app_design_draft`.
  Future<DateTime> saveDraft(
    Map<String, List<EditableComponent>> componentsByPage, {
    DesignTheme theme = DesignTheme.none,
  });

  /// نشر الإصدار عبر `admin_publish_app_design` — ترجع بيانات الإصدار.
  Future<PublishedVersionInfo> publishDesign(
    Map<String, dynamic> designDocument, {
    String? note,
  });

  /// تاريخ الإصدارات بترتيبها، بلا مستندات (مصمم كذلك في 226).
  Future<List<PublishedVersionInfo>> listVersions({int limit = 30});

  /// مستند إصدار مخزّن.
  Future<Map<String, dynamic>?> getVersionDocument(String versionId);

  /// استرجاع إصدار سابق — إصدار جديد يحمل ملفّ القديم (لا محو في السجل).
  Future<PublishedVersionInfo> restoreVersion(String versionId);

  /// المفتاح الذي يقرؤه Customer App (`SupabaseDesignRepository` هناك).
  static const String publishedKey = 'app_design_published';
}

/// نموذج المسودة المحفوظة.
class EditorDraft {
  const EditorDraft({
    required this.componentsByPage,
    required this.theme,
    required this.savedAt,
  });

  final Map<String, List<EditableComponent>> componentsByPage;
  final DesignTheme theme;
  final DateTime savedAt;
}

/// بيانات إصدار منشور كما تعيد الـ RPCs.
class PublishedVersionInfo {
  const PublishedVersionInfo({
    required this.id,
    required this.versionNumber,
    required this.publishedAt,
    required this.schemaVersion,
    this.note,
  });

  final String id;
  final int versionNumber;
  final DateTime publishedAt;
  final int schemaVersion;
  final String? note;

  static PublishedVersionInfo? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final number = raw['version_number'];
    if (id is! String || number is! num) return null;
    return PublishedVersionInfo(
      id: id,
      versionNumber: number.round(),
      publishedAt: DateTime.tryParse(
            raw['published_at']?.toString() ?? '',
          ) ??
          DateTime.now(),
      schemaVersion: raw['schema_version'] is num
          ? (raw['schema_version'] as num).round()
          : 0,
      note: raw['note'] is String ? raw['note'] as String : null,
    );
  }
}

/// تنفيذ Supabase للمستودع فوق الـ RPCs.
class SupabaseVisualEditorRepository implements VisualEditorRepository {
  SupabaseVisualEditorRepository({SupabaseClient? client})
      : _clientOverride = client;

  final SupabaseClient? _clientOverride;

  SupabaseClient? get _client {
    try {
      return _clientOverride ?? Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  Object? _rpc(
    String function,
    Map<String, dynamic> params,
  ) {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase غير مهيأ للمحرر المرئي');
    }
    return client.rpc(function, params: params);
  }

  @override
  Future<EditorDraft?> loadDraft() async {
    final raw = _rpc('admin_get_app_design', {'p_slot': 'draft'});
    final value = await raw;
    if (value == null) return null;
    final document = jsonDecode(jsonEncode(value));
    return EditorDraft(
      componentsByPage: DesignDocumentCodec.parseDocument(document),
      theme: DesignDocumentCodec.themeOf(document),
      savedAt: DateTime.now(),
    );
  }

  @override
  Future<DateTime> saveDraft(
    Map<String, List<EditableComponent>> componentsByPage, {
    DesignTheme theme = DesignTheme.none,
  }) async {
    final document = DesignDocumentCodec.document(
      componentsByPage,
      theme: theme,
    );
    final saved = await _rpc(
      'admin_save_app_design_draft',
      {'p_document': document},
    );
    final savedAt = saved is Map ? saved['saved_at']?.toString() : null;
    return DateTime.tryParse(savedAt ?? '') ?? DateTime.now();
  }

  @override
  Future<PublishedVersionInfo> publishDesign(
    Map<String, dynamic> designDocument, {
    String? note,
  }) async {
    final version = await _rpc(
      'admin_publish_app_design',
      {
        'p_document': designDocument,
        'p_note': note,
      },
    );
    final info = PublishedVersionInfo.fromJson(version);
    if (info == null) {
      throw StateError('إجابة نشر غير مفهومة من admin_publish_app_design');
    }
    return info;
  }

  @override
  Future<List<PublishedVersionInfo>> listVersions({int limit = 30}) async {
    final raw = await _rpc(
      'admin_list_app_design_versions',
      {'p_limit': limit.clamp(1, 100)},
    );
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (PublishedVersionInfo.fromJson(item) case PublishedVersionInfo info)
          info,
    ];
  }

  @override
  Future<Map<String, dynamic>?> getVersionDocument(String versionId) async {
    final raw = await _rpc(
      'admin_get_app_design_version',
      {'p_version_id': versionId},
    );
    if (raw == null) return null;
    return jsonDecode(jsonEncode(raw)) as Map<String, dynamic>;
  }

  @override
  Future<PublishedVersionInfo> restoreVersion(String versionId) async {
    final version = await _rpc(
      'admin_restore_app_design_version',
      {'p_version_id': versionId},
    );
    final info = PublishedVersionInfo.fromJson(version);
    if (info == null) {
      throw StateError('إجابة استرجاع غير مفهومة من admin_restore_app_design_version');
    }
    return info;
  }
}
