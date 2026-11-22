import 'package:admin_app/features/visual_editor/domain/design_contract.dart';
import 'package:admin_app/features/visual_editor/domain/design_document_codec.dart';
import 'package:admin_app/features/visual_editor/domain/visual_editor_models.dart';

/// سجل مراجعات الصفحات داخل المستند (`meta.page_revisions`).
///
/// 226 يخزّن مستندًا واحدًا لكل التطبيق، وRPCات الإدخال تكتب المستند كله.
/// رقم مراجعة لكل صفحة يسمح للمحرّر بمعرفة: هل تغيّرت هذه الصفحة في
/// القاعدة منذ أن حمّلتها؟ (قفل التعديل المتزامن). الأرقام تُكتب داخل
/// المستند نفسه — مدقق SQL (226/244) يفحص `schema_version` و`pages`
/// و`theme` فقط ولا يرفض المفاتيح الأعلى المجهولة، وجسر العميل
/// (`PublishedDesign.fromJson`) يتجاهلها.
abstract final class DesignDocumentMeta {
  /// مفاتيح `meta` أعلى المستند.
  static const String metaKey = 'meta';
  static const String revisionsKey = 'page_revisions';

  /// خريطة مراجعات الصفحات من مستند. مستند قديم بلا `meta` يعيد خريطة
  /// فارغة — تعني «لم تُرقَّم الصفحات بعد» وتبدأ كلها من 0.
  static Map<String, int> pageRevisions(Object? document) {
    final meta = document is Map ? document[metaKey] : null;
    final revisions = meta is Map ? meta[revisionsKey] : null;
    if (revisions is! Map) return const {};
    return {
      for (final entry in revisions.entries)
        if (entry.key is String && entry.value is num)
          entry.key as String: (entry.value as num).toInt(),
    };
  }

  /// مراجعة صفحة واحدة، 0 إن لم تُرقَّم بعد.
  static int pageRevision(Object? document, String pageId) =>
      pageRevisions(document)[pageId] ?? 0;

  /// نسخة المستند مع مراجعة صفحة واحدة محدّثة، وما عداها كما هو.
  static Map<String, dynamic> withPageRevision(
    Object? document,
    String pageId,
    int revision,
  ) {
    final base = document is Map ? document : const <String, dynamic>{};
    final revisions = {
      ...pageRevisions(base),
      pageId: revision,
    };
    return {
      ...base,
      metaKey: {...(base[metaKey] is Map ? base[metaKey] as Map : const {}), revisionsKey: revisions},
    };
  }
}

/// دمج على مستوى الصفحة فوق مستندات التصميم الكاملة.
///
/// كل دمج يبدأ من قراءة حية للمستند المحفوظ ويستبدل الصفحات المستهدفة
/// فقط: كتابة صفحة لا تلمس صفحات أخرى ولا ترتيبها ولا عناصرها، والنشر
/// يجمع من أحدث مسودة محفوظة + أحدث منشور — لا من حالة المحرر المفتوح.
abstract final class DesignDocumentMerge {
  /// مستند كامل مع صفحة واحدة مستبدلة أو مُدرجة.
  ///
  /// [base] المستند المحفوظ كما جاء من القاعدة (قد يكون فارغًا أول مرة).
  /// صفحة فارغة تُسقَط من المصفوفة مطابقةً لسلوك [DesignDocumentCodec.document]
  /// — إفراغ صفحة يعني إزالتها، وما عداها يبقى كما كُتب.
  static Map<String, dynamic> withPage({
    required Object? base,
    required String pageId,
    required List<EditableComponent> components,
    DesignTheme? theme,
  }) => withPages(base: base, pages: {pageId: components}, theme: theme);

