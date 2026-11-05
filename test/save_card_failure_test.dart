import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show FunctionsHttpException;

import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/payment/data/repositories/saved_cards_repository.dart';

/// Cover for classifying a card-save failure.
///
/// The bug this exists for: Supabase answers an absent edge function with 404
/// and the body "Requested function was not found". That fell into the generic
/// catch, which told the customer to try again later — forever, for a function
/// that was never deployed, with nothing logged and nothing distinguishable.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  FunctionsHttpException http(int status, {Object? details}) =>
      FunctionsHttpException(status: status, details: details);

  group('a function that is not deployed', () {
    test('is never reported as a retryable failure', () {
      final error = SupabaseSavedCardsRepository.classifyHttpError(
        http(
          404,
          details: {
            'code': 'NOT_FOUND',
            'message': 'Requested function was not found',
          },
        ),
      );

      expect(error.failure, SaveCardFailure.notConfigured);
      // The old bug: this is what told the customer to try again, endlessly.
      expect(error.failure, isNot(SaveCardFailure.temporary));
      expect(error.message, S.cardSavingNotConfigured);
      expect(error.message, isNot(S.saveCardFailed));
    });
  });

  group('other statuses', () {
    test('401 and 403 mean sign in', () {
      expect(
        SupabaseSavedCardsRepository.classifyHttpError(http(401)).failure,
        SaveCardFailure.notSignedIn,
      );
      expect(
        SupabaseSavedCardsRepository.classifyHttpError(http(403)).failure,
        SaveCardFailure.notSignedIn,
      );
    });

    test('5xx is retryable', () {
      for (final status in [500, 502, 503]) {
        final error = SupabaseSavedCardsRepository.classifyHttpError(
          http(status),
        );
        expect(error.failure, SaveCardFailure.temporary);
        expect(error.message, S.saveCardFailed);
      }
    });

    test('422 carries the provider code through', () {
      final error = SupabaseSavedCardsRepository.classifyHttpError(
        http(422, details: {'error': 'card_declined'}),
      );
      expect(error.failure, SaveCardFailure.declined);
      expect(error.message, S.cardDeclined);
    });

    test('422 with no code still reads as declined, not as an outage', () {
      final error = SupabaseSavedCardsRepository.classifyHttpError(http(422));
      expect(error.failure, SaveCardFailure.declined);
    });
  });

  group('provider codes', () {
    test('each maps to its own field message', () {
      final cases = {
        'invalid_card_number': S.validCardNumber,
        'invalid_expiry': S.invalidDate,
        'invalid_cvv': S.invalidCvv,
        'missing_holder_name': S.cardHolderRequired,
        'card_declined': S.cardDeclined,
        'unauthorized': S.cardSaveNotAllowed,
        'not_configured': S.cardSavingNotConfigured,
      };
      cases.forEach((code, message) {
        final error = SupabaseSavedCardsRepository.classifyCode(code);
        expect(error.message, message, reason: code);
      });
    });

    test('an unrecognised code is retryable and never raw', () {
      final error = SupabaseSavedCardsRepository.classifyCode(
        'Visa Gateway Timeout on host internal-abc',
      );
      expect(error.failure, SaveCardFailure.temporary);
      expect(error.message, S.saveCardFailed);
      expect(error.message, isNot(contains('Visa')));
    });

    test('a null code is safe', () {
      expect(
        SupabaseSavedCardsRepository.classifyCode(null).failure,
        SaveCardFailure.temporary,
      );
    });
  });

  group('the labels', () {
    test('the card says "Card Holder", not "Card Holder Name"', () {
      AppLocale.instance.debugSet(AppLanguage.english);
      expect(S.cardHolderName, 'Card Holder');
      AppLocale.instance.debugSet(AppLanguage.arabic);
      expect(S.cardHolderName, 'حامل البطاقة');
    });

    test('the required message still reads as a sentence', () {
      AppLocale.instance.debugSet(AppLanguage.english);
      expect(S.cardHolderRequired.toLowerCase(), contains('required'));
      expect(S.cardHolderRequired, isNot(S.cardHolderName));
    });

    test('the unavailable message is real Arabic, and real English', () {
      AppLocale.instance.debugSet(AppLanguage.arabic);
      expect(
        RegExp('[\u0600-\u06FF]').hasMatch(S.cardSavingNotConfigured),
        isTrue,
      );
      AppLocale.instance.debugSet(AppLanguage.english);
      expect(
        RegExp('[\u0600-\u06FF]').hasMatch(S.cardSavingNotConfigured),
        isFalse,
      );
    });
  });

  group('a delete that did not happen', () {
    SaveCardException? refuse(int status, Object? data) =>
        SupabaseSavedCardsRepository.deleteRefusalFor(
          status: status,
          data: data,
        );

    test('only deleted:true says the card is gone', () {
      expect(refuse(200, {'deleted': true}), isNull);
    });

    test('the provider refusing is a failure, not a success', () {
      // The bug this covers: `invoke()` resolving was taken as proof, so a
      // 200 with {deleted: false} dropped a still-chargeable card off the list.
      final error = refuse(200, {'deleted': false, 'error': 'provider_down'});
      expect(error, isNotNull);
      expect(error!.failure, SaveCardFailure.temporary);
      expect(error.message, S.cardDeleteFailed);
    });

    test('a body that never answers is a failure', () {
      expect(refuse(200, {'error': 'boom'}), isNotNull);
      expect(refuse(200, null), isNotNull);
      expect(refuse(200, 'deleted'), isNotNull);
    });

    test('a non-200 that still claims success is a failure', () {
      expect(refuse(502, {'deleted': true}), isNotNull);
    });
  });

  group('a delete refused over HTTP', () {
    FunctionsHttpException httpError(int status, {Object? details}) =>
        FunctionsHttpException(status: status, details: details);

    test('an absent function is a deploy problem, not a retry', () {
      final error = SupabaseSavedCardsRepository.classifyDeleteHttpError(
        httpError(
          404,
          details: {
            'message': 'Requested function "tap-delete-card" not found',
          },
        ),
      );
      expect(error.failure, SaveCardFailure.notConfigured);
      expect(error.message, S.cardSavingNotConfigured);
    });

    test('a card the account no longer has is not a deploy problem', () {
      final error = SupabaseSavedCardsRepository.classifyDeleteHttpError(
        httpError(404, details: {'error': 'Card not found'}),
      );
      expect(error.failure, SaveCardFailure.declined);
      expect(error.message, S.cardAlreadyRemoved);
    });

    test('a session that went away says sign in', () {
      for (final status in [401, 403]) {
        final error = SupabaseSavedCardsRepository.classifyDeleteHttpError(
          httpError(status),
        );
        expect(error.failure, SaveCardFailure.notSignedIn, reason: '$status');
      }
    });

    test('a provider outage is retryable and says so in app words', () {
      final error = SupabaseSavedCardsRepository.classifyDeleteHttpError(
        httpError(
          502,
          details: {'error': 'Tap gateway timeout on host internal'},
        ),
      );
      expect(error.failure, SaveCardFailure.temporary);
      expect(error.message, S.cardDeleteFailed);
      expect(error.message, isNot(contains('Tap gateway')));
    });
  });

  group('a default the database refused', () {
    test('a bridge that is not installed is named as one', () {
      for (final code in ['PGRST202', '42883']) {
        final error = SupabaseSavedCardsRepository.classifyDefaultRpcError(
          code,
        );
        expect(error.failure, SaveCardFailure.notConfigured, reason: code);
        expect(error.message, S.cardSavingNotConfigured, reason: code);
      }
    });

    test('a row locked elsewhere stays retryable', () {
      final error = SupabaseSavedCardsRepository.classifyDefaultRpcError(
        '23505',
      );
      expect(error.failure, SaveCardFailure.temporary);
      // The preference write failing must not read as "cards cannot be saved".
      expect(error.message, S.saveCardFailed);
    });

    test('a missing code is retryable and never raw', () {
      expect(
        SupabaseSavedCardsRepository.classifyDefaultRpcError(null).failure,
        SaveCardFailure.temporary,
      );
    });
  });
}
