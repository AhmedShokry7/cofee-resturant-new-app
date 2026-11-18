import 'package:admin_app/features/visual_editor/domain/component_registry.dart';
import 'package:admin_app/features/visual_editor/domain/design_contract.dart';
import 'package:admin_app/features/visual_editor/domain/design_document_codec.dart';
import 'package:admin_app/features/visual_editor/domain/visual_editor_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() {
    ComponentRegistry.initialize();
    ComponentRegistry.all.forEach(DesignDocumentCodec.registerEntry);
  });

  group('DesignDocumentCodec — مفاتيح العقد', () {
    test('تظهر نصوص الصفحات المدمجة بالعربية والإنجليزية في حقول التحرير', () {
      final home = DesignDocumentCodec.defaultComponentsFor('home');
      final header = home.firstWhere(
        (component) => component.componentType == 'header',
      );
      expect(header.properties['question_ar'], 'ماذا تريد اليوم؟');
      expect(header.properties['question_en'], 'What would you like today?');

      final welcome = DesignDocumentCodec.defaultComponentsFor('welcome');
      final title = welcome.firstWhere(
        (component) => component.componentType == 'welcomeTitle',
      );
      expect(title.properties['highlight_ar'], 'قهوتك');
      expect(title.properties['highlight_en'], 'Your Coffee');
      expect(title.properties['rest_ar'], 'لحظتك، على طريقتك');
      expect(title.properties['rest_en'], 'Your Moment, Your Way');

      final auth = DesignDocumentCodec.defaultComponentsFor('forget_password');
      final subtitle = auth.firstWhere(
        (component) => component.componentType == 'authSubtitle',
      );
      expect(subtitle.properties['text_ar'], contains('أدخل بريدك الإلكتروني'));
      expect(subtitle.properties['text_en'], contains("we'll send you a link"));

      final cta = welcome.firstWhere(
        (component) => component.componentType == 'welcomeCta',
      );
      expect(cta.properties['label_ar'], 'لنبدأ');
      expect(cta.properties['label_en'], "Let's Get Started");
    });
    test('كل قسم يرسمه الهاتف له مفتاح عقد', () {
      for (final contractType in DesignContract.sectionTypes) {
        final internal = DesignDocumentCodec.internalType(contractType);
        expect(
          ComponentRegistry.get(internal),
          isNotNull,
          reason: 'المفتاح $contractType في العقد بلا مكوّن في السجل',
        );
        expect(
          DesignDocumentCodec.contractType(internal),
          contractType,
          reason: 'التحويل الدائري فشل لـ $contractType',
        );
      }
    });

    test('المستندات القديمة تعرض نصوص المصدر باللغتين عند فتحها', () {
      final parsed = DesignDocumentCodec.parsePage('home', [
        {
          'id': 'legacy-header',
          'type': DesignContract.header,
          'properties': const {},
        },
      ]);
      final header = parsed.single;
      expect(header.properties['question_ar'], 'ماذا تريد اليوم؟');
      expect(header.properties['question_en'], 'What would you like today?');
    });

    test('مسودة قديمة بلا زر ترحيب تحصل على عقدة قابلة للتحرير', () {
      final legacy = DesignDocumentCodec.parsePage('welcome', [
        {
          'id': 'welcome-title',
          'type': DesignContract.welcomeTitle,
          'properties': {},
        },
      ]);
      final migrated = DesignDocumentCodec.migrateWelcomeCta(legacy);
      final cta = migrated.singleWhere(
        (component) => component.componentType == 'welcomeCta',
      );
      expect(cta.properties['label_ar'], 'لنبدأ');
      expect(cta.properties['label_en'], "Let's Get Started");
      expect(cta.index, 1);
    });

    test('مكوّن إعدادات الافتتاحية يكتب المفتاح ويعود بقيمه', () {
      final component = DesignDocumentCodec.defaultComponentsFor('splash')
          .single;
      final document = DesignDocumentCodec.document({
        'splash': [component],
      });
      final root = document['pages']!.single['root'] as Map;
      final node = (root['children'] as List).single as Map;

      expect(node['type'], DesignContract.splashSettings);
      expect(DesignDocumentCodec.validate(document), isNull);
      final restored = DesignDocumentCodec.parseDocument(
        document,
      )['splash']!.single;
      expect(restored.componentType, 'splashSettings');
      expect(restored.properties['durationMs'], 1000);
      expect(restored.properties['backgroundColor'], '#FFFFFF');
    });

    test('المصادر الداخلية تعود بمفاتيح العقد', () {
      expect(
        DesignDocumentCodec.contractDataSource('featured'),
        DesignContract.featured,
      );
      expect(
        DesignDocumentCodec.contractDataSource('recommendations'),
        DesignContract.recommendations,
      );
      // قيمة داخلية مجهولة للهاتف تمرّ كما هي: المدقق لا يسمّيها.
      expect(
        DesignDocumentCodec.contractDataSource('categoryProducts'),
        'categoryProducts',
      );
      expect(
        DesignDocumentCodec.internalDataSource(DesignContract.featured),
        'featured',
      );
    });
  });

  group('DesignDocumentCodec — بناء وقراءة المستند', () {
    EditableComponent strip() => EditableComponent(
      componentId: 'home_productStrip_1',
      componentType: 'productStrip',
      pageId: 'home',
      index: 0,
      classification: ComponentClassification.configurableBusiness,
      properties: {
        'title': 'الأكثر طلبًا',
        'dataSource': 'featured',
        'maxItems': 10,
        'showPrice': true,
        'visible': true,
      },
      defaultValues: const {'dataSource': 'featured', 'maxItems': 10},
      validationRules: const {},
      allowedOperations: const ['delete', 'reorder', 'hide'],
      version: 1,
    );

    test(
      'العقدة تحمل مفتاح العقد ومصدر بياناته، وتستبعد غير الأعداد الأولية',
      () {
        final component = strip();
        final node = DesignDocumentCodec.node(component);
        expect(node['type'], DesignContract.productStrip);
        expect(node['visible'], true);
        final properties = node['properties'] as Map<String, dynamic>;
        expect(properties['dataSource'], DesignContract.featured);
        expect(properties['maxItems'], 10);
        expect(
          properties.containsKey('visible'),
          isFalse,
          reason: 'الظهور حقل العقدة لا خاصية',
        );
      },
    );

    test('المستند كامل يمر التحقق الحي بلا عيب', () {
      final document = DesignDocumentCodec.document({
        'home': [strip()],
      });
      expect(document['schema_version'], DesignContract.readableSchemaVersion);
      expect(DesignDocumentCodec.validate(document), isNull);
    });

    test('المستند يقرأ راجعًا إلى نفس المكوّنات', () {
      final original = strip();
      final document = DesignDocumentCodec.document({
        'home': [original],
      });
      final parsed = DesignDocumentCodec.parseDocument(document);
      final components = parsed['home']!;
      expect(components, hasLength(1));
      final component = components.single;
      expect(component.componentId, original.componentId);
      expect(component.componentType, 'productStrip');
      expect(component.properties['dataSource'], 'featured');
      expect(component.properties['maxItems'], 10);
      expect(component.properties['title_ar'], 'الأكثر طلبًا');
      expect(component.properties['title_en'], 'الأكثر طلبًا');
      expect(component.properties['visible'], true);
    });

    test('طبقة محايدة تعني غياب مفتاح theme لا قيمة فارغة', () {
      final document = DesignDocumentCodec.document({
        'home': [strip()],
      });
      expect(
        document.containsKey('theme'),
        isFalse,
        reason: 'المدقق الحي يفرّق بين JSON null وكائن؛ الفارغ غياب',
      );
    });

    test('طبقة شكل تُكتب بمفاتيح العقد وتُقرأ راجعًا', () {
      final theme = DesignTheme(
        colors: const {
          DesignColorRole.primary: '#2E7D32',
          DesignColorRole.border: '#80FFFFFF',
        },
        textScale: 'large',
        radiusScale: 'round',
      );
      final document = DesignDocumentCodec.document({
        'home': [strip()],
      }, theme: theme);
      expect(DesignDocumentCodec.validate(document), isNull);
      final parsedTheme = DesignDocumentCodec.themeOf(document);
      expect(parsedTheme.colors[DesignColorRole.primary], '#2E7D32');
      expect(parsedTheme.textScale, 'large');
      expect(parsedTheme.radiusScale, 'round');
    });
  });

  group('DesignDocumentCodec — التحقق الحي (مرآة app_design_is_valid)', () {
    final valid = DesignDocumentCodec.document({
      'home': [
        EditableComponent(
          componentId: 'id1',
          componentType: 'text',
          pageId: 'home',
          index: 0,
          classification: ComponentClassification.editable,
          properties: const {'visible': true},
          defaultValues: const {},
          validationRules: const {},
          allowedOperations: const ['reorder', 'hide'],
          version: 1,
        ),
      ],
    });

    test('رمز المخطط', () {
      final broken = Map<String, dynamic>.from(valid)..['schema_version'] = 3;
      expect(DesignDocumentCodec.validate(broken), 'schema_version');
    });

    test('صفحة لا يعرفها المدقق', () {
      final broken = Map<String, dynamic>.from(valid)
        ..['pages'] = [
          {'page': 'unknown_page', 'root': valid['pages'].first['root']},
        ];
      expect(DesignDocumentCodec.validate(broken), 'page_key');
    });

    test('معرّف مكرّر في الشجرة', () {
      final root = valid['pages'].first['root'] as Map<String, dynamic>;
      final child = (root['children'] as List).first;
      final duplicate = Map.from(child);
      final broken = Map<String, dynamic>.from(valid);
      broken['pages'] = [
        {
          'page': 'home',
          'root': {
            ...root,
            'children': [child, duplicate],
          },
        },
      ];
      expect(DesignDocumentCodec.validate(broken), 'node_duplicate');
    });

    test('خاصية غير أولية ترفض', () {
      final root = valid['pages'].first['root'] as Map<String, dynamic>;
      final child = Map<String, dynamic>.from(
        (root['children'] as List).first as Map,
      );
      child['properties'] = {
        'nested': {'bad': true},
      };
      final broken = Map<String, dynamic>.from(valid);
      broken['pages'] = [
        {
          'page': 'home',
          'root': {
            ...root,
            'children': [child],
          },
        },
      ];
      expect(DesignDocumentCodec.validate(broken), 'property_value');
    });

    test('مستند بلا صفحات يرفض', () {
      final broken = Map<String, dynamic>.from(valid)..['pages'] = [];
      expect(DesignDocumentCodec.validate(broken), 'pages');
    });
  });
}
