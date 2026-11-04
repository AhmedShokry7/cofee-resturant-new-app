import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:admin_app/core/services/supabase_service.dart';
import 'package:admin_app/features/customer_preview/domain/entities/design_document.dart';
import 'package:admin_app/features/customer_preview/domain/entities/design_version.dart';
import 'package:admin_app/features/customer_preview/domain/repositories/app_builder_repository.dart';

/// تصميم تطبيق العميل في قاعدته: مسودة، ومنشور، وسجلّ إصدارات.
///
/// المواضع اثنان لا جدولان: `core.app_settings` تحمل المستند الحيّ (وصفها صفّان
/// بـ 226، والمنشور منها `is_public` فيقرؤه تطبيق العميل من نفس الصف الذي تقرأه
/// اللوحة)، و`core.app_design_versions` تحمل ما نُشر. كل كتابة تمرّ بدالة
/// `security definer` تفحص الصلاحية والمخطّط في القاعدة، فلا حماية في الواجهة
/// وحدها: زرّ النشر المخفي ليس إذنًا، و`design.publish` تملكه القاعدة.
class SupabaseAppBuilderRepository implements AppBuilderRepository {
  SupabaseAppBuilderRepository([this._client]);

  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? SupabaseService.client;

  /// ما يقرأه الموظف الذي يحرّر، لا ما يراه الزبون.
  static const String _draftSlot = 'draft';

  @override
  Future<DesignDocument?> loadDraft() => _readDocument(_draftSlot);

  @override
  Future<DesignDocument?> loadPublished() => _readDocument('published');

  /// ما تقرأه اللوحة من سجلّ: أحدث ثلاثين نشرًا، وهو ما تُظهره قائمة الإصدارات.
  static const int _versionLimit = 30;

  @override
  Future<List<DesignVersion>> loadVersions() async {
    final rows = await _supabase.rpc(
      'admin_list_app_design_versions',
      params: <String, dynamic>{'p_limit': _versionLimit},
    );
    if (rows is! List) return const <DesignVersion>[];
    return rows
        .whereType<Map<dynamic, dynamic>>()
        .map(_versionFrom)
        .toList(growable: false);
  }

  @override
  Future<DesignDocument?> loadVersion(String versionId) async {
    if (versionId.isEmpty) return null;
    final rows = await _supabase.rpc(
      'admin_get_app_design_version',
      params: <String, dynamic>{'p_version_id': versionId},
    );
    return _documentFrom(rows);
  }

  @override
  Future<void> saveDraft(DesignDocument document) async {
    await _supabase.rpc(
      'admin_save_app_design_draft',
      params: <String, dynamic>{'p_document': document.toMap()},
    );
  }

  @override
  Future<DesignVersion> publish(DesignDocument document) async {
    final row = await _supabase.rpc(
      'admin_publish_app_design',
      params: <String, dynamic>{'p_document': document.toMap()},
    );
    if (row is! Map) {
      throw const AppBuilderPublishException(
        'النشر: القاعدة لم ترجع رقم الإصدار',
      );
    }
    return _versionFrom(Map<dynamic, dynamic>.from(row));
  }

  @override
  Future<DesignVersion> restoreVersion(String versionId) async {
    final row = await _supabase.rpc(
      'admin_restore_app_design_version',
      params: <String, dynamic>{'p_version_id': versionId},
    );
    if (row is! Map) {
      throw const AppBuilderPublishException(
        'الرجوع: القاعدة لم ترجع رقم الإصدار',
      );
    }
    return _versionFrom(Map<dynamic, dynamic>.from(row));
  }

  @override
  Future<void> discardDraft() async {
    await _supabase.rpc('admin_discard_app_design_draft');
  }

  Future<DesignDocument?> _readDocument(String slot) async {
    final rows = await _supabase.rpc(
      'admin_get_app_design',
      params: <String, dynamic>{'p_slot': slot},
    );
    return _documentFrom(rows);
  }

  /// المستند كما كتبته اللوحة، أو null حين لم يُحفظ شيء بعد.
  ///
  /// قراءة صارمة عن قصد: [DesignDocument.fromMap] يرمي على صنف مجهول أو صفحة
  /// مكرّرة، وخطأه يصل اللوحة كما هو. مستند نصف مقروء لا يُعرض ولا يُنشر فوق ما
  /// يراه الزبون الآن.
  static DesignDocument? _documentFrom(Object? rows) {
    if (rows is! Map) return null;
    return DesignDocument.fromMap(Map<Object?, Object?>.from(rows));
  }

  static DesignVersion _versionFrom(Map<dynamic, dynamic> row) {
    return DesignVersion(
      id: '${row['id'] ?? ''}',
      number: (row['version_number'] as num?)?.toInt() ?? 0,
      // 1970 لا الآن: الوقت هنا للوحة تُطابق به إصدارًا، وزمنٌ مُختلَق يخدعها في
      // كل مقارناتها، أما الصف الذي بلا وقت فيظهر على حقيقته.
      publishedAt:
          DateTime.tryParse('${row['published_at'] ?? ''}')?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      schemaVersion: (row['schema_version'] as num?)?.toInt() ?? 0,
      note: switch (row['note']) {
        final String text when text.trim().isNotEmpty => text.trim(),
        _ => null,
      },
    );
  }
}

/// نشر أو رجوع بلا رقم إصدار: القاعدة ردّت بشكل لا يصفّ إصدارًا.
class AppBuilderPublishException implements Exception {
  const AppBuilderPublishException(this.message);

  final String message;

  @override
  String toString() => message;
}
