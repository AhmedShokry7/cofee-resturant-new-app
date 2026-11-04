import 'dart:convert';

import 'package:admin_app/features/customer_preview/domain/entities/app_page.dart';
import 'package:admin_app/features/customer_preview/domain/entities/design_node.dart';
import 'package:admin_app/features/customer_preview/domain/entities/design_theme.dart';

/// مستند تصميم تطبيق العميل: نسخة واحدة تحمل صفحات التطبيق كلها وشكلها العام.
///
/// المستند هو وحدة الحفظ والنشر — مسودة أو منشور — لأنه لا معنى لنشر صفحة
/// مكتملة فوق أخرى قديمة: الزبون يرى التطبيق كله من نسخة واحدة. والثيم جزء من
/// تلك الوحدة لا بجانبها: لون منشور بلا تخطيطه نصف شاشة، والتراجع عن نشر يجب
/// أن يرجع الشكل والتخطيط معًا لا أحدهما.
///
/// [schemaVersion] يُطبع ويُتحقَّق منه عند القراءة: تطبيق عميل مثبّت بإصدار لا
/// يعرف هذه النسخة يرث آخر تصميم صالح بدل أن ينفّذ شكلًا لا يفهمه.
class DesignDocument {
  const DesignDocument({
    required this.schemaVersion,
    required this.pages,
    this.theme = DesignTheme.none,
  });

  /// نسخة المستند التي يفهمها `DesignRenderer` المثبّت عند الزبون.
  final int schemaVersion;

  /// جذر كل صفحة. الصفحات القابلة للتحرير وحدها لها جذر: صفحة مقفلة لا تُحرَّر،
  /// فلا تُخزَّن شكلًا.
  final Map<AppPage, DesignNode> pages;

  /// الطبقة التي تُرسم بها كل الصفحات. محايدة حين لا يغيّرها أحد، فتبقى شاشة
  /// اليوم هي شاشة ما قبل النظام.
  final DesignTheme theme;

  DesignNode? rootOf(AppPage page) => pages[page];

  /// مقارنة بالمحتوى، لا بالكائن: اللوحة تحتاج أن تعرف هل بقي شيء غير محفوظ
  /// بعد، والمستندات تُبنى من جديد مع كل تحريك.
  bool hasSameContent(DesignDocument? other) {
    if (other == null) return false;
    return jsonEncode(toMap()) == jsonEncode(other.toMap());
  }

  /// مقاطع صفحة بترتيبها كما يراها المحرّر؛ صفحة بلا جذر قائمة فارغة.
  List<DesignNode> sectionsOf(AppPage page) =>
      pages[page]?.children ?? const <DesignNode>[];

  DesignDocument withPage(AppPage page, DesignNode root) {
    final next = Map<AppPage, DesignNode>.of(pages);
    next[page] = root;
    return DesignDocument(schemaVersion: schemaVersion, pages: next, theme: theme);
  }

  /// طبقة الشكل الجديدة لكل المستند: لا تُحرَّر صفحة في هذه العملية، فالشكل
  /// عام بالتعريف وخصائص الصفحات لا تمسها.
  DesignDocument withTheme(DesignTheme next) =>
      DesignDocument(schemaVersion: schemaVersion, pages: pages, theme: next);

  DesignDocument copyWith({
    int? schemaVersion,
    Map<AppPage, DesignNode>? pages,
    DesignTheme? theme,
  }) => DesignDocument(
    schemaVersion: schemaVersion ?? this.schemaVersion,
    pages: pages ?? this.pages,
    theme: theme ?? this.theme,
  );

  /// كل عقد المستند، بما فيها جذور الصفحات، في ترتيب الشجرة.
  Iterable<DesignNode> get nodes sync* {
    for (final root in pages.values) {
      yield* _walk(root);
    }
  }

  static Iterable<DesignNode> _walk(DesignNode node) sync* {
    yield node;
    for (final child in node.children) {
      yield* _walk(child);
    }
  }

  Map<String, Object?> toMap() => <String, Object?>{
    'schema_version': schemaVersion,
    // الطبقة المحايدة لا تُطبع: مستند بلا شكل هو حرفيًا مستند النسخة الأولى،
    // فلا فرق في القاعدة بين من لم يفتح لوحة الألوان ومن فتحها وتركها.
    if (!theme.isDefault) 'theme': theme.toMap(),
    'pages': <Object?>[
      for (final entry in pages.entries)
        <String, Object?>{'page': entry.key.key, 'root': entry.value.toMap()},
    ],
  };

  /// القراءة صارمة: صنف غير معروف أو صفحة مكررة أو حقل ناقص يرمي، لأن مستندًا
  /// نصف مقروء لا يُنشر فوق تصميم الزبون.
  static DesignDocument fromMap(Map<Object?, Object?> map) {
    final version = map['schema_version'];
    if (version is! int || version <= 0) {
      throw const FormatException('المستند بلا نسخة مخطط صحيحة');
    }
    final rawPages = map['pages'];
    if (rawPages is! List) {
      throw const FormatException('المستند بلا قائمة صفحات');
    }
    final pages = <AppPage, DesignNode>{};
    for (final raw in rawPages) {
      if (raw is! Map<Object?, Object?>) {
        throw const FormatException('صفحة في المستند ليست كائنًا');
      }
      final page = AppPage.of(raw['page'] as String?);
      if (page == null) {
        throw FormatException('صفحة لا يعرفها المحرّر: ${raw['page']}');
      }
      final root = raw['root'];
      if (root is! Map<Object?, Object?>) {
        throw FormatException('جذر صفحة ${page.key} مفقود');
      }
      if (pages.containsKey(page)) {
        throw FormatException('صفحة ${page.key} مكررة في المستند');
      }
      pages[page] = DesignNode.fromMap(root);
    }
    return DesignDocument(
      schemaVersion: version,
      pages: pages,
      // النسخة الأولى لم تحمل مفتاح theme إطلاقًا، فغيابه طبقة محايدة لا عيب.
      theme: DesignTheme.fromMap(map['theme']),
    );
  }
}
