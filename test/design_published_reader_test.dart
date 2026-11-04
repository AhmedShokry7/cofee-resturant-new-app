import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/features/design/data/design_applier.dart';
import 'package:new_coffee/features/design/data/model/published_design.dart';
import 'package:new_coffee/features/design/data/repositories/design_repository.dart';
import 'package:new_coffee/shared/utils/cache_manager.dart';

/// قارئ التصميم المنشور: العقد مع ما ينشره الموظف، لا مع ذوق اللوحة.
///
/// الصف الذي لا يُقرأ لا يترك شاشة زبون بيضاء، والدور الذي لم يُنشر يبقى على
/// قيمته التي كان عليها التطبيق — وهذان الوعدان هما ما تُفحصه هذه الملفات.
void main() {
  setUp(() {
    CacheManager().clear();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    applyPublishedTheme(PublishedTheme.none);
  });

  group('طبعة المنشور تُقرأ كما كُتبت', () {
    test('لا طبقة: كل دور على أصله ومقياس الخط واحد', () {
      final theme = PublishedTheme.fromJson(<Object?, Object?>{});
      expect(theme.isNeutral, isTrue);
      expect(theme.textFactor, 1);
    });

    test('الستة التي يملكها الاستوديو تُقرأ بأدوارها', () {
      final theme = PublishedTheme.fromJson(<Object?, Object?>{
        'colors': <Object?, Object?>{
          'primary': '#C09060',
          'secondary': '#102030',
          'surface': '#F0E8DC',
          'background': '#FFFDF8',
          'text_primary': '#121212',
          'text_secondary': '#6B6B6B',
          'border': '#DED6C8',
        },
      });
      expect(theme.colors, hasLength(7));
      expect(theme.color(ThemeColorRole.primary), const Color(0xFFC09060));
      expect(theme.color(ThemeColorRole.border), const Color(0xFFDED6C8));
    });

    test('الشفافية في #AARRGGBB محترمة', () {
      final theme = PublishedTheme.fromJson(<Object?, Object?>{
        'colors': <Object?, Object?>{'primary': '#80FF0000'},
      });
      expect(theme.color(ThemeColorRole.primary), const Color(0x80FF0000));
    });

    test('مقياس الخط باسمه، والمجهول يترك 1', () {
      expect(
        PublishedTheme.fromJson(<Object?, Object?>{'text_scale': 'large'})
            .textFactor,
        1.15,
      );
      expect(
        PublishedTheme.fromJson(<Object?, Object?>{'text_scale': 'giant'})
            .textFactor,
        1,
      );
    });

    test('دور لا يعرفه القارئ أو لون تالف يُتجاهلان وحدهما', () {
      // القاعدة ترفض هذا قبل النشر، لكنه يصل من صف كتبه مصدر آخر: الزبون لا
      // يفقد بقية الطبقة من أجل سطر لا يُفهم.
      final theme = PublishedTheme.fromJson(<Object?, Object?>{
        'colors': <Object?, Object?>{
          'primary': '#C09060',
          'glow': '#FF00AA',
          'surface': 'red',
        },
      });
      expect(theme.colors.keys, <ThemeColorRole>[ThemeColorRole.primary]);
    });

    test('مستند بنسخة أحدث لا يغيّر شيئًا', () {
      expect(
        PublishedDesign.fromJson(<Object?, Object?>{
          'schema_version': 3,
          'pages': <Object?>[],
        }),
        isNull,
      );
    });

    test('مستند النسخة الأولى بلا طبقة، ومخطط 2 بطبقة', () {
      expect(
        PublishedDesign.fromJson(<Object?, Object?>{'schema_version': 1})!
            .theme
            .isNeutral,
        isTrue,
      );
      expect(
        PublishedDesign.fromJson(<Object?, Object?>{
          'schema_version': 2,
          'theme': <Object?, Object?>{
            'colors': <Object?, Object?>{'primary': '#00FF00'},
          },
        })!
            .theme
            .color(ThemeColorRole.primary),
        const Color(0xFF00FF00),
      );
    });
  });

  group('التطبيق يكتب الأدوار ويرجع عنها', () {
    test('دور منشور يكتب موضعه، والبقية تبقى على أصلها', () {
      applyPublishedTheme(
        PublishedTheme.fromJson(<Object?, Object?>{
          'colors': <Object?, Object?>{'primary': '#C09060'},
        }),
      );
      expect(AppColor.primaryColor, const Color(0xFFC09060));
      expect(AppColor.secondryColor, AppColor.secondryDefault);
      expect(AppColor.borderColor, AppColor.borderDefault);
      expect(AppColor.cardSurface, AppColor.cardSurfaceDefault);
    });

    test('طبعة لاحقة لا تترك لونًا من المستند الملغى', () {
      applyPublishedTheme(
        PublishedTheme.fromJson(<Object?, Object?>{
          'colors': <Object?, Object?>{
            'primary': '#C09060',
            'border': '#DED6C8',
          },
        }),
      );
      applyPublishedTheme(
        PublishedTheme.fromJson(<Object?, Object?>{
          'colors': <Object?, Object?>{'border': '#111111'},
        }),
      );
      // دور في الطبقة الجديدة: يكتب. دور خرج منها: يرجع لأصله لا للأول.
      expect(AppColor.borderColor, const Color(0xFF111111));
      expect(AppColor.primaryColor, AppColor.primaryDefault);
    });

    test('الأدوار الثلاثة الباقية لا تموضع لها فلا تغيّر شيئًا', () {
      applyPublishedTheme(
        PublishedTheme.fromJson(<Object?, Object?>{
          'colors': <Object?, Object?>{
            'success': '#00FF00',
            'error': '#FF0000',
            'disabled': '#888888',
          },
        }),
      );
      expect(AppColor.successColor, const Color(0xFF22C55E));
      expect(AppColor.errorColor, const Color(0xFFDC2626));
    });

    test('مقياس الخط فوق مقياس الجهاز لا بدلًا منه', () {
      expect(
        PublishedTheme.fromJson(<Object?, Object?>{'text_scale': 'large'})
            .textFactor,
        1.15,
      );
    });
  });

  group('اللف بمقياس الخط', () {
    testWidgets('عند 1 تُترك الشجرة كما هي', (tester) async {
      const child = Text('x');
      late Widget wrapped;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              wrapped = applyDesignTextScale(
                context: context,
                factor: 1,
                child: child,
              );
              return wrapped;
            },
          ),
        ),
      );
      expect(wrapped, same(child));
    });

    testWidgets('المضاعف يُضرب في مقياس الجهاز', (tester) async {
      late double scaled;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.2)),
          child: MaterialApp(
            home: Builder(
              builder: (outer) => applyDesignTextScale(
                context: outer,
                factor: 1.15,
                child: Builder(
                  builder: (inner) {
                    scaled = MediaQuery.textScalerOf(inner).scale(10);
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
          ),
        ),
      );
      expect(scaled, closeTo(10 * 1.2 * 1.15, 0.0001));
    });
  });

  group('المستودع يقرأ الجسر العام', () {
    late _SettingsServer server;

    setUp(() async {
      // اختبار شاشة يترك الشبكة مموّهة في هذا الملف؛ الصف هنا يُقرأ من خادم
      // محلي حقيقي، لا من وهم يجيب كل طلب بأربعمئة.
      HttpOverrides.global = null;
      server = await _SettingsServer.start();
    });
    tearDown(() async {
      await server.close();
    });

    test('صف منشور: المستند يُقرأ ويُحفظ للنسخة الاحتياطية', () async {
      server.rows = <Object?>[
        <String, Object?>{
          'value': <String, Object?>{
            'schema_version': 2,
            'theme': <String, Object?>{
              'colors': <String, Object?>{'primary': '#C09060'},
            },
          },
        },
      ];
      final repository = SupabaseDesignRepository(client: server.client);
      final design = await repository.published();
      expect(design!.theme.color(ThemeColorRole.primary), const Color(0xFFC09060));
      expect(server.query, contains('key=eq.app_design_published'));
      expect(server.query, contains('is_public=eq.true'));

      final stored = await repository.lastKnown();
      expect(stored!.theme, design.theme);
    });

    test('لا صف: طبقة محايدة، والنسخة القديمة تُمحى', () async {
      server.rows = <Object?>[
        <String, Object?>{
          'value': <String, Object?>{
            'schema_version': 2,
            'theme': <String, Object?>{
              'colors': <String, Object?>{'primary': '#C09060'},
            },
          },
        },
      ];
      final repository = SupabaseDesignRepository(client: server.client);
      await repository.published();
      expect(await repository.lastKnown(), isNotNull);

      server.rows = <Object?>[];
      final cleared = await repository.published(forceRefresh: true);
      expect(cleared, same(PublishedDesign.none));
      // الموظف رجع للأصل: زبون بلا شبكة يراه هو الآخر بلا طبقة.
      expect(await repository.lastKnown(), isNull);
    });

    test('عطل القراءة يرجع لآخر طبعة صالحة', () async {
      server.rows = <Object?>[
        <String, Object?>{
          'value': <String, Object?>{
            'schema_version': 2,
            'theme': <String, Object?>{
              'colors': <String, Object?>{'border': '#123456'},
            },
          },
        },
      ];
      final repository = SupabaseDesignRepository(client: server.client);
      await repository.published();

      server.status = 500;
      final fallback = await repository.published(forceRefresh: true);
      expect(
        fallback!.theme.color(ThemeColorRole.border),
        const Color(0xFF123456),
      );
    });

    test('الذاكرة تخدم بلا رحلة ثانية للقاعدة', () async {
      server.rows = <Object?>[];
      final repository = SupabaseDesignRepository(client: server.client);
      await repository.published();
      final before = server.requests;
      final again = await repository.published();
      expect(again, isNotNull);
      expect(server.requests, before);
    });

    test('بلا عميل وبلا نسخة محفوظة: لا طبقة ولا استثناء', () async {
      final repository = SupabaseDesignRepository(client: null);
      // العميل الحقيقي غير مهيّأ في الاختبار، فالقراءة تجيب بnull وترجع للنسخة.
      expect(await repository.published(), isNull);
    });
  });
}

/// جسر `public.app_settings` مزيّف: يردّ بما يُطلب منه، ويسجّل ما طُلب.
class _SettingsServer {
  _SettingsServer._(this._server);

  static Future<_SettingsServer> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final instance = _SettingsServer._(server);
    instance._serve();
    return instance;
  }

  final HttpServer _server;

  /// الصفوف التي يردّها، وحالة الردّ.
  Object? rows = <Object?>[];
  int status = 200;

  int requests = 0;
  String query = '';

  SupabaseClient get client => SupabaseClient(origin, 'anon-key');

  String get origin => 'http://127.0.0.1:${_server.port}';

  void _serve() {
    _server.listen((request) async {
      requests++;
      query = request.uri.query;
      final known = request.uri.path.startsWith('/rest/v1/app_settings');
      request.response.statusCode = known ? status : HttpStatus.notFound;
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode(
          !known || status == 200
              ? rows
              : <String, Object?>{'message': 'unavailable'},
        ),
      );
      await request.response.close();
    });
  }

  Future<void> close() => _server.close(force: true);
}
