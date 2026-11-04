import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/features/customer_preview/data/repositories/supabase_app_builder_repository.dart';
import 'package:admin_app/features/customer_preview/domain/entities/app_page.dart';
import 'package:admin_app/features/customer_preview/domain/registry/widget_registry.dart';

import 'helpers/stub_supabase_client.dart';

/// عقد اللوحة مع 226: أسماء الدوال ومعاملاتها وشكل ما ترجع.
///
/// الأسماء ليست تفصيلًا داخليًا: `admin_get_app_design` تقرأ معاملها في القاعدة
/// (`draft` أو `published`)، فاسم موضع محرَّف يرجع 22023 على الشاشة لا رسالة
/// ترجمة. والقراءة صارمة عن قصد: مستند نصف مقروء يرمي، فلا يُعرض ولا يُنشر.
void main() {
  final document = WidgetRegistry.defaultDocument();

  Map<String, Object?> versionRow({
    String id = '00000000-0000-0000-8000-000000000007',
    int number = 7,
    String publishedAt = '2026-11-03T10:15:00.000Z',
    int schemaVersion = 1,
    Object? note = 'افتتاحية',
  }) => <String, Object?>{
    'id': id,
    'version_number': number,
    'published_at': publishedAt,
    'schema_version': schemaVersion,
    'note': note,
  };

  group('قراءة المسودة والمنشور', () {
    test('المسودة تُقرأ باسم موضعها وتُفكّ إلى مستند', () async {
      final client = StubSupabaseFunctions(
        responses: <String, Object?>{'admin_get_app_design': document.toMap()},
      );

      final draft = await SupabaseAppBuilderRepository(client).loadDraft();

      expect(client.events, <String>['rpc:admin_get_app_design']);
      expect(client.params['admin_get_app_design'], <String, Object?>{
        'p_slot': 'draft',
      });
      expect(draft?.rootOf(AppPage.home), isNotNull);
    });

    test('المنشور يطلب الصف الذي يقرؤه تطبيق العميل', () async {
      final client = StubSupabaseFunctions(
        responses: <String, Object?>{'admin_get_app_design': document.toMap()},
      );

      await SupabaseAppBuilderRepository(client).loadPublished();

      expect(client.params['admin_get_app_design'], <String, Object?>{
        'p_slot': 'published',
      });
    });

    test('لا صف بعد = null، لا مستند فارغ', () async {
      final repository = SupabaseAppBuilderRepository(StubSupabaseFunctions());

      expect(await repository.loadDraft(), isNull);
      expect(await repository.loadPublished(), isNull);
    });

    test('مستند لا يرسمه المحرّر يرمي ولا يُعرض نصفًا', () async {
      final client = StubSupabaseFunctions(
        responses: <String, Object?>{
          'admin_get_app_design': <String, Object?>{
            'schema_version': 1,
            'pages': <Object?>[
              <String, Object?>{
                'page': 'checkout',
                'root': <String, Object?>{'id': 'x', 'type': 'page'},
              },
            ],
          },
        },
      );

      await expectLater(
        SupabaseAppBuilderRepository(client).loadDraft(),
        throwsA(isA<FormatException>()),
      );
    });

    test('مستند النسخة الأولى يعود بختم اللوحة الحيّة', () async {
      // المحرّر يرقّي الختم وحده عند القراءة، لا يعيد كتابة الشجرة: المستند
      // المخزّن قبل طبقة الشكل يُقرأ كما هو ويُقبل النشر من جديد، وإلا كانت كل
      // مسودة محفوظة منذ 226 تحتاج يدًا في القاعدة قبل أن تُفتح.
      final stored = <Object?, Object?>{
        ...document.toMap(),
        'schema_version': 1,
      };
      final client = StubSupabaseFunctions(
        responses: <String, Object?>{'admin_get_app_design': stored},
      );

      final draft = await SupabaseAppBuilderRepository(client).loadDraft();
      expect(draft?.schemaVersion, WidgetRegistry.schemaVersion);
      expect(
        draft?.rootOf(AppPage.home)?.toMap(),
        document.rootOf(AppPage.home)?.toMap(),
      );
      expect(draft?.theme.isDefault, isTrue);
    });

    test('طبقة شكل لا يعرفها المحرّر ترمي ولا تُعرض', () async {
      final client = StubSupabaseFunctions(
        responses: <String, Object?>{
          'admin_get_app_design': <Object?, Object?>{
            ...document.toMap(),
            'theme': <String, Object?>{
              'colors': <String, Object?>{'accent': '#FF0000'},
            },
          },
        },
      );

      await expectLater(
        SupabaseAppBuilderRepository(client).loadDraft(),
        throwsA(isA<FormatException>()),
      );
    });

    test('رفض القاعدة يصل كما هو', () async {
      final client = StubSupabaseFunctions(
        errors: <String, Object>{
          'admin_get_app_design': StateError('missing permission: design.edit'),
        },
      );

      await expectLater(
        SupabaseAppBuilderRepository(client).loadDraft(),
        throwsStateError,
      );
    });
  });

  group('كتابة المسودة', () {
    test('الحفظ يرسل المستند كله كما يُنشر', () async {
      final client = StubSupabaseFunctions();

      await SupabaseAppBuilderRepository(client).saveDraft(document);

      expect(client.events, <String>['rpc:admin_save_app_design_draft']);
      expect(
        client.params['admin_save_app_design_draft']!['p_document'],
        document.toMap(),
      );
    });

    test('التجاهل يندّد بدالة الحذف وحدها وبلا معاملات', () async {
      final client = StubSupabaseFunctions();

      await SupabaseAppBuilderRepository(client).discardDraft();

      expect(client.events, <String>['rpc:admin_discard_app_design_draft']);
      expect(
        client.params.containsKey('admin_discard_app_design_draft'),
        isFalse,
      );
    });
  });

  group('النشر والرجوع', () {
    test('النشر يرجع صفّ الإصدار الذي كتبته القاعدة', () async {
      final client = StubSupabaseFunctions(
        responses: <String, Object?>{
          'admin_publish_app_design': versionRow(number: 12),
        },
      );

      final version = await SupabaseAppBuilderRepository(client)
          .publish(document);

      expect(client.events, <String>['rpc:admin_publish_app_design']);
      expect(
        client.params['admin_publish_app_design']!['p_document'],
        document.toMap(),
      );
      expect(version.number, 12);
      expect(version.schemaVersion, 1);
      expect(version.note, 'افتتاحية');
      expect(version.publishedAt, DateTime.parse('2026-11-03T10:15:00.000Z'));
    });

    test('نشر بلا رقم إصدار خطأٌ مسمّى، لا إصدار صفر', () async {
      final repository = SupabaseAppBuilderRepository(StubSupabaseFunctions());

      await expectLater(
        repository.publish(document),
        throwsA(isA<AppBuilderPublishException>()),
      );
    });

    test('الرجوع يرسل المعرّف ويرجع الإصدار الجديد', () async {
      final client = StubSupabaseFunctions(
        responses: <String, Object?>{
          'admin_restore_app_design_version': versionRow(
            number: 13,
            note: 'restored from version 12',
          ),
        },
      );

      final version = await SupabaseAppBuilderRepository(client)
          .restoreVersion('00000000-0000-0000-8000-000000000007');

      expect(
        client.params['admin_restore_app_design_version'],
        <String, Object?>{
          'p_version_id': '00000000-0000-0000-8000-000000000007',
        },
      );
      expect(version.number, 13);
      expect(version.note, 'restored from version 12');
    });

    test('معرّف فارغ لا يذهب إلى القاعدة', () async {
      final client = StubSupabaseFunctions();

      expect(
        await SupabaseAppBuilderRepository(client).loadVersion(''),
        isNull,
      );
      expect(client.events, isEmpty);
    });

    test('ملفّ إصدار يُقرأ مستندًا كاملًا', () async {
      final client = StubSupabaseFunctions(
        responses: <String, Object?>{
          'admin_get_app_design_version': document.toMap(),
        },
      );

      final file = await SupabaseAppBuilderRepository(client)
          .loadVersion('00000000-0000-0000-8000-000000000007');

      expect(file?.hasSameContent(document), isTrue);
    });
  });

  group('سجلّ الإصدارات', () {
    test('الصفوف تصدر بالترتيب الذي أرسلته القاعدة', () async {
      final client = StubSupabaseFunctions(
        responses: <String, Object?>{
          'admin_list_app_design_versions': <Object?>[
            versionRow(number: 3),
            versionRow(number: 2, note: null),
          ],
        },
      );

      final versions = await SupabaseAppBuilderRepository(client)
          .loadVersions();

      expect(client.params['admin_list_app_design_versions'], <String, Object?>{
        'p_limit': 30,
      });
      expect(versions.map((version) => version.number), <int>[3, 2]);
      expect(versions.last.note, isNull);
    });

    test('تاريخ لا يقرأ يبقى على حقيقته ولا يُختلق الآن', () async {
      final client = StubSupabaseFunctions(
        responses: <String, Object?>{
          'admin_list_app_design_versions': <Object?>[
            versionRow(publishedAt: 'not a date'),
          ],
        },
      );

      final versions = await SupabaseAppBuilderRepository(client)
          .loadVersions();

      expect(versions.single.publishedAt.isUtc, isTrue);
      expect(versions.single.publishedAt.year, 1970);
    });

    test('سجلّ فارغ قائمة فارغة', () async {
      expect(
        await SupabaseAppBuilderRepository(StubSupabaseFunctions())
            .loadVersions(),
        isEmpty,
      );
    });
  });
}
