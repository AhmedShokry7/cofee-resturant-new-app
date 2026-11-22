import 'package:flutter_test/flutter_test.dart';
import 'package:new_coffee/core/preview/preview_bridge.dart';
import 'package:new_coffee/core/preview/preview_repositories.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/design/data/design_preview_store.dart';
import 'package:new_coffee/features/design/presentation/manager/design/design_cubit.dart';

void main() {
  tearDown(() {
    DesignPreviewStore.instance.setDocument(null);
    SupabaseService.debugReset();
  });

  test(
    'preview stays a guest: session is never restored and sign-in is blocked',
    () async {
      SupabaseService.debugSetSignedIn(true);
      SupabaseService.enterPreviewMode();
      expect(SupabaseService.isPreviewMode, isTrue);
      // حتى لو وُجدت جلسة في مخزن التطبيق الحقيقي، المعاينة زبون مجهول:
      // لا سلة خادم ولا عناوين ولا طلبات باسم أحد.
      expect(SupabaseService.isSignedIn, isFalse);
      expect(const PreviewAuthRepository().currentUser(), completion(isNull));
    },
  );

  test(
    'preview design repository reads only the in-memory draft document',
    () async {
      final draft = <String, dynamic>{
        'schema_version': 1,
        'pages': <Object>[
          <String, Object?>{
            'page': 'home',
            'root': <String, Object?>{
              'type': 'page.home',
              'children': <Object>[
                <String, Object?>{
                  'id': 'draft-title',
                  'type': 'section.text',
                  'properties': <String, Object?>{'text': 'Studio Draft'},
                },
              ],
            },
          },
        ],
      };
      DesignPreviewStore.instance.setDocument(draft);

      final cubit = DesignCubit(repository: const PreviewDesignRepository());
      await cubit.initialLoad;

      expect(cubit.state.isLoaded, isTrue);
      expect(cubit.state.homeSections.single.id, 'draft-title');
      expect(
        cubit.state.homeSections.single.properties['text'],
        'Studio Draft',
      );
      expect(DesignPreviewStore.instance.document, same(draft));
      expect(SupabaseService.isReady, isFalse);
      await cubit.close();
    },
  );

  test(
    'preview protocol rejects unknown messages and accepts a session draft',
    () {
      final accepted = PreviewMessage.fromJson(<String, Object?>{
        'protocolVersion': '1.0',
        'messageId': 'test-1',
        'sessionId': 'session-1',
        'type': 'APPLY_DESIGN_CONFIG',
        'payload': <String, Object?>{
          'designDocument': <String, Object?>{
            'schema_version': 1,
            'pages': <Object>[],
          },
        },
      });
      final rejected = PreviewMessage.fromJson(<String, Object?>{
        'protocolVersion': '1.0',
        'messageId': 'test-2',
        'sessionId': 'session-1',
        'type': 'RUN_ARBITRARY_COMMAND',
        'payload': <String, Object?>{},
      });

      expect(accepted?.type, PreviewMessageType.applyDesignConfig);
      expect(accepted?.payload['designDocument'], isA<Map>());
      expect(rejected, isNull);
    },
  );

  test('preview writes for payments and profile media fail closed', () async {
    await expectLater(
      const PreviewPaymentRepository().verifyCharge('charge-id'),
      throwsStateError,
    );
    await expectLater(
      const PreviewProfilePhotoRepository().removeAvatar(),
      throwsA(isA<Exception>()),
    );
  });
}
