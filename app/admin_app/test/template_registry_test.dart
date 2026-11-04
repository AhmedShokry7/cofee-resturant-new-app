import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/features/customer_preview/domain/entities/app_page.dart';
import 'package:admin_app/features/customer_preview/domain/entities/design_document.dart';
import 'package:admin_app/features/customer_preview/domain/entities/design_node.dart';
import 'package:admin_app/features/customer_preview/domain/entities/design_theme.dart';
import 'package:admin_app/features/customer_preview/domain/registry/template_registry.dart';
import 'package:admin_app/features/customer_preview/domain/registry/widget_registry.dart';
import 'package:admin_app/features/customer_preview/domain/services/design_validator.dart';

/// ما يضمنه المعرض قبل أن يلمسه الموظف.
///
/// القالب المضمّن يُبنى من مستند السجل نفسه: يعيد ترتيب المقاطع بذكر
/// معرّفاتها، ولا ينسخ خصائصها. فإن كان التعريف في Dart هو الحقيقة الوحيدة،
/// صار القالب شبح شاشة يصفّها السجل من بعده — وهذا الاختبار هو ما يمنع ذلك.
void main() {
  final base = WidgetRegistry.defaultDocument();

  List<String> ids(DesignDocument document) => document
      .sectionsOf(AppPage.home)
      .map((section) => section.id)
      .toList(growable: false);

  group('القوالب المضمّنة', () {
    test('ترتيب اليوم لا يغيّر حرفًا في المستند الافتراضي', () {
      expect(
        TemplateRegistry.today.applyTo(base).hasSameContent(base),
        isTrue,
        reason: 'الوعد الأول: تصميم اليوم هو القالب الأصلي، وتطبيقه لا يحرّكه.',
      );
    });

    test('كل قالب يسمّي مقاطع الصفحة كلها، فلا يختفي قسم بتطبيقه', () {
      final known = ids(base).toSet();
      for (final template in TemplateRegistry.builtIns) {
        final named = template.homeOrder.toSet();
        expect(
          named.difference(known),
          isEmpty,
          reason: '${template.slug} يذكر معرّفات لا توجد في مستند السجل.',
        );
        expect(
          known.difference(named),
          isEmpty,
          reason: '${template.slug} يسكت عن مقطع، فيقع في آخر الصفحة بغير قرار.',
        );
      }
    });

    test('كل قالب ينتج مستندًا صالحًا للنشر', () {
      for (final template in TemplateRegistry.builtIns) {
        final document = template.applyTo(base);
        expect(
          DesignValidator.validate(document).isPublishable,
          isTrue,
          reason: '${template.slug} ينتج مستندًا ترفضه القاعدة عند النشر.',
        );
        expect(document.schemaVersion, WidgetRegistry.schemaVersion);
      }
    });

    test('الترتيب يتغيّر والخصائص تبقى ملك السجل', () {
      final applied = TemplateRegistry.quickOrder.applyTo(base);

      expect(ids(applied).first, 'home_search');
      expect(ids(applied)[1], 'home_header');
      // الخصائص تُنقل كما هي: القالب لا يملك عنوانًا ولا مصدر بيانات.
      final search = applied.sectionsOf(AppPage.home).first;
      final inBase = base.sectionsOf(AppPage.home).firstWhere(
        (section) => section.id == 'home_search',
      );
      expect(search.properties, inBase.properties);
      // لم يلمس لونًا: قالب بلا لوحة ألوان لا يلوّن شيئًا.
      expect(applied.theme.isDefault, isTrue);
    });

    test('مقهى حديث يلوّن الأدوار التي يقرأها الهاتف وحدها', () {
      final applied = TemplateRegistry.modernCafe.applyTo(base);
      expect(applied.theme.colors.isNotEmpty, isTrue);
      // الأدوار التي لا موضع لها في الهاتف بعد لا تُكتب في قالب: لون لا يراه
      // أحد في الزبون يُعرض في اللوحة ويختفي عند النشر.
      expect(applied.theme.colors.keys, unorderedEquals(<DesignColorRole>{
        DesignColorRole.primary,
        DesignColorRole.secondary,
        DesignColorRole.background,
        DesignColorRole.surface,
        DesignColorRole.textPrimary,
        DesignColorRole.textSecondary,
        DesignColorRole.border,
      }));
      // المقاييس لا يقرأها الهاتف بعد، فتبقى على ما هي.
      expect(applied.theme.textScale, DesignScale.defaultKey);
      expect(applied.theme.radiusScale, DesignScale.defaultKey);
    });

    test('القالب يدمج فوق قرارات الموظف ولا يستبدل الطبقة كلها', () {
      final owner = base.withTheme(
        base.theme.withColor(DesignColorRole.success, '#00AA00'),
      );
      final applied = TemplateRegistry.modernCafe.applyTo(owner);

      expect(applied.theme.colors[DesignColorRole.success], '#00AA00');
      expect(applied.theme.colors[DesignColorRole.primary], '#6F4E37');
    });

    test('مقطع أضافه الموظف يبقى في آخر الصفحة بخصائصه', () {
      final home = base.rootOf(AppPage.home)!;
      final withExtra = base.withPage(
        AppPage.home,
        home.copyWith(
          children: <DesignNode>[
            ...home.children,
            WidgetRegistry.node(WidgetTypes.promoBanner, 'home_owner_added'),
          ],
        ),
      );

      final applied = TemplateRegistry.today.applyTo(withExtra);
      final after = ids(applied);
      expect(after.take(8).toList(), ids(base));
      expect(after.last, 'home_owner_added');
    });

    test('صفحة لا جذر لها لا تُخترع من قالب', () {
      final partial = DesignDocument(
        schemaVersion: WidgetRegistry.schemaVersion,
        pages: <AppPage, DesignNode>{},
      );
      final applied = TemplateRegistry.modernCafe.applyTo(partial);

      expect(applied.pages, isEmpty);
      // اللون يصل بقية المستند: الطبقة عامة بالتعريف.
      expect(applied.theme.colors.isNotEmpty, isTrue);
    });
  });
}
