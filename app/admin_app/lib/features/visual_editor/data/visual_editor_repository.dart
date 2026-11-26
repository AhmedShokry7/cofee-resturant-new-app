import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:admin_app/features/visual_editor/domain/design_contract.dart';
import 'package:admin_app/features/visual_editor/domain/design_document_codec.dart';
import 'package:admin_app/features/visual_editor/domain/design_document_merge.dart';
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

  /// المسودة الخام كما جاءت من القاعدة — لطبقة الدمج لا للعرض.
  Future<Map<String, dynamic>?> loadDraftDocument() async =>
      throw UnimplementedError();

  /// المسودّ المنشور الخام — يبني عليه نشر الصفحات.
  Future<Map<String, dynamic>?> loadPublishedDocument() async =>
      throw UnimplementedError();

  /// حفظ مسودة عبر `admin_save_app_design_draft`.
  ///
  /// حفظ مدمج على مستوى الصفحة: قراءة حية ثم استبدال الصفحات الممرّرة
  /// فقط — صفحة محفوظة لا تُمسّ صفحات أخرى ولا ترتيبها ولا عناصرها.
  /// [knownRevisions] مراجعات الصفحات التي بُنيت عليها حالة المحرّر؛
  /// صفحة تغيّرت في القاعدة منذ التحميل ترفع [PageRevisionConflict] بدل
  /// الكتابة الصامتة فوق تعديل أحدث. [force] يجبر الحفظ فوق المراجعة
  /// الأحدث (يُستخدم فقط بعد قرار صريح من الموظف في حوار التعارض).
  Future<PageSaveResult> saveDraft(
    Map<String, List<EditableComponent>> componentsByPage, {
    DesignTheme theme = DesignTheme.none,
    Map<String, int> knownRevisions = const {},
    bool force = false,
  });

  /// التخلص من المسودة عبر `admin_discard_app_design_draft` — يمسح صف
  /// المسودة فقط؛ ما يراه الزبون لا يُلمس.
  Future<void> discardDraft();

  /// نشر الإصدار عبر `admin_publish_app_design` — ترجع بيانات الإصدار.
  Future<PublishedVersionInfo> publishDesign(
    Map<String, dynamic> designDocument, {
    String? name,
    String? note,
  });

  /// نشر صفحات محددة من آخر مسودة محفوظة.
  ///
  /// تجميع من أحدث مسودة (الصفحات المعتمدة) + أحدث منشور (ما عداها) —
  /// لا من حالة المحرر المفتوح ولا من لقطة قديمة. صفحة لم تُحفظ بعد
  /// لا تُنشر (النشر يعتمد المسودّ المحفوظ فقط). فحص المراجعة كما في
  /// [saveDraft]: صفحة غيّرها موظف آخر منذ التحميل ترفع التعارض بدل
  /// اعتماد تغيير لم يره الناشر.
  Future<PublishedVersionInfo> publishPages({
    required Set<String> pageIds,
    Map<String, int> knownRevisions = const {},
    bool force = false,
    String? name,
    String? note,
  }) async => throw UnimplementedError();

  /// تاريخ الإصدارات بترتيبها، بلا مستندات (مصمم كذلك في 226).
  Future<List<PublishedVersionInfo>> listVersions({int limit = 1000000});

  Future<void> updateVersionDetails(
    String versionId,
    String? name,
    String? note,
  ) async => throw UnimplementedError();

  Future<void> deleteVersion(String versionId) async =>
      throw UnimplementedError();

  /// مستند إصدار مخزّن.
  Future<Map<String, dynamic>?> getVersionDocument(String versionId);

  /// استرجاع إصدار سابق — إصدار جديد يحمل ملفّ القديم (لا محو في السجل).
  Future<PublishedVersionInfo> restoreVersion(String versionId);

  /// القوالب المحفوظة، الأحدث أولًا (228) — أسماء وتواريخ فقط.
  Future<List<DesignTemplateInfo>> listTemplates();

  /// مستند قالب واحد (228).
  Future<Map<String, dynamic>?> getTemplateDocument(String templateId);

  /// إنشاء قالب (id: null) أو استبدال قائم (228) — بنفس تدقيق النشر.
  Future<DesignTemplateInfo> saveTemplate({
    String? id,
    required String name,
    required Map<String, dynamic> document,
  });

  /// حذف قالب (228) — لا يلمس مسودة ولا منشورًا ولا إصدارًا.
  Future<void> deleteTemplate(String templateId);

  /// المفتاح الذي يقرؤه Customer App (`SupabaseDesignRepository` هناك).
  static const String publishedKey = 'app_design_published';
}

