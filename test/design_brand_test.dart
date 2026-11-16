import 'package:flutter_test/flutter_test.dart';

import 'package:new_coffee/features/design/data/model/published_design.dart';
import 'package:new_coffee/features/design/presentation/manager/design/design_state.dart';

/// هوية التطبيق القادمة في طبقة `theme.brand` — الاسم واللوجو من المحرر.
///
/// الباقي بلا هوية يجب أن يقرأ محايدًا (null) كي تسقط الواجهات على هوية
/// التطبيق المضمّنة لا على فراغ.
void main() {
  test('PublishedTheme reads the brand block of a version-2 document', () {
    const document = <String, dynamic>{
      'schema_version': 2,
      'theme': {
        'brand': {
          'name_ar': 'قهوتي',
          'name_en': 'My Coffee',
          'logo_url': 'https://cdn.example.com/logo.png',
        },
      },
      'pages': [
        {'page': 'home', 'root': {'type': 'page.home', 'children': []}},
      ],
    };

    final design = PublishedDesign.fromJson(document)!;
    expect(design.theme.appNameAr, 'قهوتي');
    expect(design.theme.appNameEn, 'My Coffee');
    expect(design.theme.logoUrl, 'https://cdn.example.com/logo.png');
    expect(design.theme.brandName(isArabic: true), 'قهوتي');
    expect(design.theme.brandName(isArabic: false), 'My Coffee');
  });

  test('a document without a brand reads neutral', () {
    const document = <String, dynamic>{
      'schema_version': 2,
      'theme': {
        'colors': {'primary': '#2E7D32'},
      },
      'pages': [
        {'page': 'home', 'root': {'type': 'page.home', 'children': []}},
      ],
    };

    final design = PublishedDesign.fromJson(document)!;
    expect(design.theme.hasBrand, isFalse);
    expect(design.theme.logoUrl, isNull);
    expect(design.theme.brandName(isArabic: true), isNull);
  });

  test('toJson round-trips the brand', () {
    const theme = PublishedTheme(
      appNameAr: 'قهوتي',
      appNameEn: 'My Coffee',
      logoUrl: 'https://cdn.example.com/logo.png',
    );
    final json = theme.toJson();
    final parsed = PublishedTheme.fromJson(json);
    expect(parsed.appNameAr, 'قهوتي');
    expect(parsed.appNameEn, 'My Coffee');
    expect(parsed.logoUrl, 'https://cdn.example.com/logo.png');
  });

  test('DesignState exposes the brand for screens', () {
    const design = PublishedDesign(
      schemaVersion: 2,
      theme: PublishedTheme(appNameAr: 'قهوتي', logoUrl: 'https://x/logo.png'),
      homeSections: <PublishedSection>[],
      categoriesSections: <PublishedSection>[],
    );
    final state = DesignState(design: design, isLoaded: true);
    expect(state.appNameAr, 'قهوتي');
    expect(state.logoUrl, 'https://x/logo.png');
    expect(state.brandName(true), 'قهوتي');
    expect(state.brandName(false), 'قهوتي'); // falls back to Arabic name
  });
}
