import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/features/customer_preview/domain/entities/app_page.dart';
import 'package:admin_app/features/customer_preview/domain/entities/design_document.dart';
import 'package:admin_app/features/customer_preview/domain/entities/design_node.dart';
import 'package:admin_app/features/customer_preview/domain/entities/design_theme.dart';

/// ترتيب الصفحة الذي يعرضه القالب على الشاشة، بلغة اللوحة.
///
/// المقارنة بالمعرّفات وحدها: خصائص المقطع يملكها السجل لا القالب، فلو نسخ
/// القالب الخصائص معه صار لكل قالب نسخة من شاشة يحرّرها غيره، وأول خاصية
/// يغيّرها السجل بقيت قديمة في كل قالب.
class AppTemplate {
  const AppTemplate({
    required this.slug,
    required this.nameAr,
    required this.nameEn,
    required this.noteAr,
    required this.noteEn,
    required this.homeOrder,
    this.colors = const <DesignColorRole, String>{},
  });

  /// مفتاح ثابت لا يتغيّر بتغيّر الاسم المعروض؛ به تُعرَّف القوالب المضمّنة.
  final String slug;

  final String nameAr;
  final String nameEn;

  /// سطر يقوله الموظف قبل أن يضغط: ماذا يتغيّر في شاشته بهذا القالب.
  final String noteAr;

  final String noteEn;

  /// معرّفات مقاطع الصفحة الرئيسية بالترتيب الذي يراد بها.
  final List<String> homeOrder;

  /// الأدوار التي يلوّنها القالب. الغائب منها لا يلمسه، فالقالب فوققة لا صورة
  /// كاملة تُنسخ فوق قرار الموظف.
  final Map<DesignColorRole, String> colors;

  String name(AppLanguage language) =>
      language.isArabic ? nameAr : nameEn;

  String note(AppLanguage language) =>
      language.isArabic ? noteAr : noteEn;

  /// القالب على مستند الموظف الحالي، لا على مستند افتراضي: مسوّدته قد تحمل
  /// مقاطع أضافتها بنفسها، وتلك تبقى.
  ///
  /// الترتيب يعيد ما يعرفه القالب ويترك الباقي بترتيبه الأصلي في آخر الصفحة،
  /// فلا يختفي مقطع لم يسمّه قالب، ولا يُنشأ مقطع لم يكن في المستند.
  /// والألوان تُدمج دورًا دورًا فوق ما اختاره الموظف في استوديو الشكل.
  DesignDocument applyTo(DesignDocument base) {
    final root = base.rootOf(AppPage.home);
    var document = base;
    if (root != null) {
      document = document.withPage(
        AppPage.home,
        root.copyWith(children: _reorder(root.children)),
      );
    }
    for (final entry in colors.entries) {
      document = document.withTheme(document.theme.withColor(entry.key, entry.value));
    }
    return document;
  }

  List<DesignNode> _reorder(List<DesignNode> children) {
    final remaining = <String, DesignNode>{
      for (final child in children) child.id: child,
    };
    final next = <DesignNode>[];
    for (final id in homeOrder) {
      final child = remaining.remove(id);
      if (child != null) next.add(child);
    }
    // ما لا يعرفه القالب — مقطع أضافه الموظف أو قالب استُورد لاحقًا — يبقى في
    // آخر الصفحة بترتيبه، لأن حذف مقطع لم يسمّه أحد قرار حذف لا قرار ترتيب.
    next.addAll(remaining.values);
    return next;
  }
}

/// القوالب المضمّنة التي يفتحها المحرّر.
///
/// تبقى في Dart لا في القاعدة لأنها ترسم مكوّنات السجل نفسه: قالب في SQL ينسخ
/// خصائص المقاطع، وأول خاصية يغيّرها السجل تترك القالب القديم يرسم شاشة لا
/// يعرفها أحد. ما يضيفه الموظف بنفسه يذهب إلى `core.app_design_templates` —
/// ذاك وعاء بيانات لا وعاء شيفرة.
///
/// «ترتيب اليوم» هو الوعد الأول مكتوبًا كقالب: مستند لا يغيّر حرفًا، وزرّ يرجع
/// إليه في أي وقت.
abstract final class TemplateRegistry {
  TemplateRegistry._();

  /// معرّفات الصفحة الرئيسية كما يبنيها السجل اليوم، بترتيبها كما يرسمه
  /// `home_page_body.dart`.
  static const List<String> _todayOrder = <String>[
    'home_header',
    'home_search',
    'home_banners',
    'home_categories',
    'home_popular',
    'home_single_banner',
    'home_recommendations',
    'home_bundles',
  ];

  static const AppTemplate today = AppTemplate(
    slug: 'today',
    nameAr: 'ترتيب اليوم',
    nameEn: 'Today’s layout',
    noteAr: 'التصميم الذي يراه الزبون الآن، بلا تغيير حرف واحد.',
    noteEn: 'Exactly what the customer sees today, changed in no way.',
    homeOrder: _todayOrder,
  );

  static const AppTemplate modernCafe = AppTemplate(
    slug: 'modern-cafe',
    nameAr: 'مقهى حديث',
    nameEn: 'Modern Café',
    noteAr:
        'الترتيب نفسه مع لوحة بنّية دافئة؛ البانير الترويجي ينزل بعد '
        'الترشيحات ليُكافئ الزبون بعد أن يختار.',
    noteEn:
        'The same order in a warm palette; the promo banner moves below the '
        'recommendations so it meets the customer after they choose.',
    homeOrder: <String>[
      'home_header',
      'home_search',
      'home_banners',
      'home_categories',
      'home_popular',
      'home_recommendations',
      'home_single_banner',
      'home_bundles',
    ],
    colors: <DesignColorRole, String>{
      DesignColorRole.primary: '#6F4E37',
      DesignColorRole.secondary: '#A67C52',
      DesignColorRole.background: '#FAF6F1',
      DesignColorRole.surface: '#FFFDF9',
      DesignColorRole.textPrimary: '#2B2118',
      DesignColorRole.textSecondary: '#6B5E54',
      DesignColorRole.border: '#E7DCCF',
    },
  );

  static const AppTemplate quickOrder = AppTemplate(
    slug: 'quick-order',
    nameAr: 'طلب سريع',
    nameEn: 'Quick Order',
    noteAr: 'البحث فوق الترويسة لمن يعود كل يوم؛ الألوان كما تركها الموظف.',
    noteEn:
        'Search above the header for the customer who returns every day; '
        'colours stay as the owner left them.',
    homeOrder: <String>[
      'home_search',
      'home_header',
      'home_banners',
      'home_categories',
      'home_popular',
      'home_single_banner',
      'home_recommendations',
      'home_bundles',
    ],
  );

  static const List<AppTemplate> builtIns = <AppTemplate>[
    today,
    modernCafe,
    quickOrder,
  ];
}
