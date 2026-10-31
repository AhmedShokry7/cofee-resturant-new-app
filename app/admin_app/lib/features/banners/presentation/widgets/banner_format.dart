import 'package:admin_app/core/locale/app_strings.dart';

/// أنواع هدف البانر: الكود كما تخزنه القاعدة والتسمية كما يقرأها الأدمن.
/// مصدر واحد للبطاقة والنموذج، فالبطاقة كانت تطبع الكود الإنجليزي خامًا.
String bannerTargetTypeLabel(String code) => switch (code) {
  'none' => S.none,
  'product' => S.productLabel,
  'category' => S.category,
  'url' => S.url,
  _ => code,
};

/// خيارات القائمة بترتيب عرضها؛ `none` أولها لأن الأغلبية بلا هدف.
List<String> get bannerTargetTypeCodes => const <String>[
  'none',
  'product',
  'category',
  'url',
];