/// نموذج المسودة المحفوظة.
class EditorDraft {
  const EditorDraft({
    required this.componentsByPage,
    required this.theme,
    required this.savedAt,
    this.pageRevisions = const {},
  });

  final Map<String, List<EditableComponent>> componentsByPage;
  final DesignTheme theme;
  final DateTime savedAt;

  /// مراجعات الصفحات من `meta.page_revisions` في المستند المحمّل —
  /// مرجع المحرّر لكشف الكتابة فوق تعديل أحدث.
  final Map<String, int> pageRevisions;
}

/// تعارض مراجعة صفحة: القاعدة تحمل مراجعة أحدث من مرجع المحرّر.
///
/// لا تكتب ولا تنشر شيئًا عند رفعها — الحالة المحلية للمحرّر تبقى كما هي
/// والحوار يعطي الموظف القرار: تحميل نسخة القاعدة أو الإجبار.
class PageRevisionConflict implements Exception {
  const PageRevisionConflict({
    required this.pageId,
    required this.serverRevision,
    required this.knownRevision,
  });

  final String pageId;
  final int serverRevision;
  final int knownRevision;

  @override
  String toString() =>
      'PageRevisionConflict(page: $pageId, server: $serverRevision, '
      'editor: $knownRevision)';
}

/// نتيجة حفظ ناجح: المراجعات الجديدة لكل صفحة، ووقت الحفظ.
class PageSaveResult {
  const PageSaveResult({required this.savedRevisions, required this.savedAt});

  final Map<String, int> savedRevisions;
  final DateTime savedAt;
}

/// بيانات إصدار منشور كما تعيد الـ RPCs.
class PublishedVersionInfo {
  const PublishedVersionInfo({
    required this.id,
    required this.versionNumber,
    required this.publishedAt,
    required this.schemaVersion,
    this.name,
    this.note,
  });

  final String id;
  final int versionNumber;
  final DateTime publishedAt;
  final int schemaVersion;
  final String? name;
  final String? note;

  static PublishedVersionInfo? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final number = raw['version_number'];
    if (id is! String || number is! num) return null;
    return PublishedVersionInfo(
      id: id,
      versionNumber: number.round(),
      publishedAt:
          DateTime.tryParse(raw['published_at']?.toString() ?? '') ??
          DateTime.now(),
      schemaVersion: raw['schema_version'] is num
          ? (raw['schema_version'] as num).round()
          : 0,
      name: raw['name'] is String ? raw['name'] as String : null,
      note: raw['note'] is String ? raw['note'] as String : null,
    );
  }
}

