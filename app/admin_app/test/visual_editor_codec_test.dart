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

    test('العقدة تحمل مفتاح العقد ومصدر بياناته، وتستبعد غير الأعداد الأولية', () {
      final component = strip();
      final node = DesignDocumentCodec.node(component);
      expect(node['type'], DesignContract.productStrip);
      expect(node['visible'], true);
      final properties = node['properties'] as Map<String, dynamic>;
      expect(properties['dataSource'], DesignContract.featured);
      expect(properties['maxItems'], 10);
      expect(properties.containsKey('visible'), isFalse,
          reason: 'الظهور حقل العقدة لا خاصية');
    });

    test('المستند كامل يمر التحقق الحي بلا عيب', () {
      final document = DesignDocumentCodec.document(
        {'home': [strip()]},
      );
      expect(document['schema_version'], DesignContract.readableSchemaVersion);
      expect(DesignDocumentCodec.validate(document), isNull);
    });

    test('المستند يقرأ راجعًا إلى نفس المكوّنات', () {
      final original = strip();
      final document = DesignDocumentCodec.document(
        {'home': [original]},
      );
      final parsed = DesignDocumentCodec.parseDocument(document);
      final components = parsed['home']!;
      expect(components, hasLength(1));
      final component = components.single;
      expect(component.componentId, original.componentId);
      expect(component.componentType, 'productStrip');
      expect(component.properties['dataSource'], 'featured');
      expect(component.properties['maxItems'], 10);
      expect(component.properties['visible'], true);
    });

    test('طبقة محايدة تعني غياب مفتاح theme لا قيمة فارغة', () {
      final document = DesignDocumentCodec.document(
        {'home': [strip()]},
      );
      expect(document.containsKey('theme'), isFalse,
          reason: 'المدقق الحي يفرّق بين JSON null وكائن؛ الفارغ غياب');
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
      final document = DesignDocumentCodec.document(
        {'home': [strip()]},
        theme: theme,
      );
      expect(DesignDocumentCodec.validate(document), isNull);
      final parsedTheme = DesignDocumentCodec.themeOf(document);
      expect(
        parsedTheme.colors[DesignColorRole.primary],
        '#2E7D32',
      );
      expect(parsedTheme.textScale, 'large');
      expect(parsedTheme.radiusScale, 'round');
    });
  });

  group('DesignDocumentCodec — التحقق الحي (مرآة app_design_is_valid)', () {
    final valid = DesignDocumentCodec.document(
      {'home': [EditableComponent(
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
      )]},
    );

    test('رمز المخطط', () {
      final broken = Map<String, dynamic>.from(valid)
        ..['schema_version'] = 3;
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
        {'page': 'home', 'root': {...root, 'children': [child]}},
      ];
      expect(DesignDocumentCodec.validate(broken), 'property_value');
    });

    test('مستند بلا صفحات يرفض', () {
      final broken = Map<String, dynamic>.from(valid)..['pages'] = [];
      expect(DesignDocumentCodec.validate(broken), 'pages');
    });
  });
}