  /// مستند كامل مع عدة صفحات مستبدلة أو مُدرجة، وطبقة الشكل إن حُدّدت.
  static Map<String, dynamic> withPages({
    required Object? base,
    required Map<String, List<EditableComponent>> pages,
    DesignTheme? theme,
  }) {
    final document = base is Map
        ? Map<String, dynamic>.from(base)
        : <String, dynamic>{};
    final existingPages = document['pages'];
    final pagesList = <dynamic>[
      if (existingPages is List) ...existingPages,
    ];
    for (final entry in pages.entries) {
      final pageComponents = entry.value;
      final newEntry = pageComponents.isEmpty
          ? null
          : DesignDocumentCodec.pageEntry(entry.key, pageComponents);
      // استبدال في مكانه يحفظ ترتيب الصفحات كما كُتب أول مرة.
      final index = pagesList.indexWhere(
        (page) => page is Map && page['page'] == entry.key,
      );
      if (newEntry == null) {
        if (index >= 0) pagesList.removeAt(index);
      } else if (index >= 0) {
        pagesList[index] = newEntry;
      } else {
        pagesList.add(newEntry);
      }
    }
    document['schema_version'] = DesignContract.readableSchemaVersion;
    document['pages'] = pagesList;
    if (theme != null) {
      // طبقة محايدة تعني غياب المفتاح كله، لا `"theme": null`.
      final themeJson = theme.toJson();
      if (themeJson == null || themeJson.isEmpty) {
        document.remove('theme');
      } else {
        document['theme'] = themeJson;
      }
    }
    return document;
  }

  /// مستند منشور جديد: الصفحات المعتمدة تُنسخ من المسودة الحية، وكل
  /// ما عداها يبقى من أحدث مستند منشور. طبقة الشكل تأتي من المسودة.
  ///
  /// صفحة غير موجودة في المسودة لا تُمسّ في المنشور (الموافقة تعتمد ما
  /// هو محفوظ فعلًا). مراجعة كل صفحة معتمدة تُسجَّل من مراجعتها في المسودة
  /// — يقرأها تاريخ الإصدارات لاحقًا.
  static Map<String, dynamic> publishedWithPages({
    required Object? publishedBase,
    required Object? draft,
    required Iterable<String> pageIds,
    bool includeTheme = true,
  }) {
    final draftPages = draft is Map && draft['pages'] is List
        ? [for (final page in draft['pages'] as List) if (page is Map) page]
        : const <Map>[];
    var document = publishedBase is Map
        ? Map<String, dynamic>.from(publishedBase)
        : <String, dynamic>{};
    final draftRevisions = DesignDocumentMeta.pageRevisions(draft);
    for (final pageId in pageIds) {
      final entry = draftPages.firstWhere(
        (page) => page['page'] == pageId,
        orElse: () => const {},
      );
      if (entry.isEmpty) continue;
      final root = entry['root'];
      if (root is! Map) continue;
      // الصفحة في المسودة كما هي — تعاد للمحرّر من مصدرها لا من تحليله
      // وإعادة بنائه، فلا تتغير صفحة معتمدة بحرف واحد.
      final pagesList = <dynamic>[...?document['pages'] as List?];
      final index = pagesList.indexWhere(
        (page) => page is Map && page['page'] == pageId,
      );
      final copied = Map<String, dynamic>.from(entry);
      if (index >= 0) {
        pagesList[index] = copied;
      } else {
        pagesList.add(copied);
      }
      document['pages'] = pagesList;
      // مراجعة الصفحة المعتمدة = مراجعتها في المسودة وقت النشر.
      final revision = draftRevisions[pageId];
      if (revision != null) {
        document = DesignDocumentMeta.withPageRevision(document, pageId, revision);
      }
    }
    if (includeTheme) {
      final draftTheme = draft is Map ? draft['theme'] : null;
      if (draftTheme is Map && draftTheme.isNotEmpty) {
        document['theme'] = Map<String, dynamic>.from(draftTheme);
      } else {
        document.remove('theme');
      }
    }
    document['schema_version'] = DesignContract.readableSchemaVersion;
    return document;
  }
}