/// بيانات قالب محفوظ كما تعيد الـ RPCs (228).
class DesignTemplateInfo {
  const DesignTemplateInfo({
    required this.id,
    required this.name,
    required this.schemaVersion,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final int schemaVersion;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  static DesignTemplateInfo? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final name = raw['name'];
    if (id is! String || name is! String) return null;
    return DesignTemplateInfo(
      id: id,
      name: name,
      schemaVersion: raw['schema_version'] is num
          ? (raw['schema_version'] as num).round()
          : 0,
      createdAt: DateTime.tryParse(raw['created_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(raw['updated_at']?.toString() ?? ''),
    );
  }
}

/// تنفيذ Supabase للمستودع فوق الـ RPCs.
class SupabaseVisualEditorRepository implements VisualEditorRepository {
  SupabaseVisualEditorRepository({SupabaseClient? client})
    : _clientOverride = client;

  final SupabaseClient? _clientOverride;

  /// هل RPCات 254 الذرية (الحفظ/النشر بفحص مراجعة داخل المعاملة) متوفرة
  /// في القاعدة؟ null = لم يُختبر بعد، true/false = نتيجة الفحص الأخير.
  /// غيابها لا يعطّل شيئًا — يعود المسار للدمج على القراءة عبر 226/253.
  bool? _atomicRpcSupported;
  String _loadedTheme = 'null';

  SupabaseClient? get _client {
    try {
      return _clientOverride ?? Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  Object? _rpc(String function, Map<String, dynamic> params) {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase غير مهيأ للمحرر المرئي');
    }
    return client.rpc(function, params: params);
  }

  @override
  Future<EditorDraft?> loadDraft() async {
    final document = await loadDraftDocument() ?? await loadPublishedDocument();
    _loadedTheme = jsonEncode(DesignDocumentCodec.themeOf(document).toJson());
    if (document == null) return null;
    return EditorDraft(
      componentsByPage: DesignDocumentCodec.parseDocument(document),
      theme: DesignDocumentCodec.themeOf(document),
      savedAt: DateTime.now(),
      pageRevisions: DesignDocumentMeta.pageRevisions(document),
    );
  }

  @override
  Future<Map<String, dynamic>?> loadDraftDocument() async {
    final raw = _rpc('admin_get_app_design', {'p_slot': 'draft'});
    final value = raw;
    if (value == null) return null;
    return jsonDecode(jsonEncode(value)) as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>?> loadPublishedDocument() async {
    final raw = _rpc('admin_get_app_design', {'p_slot': 'published'});
    final value = raw;
    if (value == null) return null;
    return jsonDecode(jsonEncode(value)) as Map<String, dynamic>;
  }

  @override
  Future<PageSaveResult> saveDraft(
    Map<String, List<EditableComponent>> componentsByPage, {
    DesignTheme theme = DesignTheme.none,
    Map<String, int> knownRevisions = const {},
    bool force = false,
  }) async {
    // المسار الذري أولًا (254): فحص المراجعة والكتابة في معاملة واحدة
    // بقفل صف — عميل قديم لا يستطيع بدنيًا استبدال مراجعة أحدث.
    if (_atomicRpcSupported != false) {
      try {
        return await _atomicSavePages(
          componentsByPage,
          theme: theme,
          knownRevisions: knownRevisions,
          force: force,
        );
      } on PostgrestException catch (e) {
        if (!_isMissingRpcError(e)) rethrow;
        _atomicRpcSupported = false; // القاعدة بلا 254 — دمج على القراءة.
      } on Exception catch (e) {
        if (!_isMissingRpcMessage(e.toString())) {
          rethrow;
        }
        _atomicRpcSupported = false;
      }
    }
    // المسار البديل (226/253): قراءة حية ثم فحص المراجعة في Dart ثم
    // كتابة المستند المدموج. أضعف من الذرية — تعارض بين جلستين قرأتا
    // المراجعة نفسها قد ينجو؛ يعالجه 254 فور اعتماده.
    // قراءة حية أولًا: كتابة الصفحات المدمجة تبني على آخر ما في
    // القاعدة — لا على لقطة قديمة من ذاكرة المحرّر.
    final fresh =
        await loadDraftDocument() ??
        await loadPublishedDocument() ??
        const <String, dynamic>{};
    final serverRevisions = DesignDocumentMeta.pageRevisions(fresh);
    // فحص كل الصفحات قبل أي كتابة: تعارض واحد يرفض الحفظ كله دفعة
    // واحدة، فلا يدخل الحفظ الجماعي حالة نصف مكتوبة.
    for (final pageId in componentsByPage.keys) {
      final server = serverRevisions[pageId] ?? 0;
      final known = knownRevisions[pageId] ?? 0;
      if (!force && server > known) {
        throw PageRevisionConflict(
          pageId: pageId,
          serverRevision: server,
          knownRevision: known,
        );
      }
    }
    var document = DesignDocumentMerge.withPages(
      base: fresh,
      pages: componentsByPage,
      theme: jsonEncode(theme.toJson()) == _loadedTheme ? null : theme,
    );
    final savedRevisions = <String, int>{};
    for (final pageId in componentsByPage.keys) {
      final revision = (serverRevisions[pageId] ?? 0) + 1;
      document = DesignDocumentMeta.withPageRevision(
        document,
        pageId,
        revision,
      );
      savedRevisions[pageId] = revision;
    }
    final invalid = DesignDocumentCodec.validate(document);
    if (invalid != null) {
      throw StateError('المستند غير صالح للحفظ: $invalid');
    }
    final saved = _rpc('admin_save_app_design_draft', {'p_document': document});
    _loadedTheme = jsonEncode(theme.toJson());
    final savedAt = saved is Map ? saved['saved_at']?.toString() : null;
    return PageSaveResult(
      savedRevisions: savedRevisions,
      savedAt: DateTime.tryParse(savedAt ?? '') ?? DateTime.now(),
    );
  }

  /// الحفظ الذري صفحةً صفحة عبر `admin_save_app_design_page` (254):
  /// فحص المراجعة والكتابة في معاملة واحدة بقفل صف داخل القاعدة.
  /// طبقة الشكل غير الفارغة تُكتب مع كل صفحة؛ شكل محايد (null) يرجع
  /// للمسار البديل لأن الصفرية هناك تعني مسح الطبقة لا تركها.
  Future<PageSaveResult> _atomicSavePages(
    Map<String, List<EditableComponent>> componentsByPage, {
    required DesignTheme theme,
    required Map<String, int> knownRevisions,
    required bool force,
  }) async {
    final result = await _rpcWithConflict('admin_save_app_design_pages', {
      'p_changes': [
        for (final page in componentsByPage.entries)
          {
            'entry': DesignDocumentCodec.pageEntry(page.key, page.value),
            'expected_revision': knownRevisions[page.key] ?? 0,
          },
      ],
      'p_theme': theme.toJson(),
      'p_update_theme': jsonEncode(theme.toJson()) != _loadedTheme,
      'p_force': force,
    });
    if (result is! Map || result['revisions'] is! Map) {
      throw StateError('Missing saved page revisions');
    }
    _loadedTheme = jsonEncode(theme.toJson());
    return PageSaveResult(
      savedRevisions: Map<String, int>.from(result['revisions'] as Map),
      savedAt:
          DateTime.tryParse(result['saved_at'].toString()) ?? DateTime.now(),
    );
  }

  /// RPC يحوّل خطأ تعارض المراجعة من القاعدة (40001 — رمز قابل للإعادة)
  /// إلى [PageRevisionConflict] بتفاصيله، ويمرّر ما سواه كما هو.
  Future<Object?> _rpcWithConflict(
    String function,
    Map<String, dynamic> params,
  ) async {
    try {
      return _rpc(function, params);
    } on PostgrestException catch (e) {
      final conflict = _conflictFromMessage(e.message);
      if (conflict != null) throw conflict;
      rethrow;
    }
  }

  PageRevisionConflict? _conflictFromMessage(String raw) {
    final marker = 'page revision conflict: ';
    final index = raw.indexOf(marker);
    if (index < 0) return null;
    try {
      final details = jsonDecode(raw.substring(index + marker.length));
      if (details is! Map) return null;
      return PageRevisionConflict(
        pageId: details['page']?.toString() ?? '',
        serverRevision: details['server_revision'] is num
            ? (details['server_revision'] as num).toInt()
            : 0,
        knownRevision: details['expected_revision'] is num
            ? (details['expected_revision'] as num).toInt()
            : 0,
      );
    } on FormatException {
      return null;
    }
  }

  /// هل الخطأ يعني أن RPC غير موجود في القاعدة (لم يُطبّق 254)؟
  bool _isMissingRpcError(PostgrestException e) {
    const missingCodes = {'42883', 'PGRST202', '40414'};
    if (missingCodes.contains(e.code)) return true;
    return _isMissingRpcMessage(e.message);
  }

  bool _isMissingRpcMessage(String raw) =>
      raw.contains('Could not find the function') ||
      (raw.contains('admin_save_app_design_page') &&
          raw.contains('does not exist')) ||
      (raw.contains('admin_publish_app_design_pages') &&
          raw.contains('does not exist'));

  @override
  Future<PublishedVersionInfo> publishDesign(
    Map<String, dynamic> designDocument, {
    String? name,
    String? note,
  }) async {
    final version = _rpc('admin_publish_app_design', {
      'p_document': designDocument,
      'p_name': name?.trim(),
      'p_note': note,
    });
    final info = PublishedVersionInfo.fromJson(version);
    if (info == null) {
      throw StateError('إجابة نشر غير مفهومة من admin_publish_app_design');
    }
    return info;
  }

  @override
  Future<PublishedVersionInfo> publishPages({
    required Set<String> pageIds,
    Map<String, int> knownRevisions = const {},
    bool force = false,
    String? name,
    String? note,
  }) async {
    // المسار الذري أولًا (254): قفل المسودة والمنشور بترتيب ثابت في
    // معاملة واحدة، فحص المراجعة لكل صفحة، ثم نسخ مدخل الصفحات المعتمدة
    // إلى المنشور — لا يمكن لعميل قديم أن يعتمد غير ما رأى.
    if (_atomicRpcSupported != false) {
      try {
        final version = await _rpcWithConflict(
          'admin_publish_app_design_pages',
          {
            'p_pages': [
              for (final pageId in pageIds)
                {
                  'page': pageId,
                  // الإجبار يمرّر مرجعًا فارغًا: SQL NULL يلغي فحص التعارض
                  // في الـ RPC، وغيره يفعّل الفحص الذري داخل القاعدة.
                  'expected_revision': force
                      ? null
                      : knownRevisions[pageId] ?? 0,
                },
            ],
            'p_name': name?.trim(),
            'p_note': note,
          },
        );
        final info = PublishedVersionInfo.fromJson(version);
        if (info == null) {
          throw StateError(
            'إجابة نشر غير مفهومة من admin_publish_app_design_pages',
          );
        }
        return info;
      } on PostgrestException catch (e) {
        if (!_isMissingRpcError(e)) rethrow;
        _atomicRpcSupported = false;
      } on Exception catch (e) {
        if (!_isMissingRpcMessage(e.toString())) {
          rethrow;
        }
        _atomicRpcSupported = false;
      }
    }
    // المسار البديل (226/253): تجميع على القراءة — أضعف من الذرية،
    // يعالجه 254 فور اعتماده.
    final draft = await loadDraftDocument();
    if (draft == null) {
      throw StateError('لا توجد مسودة محفوظة للنشر — احفظ أولًا ثم انشر.');
    }
    final serverRevisions = DesignDocumentMeta.pageRevisions(draft);
    // صفحة بلا مراجعة في المسودة لم تُحفظ قطّ — اعتمادها ليس ممكنًا
    // (لا يوجد ما يعتمد)؛ تفحَص التعارض فقط للصفحات المرقّمة.
    for (final pageId in pageIds) {
      final server = serverRevisions[pageId] ?? 0;
      final known = knownRevisions[pageId] ?? 0;
      if (server == 0 &&
          !(draft['pages'] as List).any(
            (p) => p is Map && p['page'] == pageId,
          )) {
        throw StateError(
          'الصفحة "$pageId" ليست محفوظة في المسودة — احفظ أولًا ثم انشر.',
        );
      }
      if (!force && server > known) {
        throw PageRevisionConflict(
          pageId: pageId,
          serverRevision: server,
          knownRevision: known,
        );
      }
    }
    final published = await loadPublishedDocument();
    final document = DesignDocumentMerge.publishedWithPages(
      publishedBase: published,
      draft: draft,
      pageIds: pageIds,
    );
    final invalid = DesignDocumentCodec.validate(document);
    if (invalid != null) {
      throw StateError('المستند غير صالح للنشر: $invalid');
    }
    return publishDesign(document, name: name, note: note);
  }

  @override
  Future<List<PublishedVersionInfo>> listVersions({int limit = 1000000}) async {
    final raw = _rpc('admin_list_app_design_versions', {
      'p_limit': limit.clamp(1, 1000000),
    });
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (PublishedVersionInfo.fromJson(item) case PublishedVersionInfo info)
          info,
    ];
  }

  @override
  Future<void> updateVersionDetails(
    String versionId,
    String? name,
    String? note,
  ) async {
    _rpc('admin_update_app_design_version_details', {
      'p_version_id': versionId,
      'p_name': name?.trim(),
      'p_note': note?.trim(),
    });
  }

  @override
  Future<void> deleteVersion(String versionId) async {
    _rpc('admin_delete_app_design_version', {'p_version_id': versionId});
  }

  @override
  Future<Map<String, dynamic>?> getVersionDocument(String versionId) async {
    final raw = _rpc('admin_get_app_design_version', {
      'p_version_id': versionId,
    });
    if (raw == null) return null;
    return jsonDecode(jsonEncode(raw)) as Map<String, dynamic>;
  }

  @override
  Future<PublishedVersionInfo> restoreVersion(String versionId) async {
    final version = _rpc('admin_restore_app_design_version', {
      'p_version_id': versionId,
    });
    final info = PublishedVersionInfo.fromJson(version);
    if (info == null) {
      throw StateError(
        'إجابة استرجاع غير مفهومة من admin_restore_app_design_version',
      );
    }
    return info;
  }

  @override
  Future<void> discardDraft() async {
    _rpc('admin_discard_app_design_draft', const {});
  }

  @override
  Future<List<DesignTemplateInfo>> listTemplates() async {
    final raw = _rpc('admin_list_app_design_templates', const {});
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (DesignTemplateInfo.fromJson(item) case DesignTemplateInfo info)
          info,
    ];
  }

  @override
  Future<Map<String, dynamic>?> getTemplateDocument(String templateId) async {
    final raw = _rpc('admin_get_app_design_template', {'p_id': templateId});
    if (raw == null) return null;
    return jsonDecode(jsonEncode(raw)) as Map<String, dynamic>;
  }

  @override
  Future<DesignTemplateInfo> saveTemplate({
    String? id,
    required String name,
    required Map<String, dynamic> document,
  }) async {
    final raw = _rpc('admin_save_app_design_template', {
      'p_id': id,
      'p_name': name.trim(),
      'p_document': document,
    });
    final info = DesignTemplateInfo.fromJson(raw);
    if (info == null) {
      throw StateError('إجابة غير مفهومة من admin_save_app_design_template');
    }
    return info;
  }

  @override
  Future<void> deleteTemplate(String templateId) async {
    _rpc('admin_delete_app_design_template', {'p_id': templateId});
  }
}
