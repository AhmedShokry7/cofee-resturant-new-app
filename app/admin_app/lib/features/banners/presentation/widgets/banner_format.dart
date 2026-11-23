import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';

String bannerTargetTypeLabel(String code) => switch (code) {
  'none' => S.none,
  'product' => S.productLabel,
  'category' => S.category,
  'bundle' => S.bundles,
  'url' => S.url,
  _ => code,
};

const List<String> bannerTargetTypeCodes = <String>[
  'none',
  'product',
  'category',
  'bundle',
  'url',
];

const List<String> bannerDisplayLocationCodes = <String>['hero', 'inline'];

String bannerDisplayLocationTitle() => AppLocale.instance.isArabic
    ? '\u0645\u0643\u0627\u0646 \u0627\u0644\u0639\u0631\u0636'
    : 'Display location';

String bannerDisplayLocationLabel(String code) => switch (code) {
  'inline' => AppLocale.instance.isArabic
      ? '\u0628\u0627\u0646\u0631 \u062f\u0627\u062e\u0644 \u0627\u0644\u0635\u0641\u062d\u0629'
      : 'In-page banner',
  _ => AppLocale.instance.isArabic
      ? '\u0627\u0644\u0633\u0644\u0627\u064a\u062f\u0631 \u0627\u0644\u0639\u0644\u0648\u064a'
      : 'Top carousel',
};
