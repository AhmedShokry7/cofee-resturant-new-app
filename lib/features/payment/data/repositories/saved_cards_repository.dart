import 'package:flutter/foundation.dart';

import 'package:new_coffee/core/locale/app_copy.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/payment/data/model/saved_card_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show
        FunctionResponse,
        FunctionsHttpException,
        PostgrestException,
        SupabaseClient;

/// Why a save failed, so the failure is diagnosable rather than a shrug.
///
/// Every one of these used to collapse into "try again later", which is a lie
/// for [notConfigured]: no amount of retrying fixes a function that was never
/// deployed, and the message hid that from whoever deploys it.
enum SaveCardFailure {
  /// The card was refused by the provider (bad number, expired, declined).
  declined,

  /// The customer must sign in first.
  notSignedIn,

  /// The edge function is absent or not exposed. A build/deploy problem, not
  /// something the customer can act on, but it must never be reported as a
  /// transient failure.
  notConfigured,

  /// The provider or the network failed. Retrying may work.
  temporary,
}

/// Raised when a card could not be saved. [message] is already in the app's
/// language, so the UI shows it as-is and no provider error text ever reaches
/// the customer.
class SaveCardException implements Exception {
  const SaveCardException(
    this.reason, {
    this.failure = SaveCardFailure.temporary,
  });

  /// Why the customer cannot use this card, held as a token so the screen
  /// reads the sentence in the language they are using now.
  final AppCopy reason;
  final SaveCardFailure failure;

  String get message => reason.copy;

  @override
  String toString() => 'SaveCardException(${failure.name})';
}

abstract class SavedCardsRepository {
  Future<List<SavedCardModel>> listSavedCards();

  /// Tokenizes the card with the provider and stores it for reuse.
  ///
  /// [number] and [cvv] travel straight to the provider and are never written
  /// anywhere: only the token and the display fields are persisted.
  Future<SavedCardModel> saveCard({
    required String number,
    required String expiryMonth,
    required String expiryYear,
    required String cvv,
    required String holderName,
  });

  Future<void> deleteSavedCard(String id);

  /// Makes [id] the card this customer pays with by default.
  ///
  /// At most one card can be default; the server clears the others.
  Future<void> setDefaultCard(String id);
}

class SupabaseSavedCardsRepository implements SavedCardsRepository {
  SupabaseSavedCardsRepository({SupabaseClient? client})
    : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  void _requireSignedIn() {
    if (_client.auth.currentUser == null) {
      throw SaveCardException(
        AppCopy.cardSaveNotAllowed,
        failure: SaveCardFailure.notSignedIn,
      );
    }
  }

  @override
  Future<List<SavedCardModel>> listSavedCards() async {
    _requireSignedIn();
    final userId = _client.auth.currentUser!.id;
    final rows = await _client
        .from('saved_cards')
        .select()
        .eq('user_id', userId)
        .eq('is_active', true)
        .order('created_at', ascending: false);
    return [
      for (final row in (rows as List))
        if (row is Map<String, dynamic>) SavedCardModel.fromDatabase(row),
    ];
  }

  @override
  Future<SavedCardModel> saveCard({
    required String number,
    required String expiryMonth,
    required String expiryYear,
    required String cvv,
    required String holderName,
  }) async {
    _requireSignedIn();
    // A non-2xx invoke throws rather than resolving, and its `details` is the
    // decoded body — so the function's own error code is recovered from there.
    // Without this a declined card would read as saved.
    final FunctionResponse response;
    try {
      response = await _client.functions.invoke(
        'tap-tokenize-card',
        body: {
          'number': number,
          'expiryMonth': expiryMonth,
          'expiryYear': expiryYear,
          'cvv': cvv,
          'holderName': holderName,
        },
      );
    } on FunctionsHttpException catch (error) {
      throw classifyHttpError(error);
    } catch (error) {
      // No HTTP response at all: the network, or the function could not be
      // reached. Retryable.
      debugPrint('Save card failed before a response: $error');
      throw SaveCardException(
        AppCopy.saveCardFailed,
        failure: SaveCardFailure.temporary,
      );
    }

    final data = response.data;
    if (response.status != 201 || data is! Map<String, dynamic>) {
      throw classifyCode(data is Map ? data['error'] : null);
    }
    final card = SavedCardModel.fromDatabase({
      'id': data['id'],
      'brand': data['brand'],
      'last4': data['last4'],
      'expiry_month': data['expiryMonth'],
      'expiry_year': data['expiryYear'],
      'holder_name': data['holderName'],
      'is_active': true,
    });
    if (card.id.isEmpty) {
      throw SaveCardException(
        AppCopy.saveCardFailed,
        failure: SaveCardFailure.temporary,
      );
    }
    return card;
  }

  /// Classifies an HTTP-level failure.
  ///
  /// The 404 branch is the important one. Supabase answers an absent edge
  /// function with 404 and the body "Requested function was not found" — which
  /// used to fall into the generic catch and tell the customer to try again
  /// later, forever, for a function that was never deployed.
  @visibleForTesting
  static SaveCardException classifyHttpError(FunctionsHttpException error) {
    final details = error.details;
    final code = details is Map ? details['error'] : null;
    if (error.status == 404) {
      // Logged because it is a build problem, not a customer one, and without
      // this it is invisible: every customer sees the same polite message.
      debugPrint(
        'tap-tokenize-card is not deployed (404). Deploy the Edge Function '
        'before saving cards.',
      );
      return SaveCardException(
        AppCopy.cardSavingNotConfigured,
        failure: SaveCardFailure.notConfigured,
      );
    }
    if (error.status == 401 || error.status == 403) {
      return SaveCardException(
        AppCopy.cardSaveNotAllowed,
        failure: SaveCardFailure.notSignedIn,
      );
    }
    if (error.status == 422) return classifyCode(code ?? 'card_declined');
    if (error.status >= 500) {
      debugPrint('tap-tokenize-card returned ${error.status}');
      return SaveCardException(
        AppCopy.saveCardFailed,
        failure: SaveCardFailure.temporary,
      );
    }
    return classifyCode(code);
  }

  /// Maps the function's stable code to the customer's language, and to the
  /// failure category the cubit stores alongside it.
  ///
  /// Anything unrecognised becomes the generic retry message rather than the raw
  /// provider text, which can name the card network or echo the request back.
  @visibleForTesting
  static SaveCardException classifyCode(Object? code) {
    final name = code?.toString() ?? '';
    final failure = switch (name) {
      'invalid_card_number' ||
      'invalid_expiry' ||
      'invalid_cvv' ||
      'missing_holder_name' ||
      'card_declined' => SaveCardFailure.declined,
      'unauthorized' => SaveCardFailure.notSignedIn,
      'not_configured' => SaveCardFailure.notConfigured,
      _ => SaveCardFailure.temporary,
    };
    final reason = switch (name) {
      'invalid_card_number' => AppCopy.validCardNumber,
      'invalid_expiry' => AppCopy.invalidDate,
      'invalid_cvv' => AppCopy.invalidCvv,
      'missing_holder_name' => AppCopy.cardHolderRequired,
      'card_declined' => AppCopy.cardDeclined,
      'unauthorized' => AppCopy.cardSaveNotAllowed,
      'not_configured' => AppCopy.cardSavingNotConfigured,
      _ => AppCopy.saveCardFailed,
    };
    return SaveCardException(reason, failure: failure);
  }

  @override
  Future<void> deleteSavedCard(String id) async {
    _requireSignedIn();
    final FunctionResponse response;
    try {
      response = await _client.functions.invoke(
        'tap-delete-card',
        body: {'cardId': id},
      );
    } on FunctionsHttpException catch (error) {
      throw classifyDeleteHttpError(error);
    } catch (error) {
      debugPrint('Delete card failed before a response: $error');
      throw SaveCardException(
        AppCopy.cardDeleteFailed,
        failure: SaveCardFailure.temporary,
      );
    }

    // The function answers 200 with {deleted: false} when the provider refused,
    // so a resolved call is not proof the card is gone. Reading the flag is what
    // keeps a still-chargeable card from disappearing off the list.
    final refusal = deleteRefusalFor(
      status: response.status,
      data: response.data,
    );
    if (refusal != null) throw refusal;
  }

  /// The one answer `tap-delete-card` gives that means the card is gone.
  ///
  /// Returns null for it, and a failure the list can show for everything else:
  /// a refused provider call, a status that is not 200, or a body that does not
  /// say `deleted`.
  @visibleForTesting
  static SaveCardException? deleteRefusalFor({
    required int status,
    required Object? data,
  }) {
    if (status == 200 && data is Map && data['deleted'] == true) return null;
    final reason = data is Map ? data['error'] : null;
    debugPrint('tap-delete-card refused: status=$status error=$reason');
    return SaveCardException(
      AppCopy.cardDeleteFailed,
      failure: SaveCardFailure.temporary,
    );
  }

  @override
  Future<void> setDefaultCard(String id) async {
    _requireSignedIn();
    // The database owns this rule: `set_default_card` re-checks ownership,
    // takes a per-customer lock, clears the previous default and sets this one
    // in one transaction (073, bridged by proposals/223). The customer role has
    // no write grant on `public.saved_cards`, so there is no client-side
    // alternative that keeps the single-default invariant.
    try {
      await _client.rpc('set_default_card', params: {'p_card_id': id});
    } on PostgrestException catch (error) {
      throw classifyDefaultRpcError(error.code);
    }
  }

  /// Separates "this preference cannot be stored here" from "it did not land
  /// this time".
  ///
  /// PGRST202/42883 mean the bridge is not in the schema: no retry fixes that,
  /// and the customer's default stays exactly as it was, so the failure has to
  /// name the deploy rather than read as a hiccup.
  @visibleForTesting
  static SaveCardException classifyDefaultRpcError(Object? code) {
    final name = code?.toString() ?? '';
    if (name == 'PGRST202' || name == '42883') {
      debugPrint(
        'set_default_card is not in the database schema ($name). '
        'Apply supabase/proposals/223_public_bridge_set_default_card.',
      );
      return SaveCardException(
        AppCopy.cardSavingNotConfigured,
        failure: SaveCardFailure.notConfigured,
      );
    }
    return SaveCardException(
      AppCopy.saveCardFailed,
      failure: SaveCardFailure.temporary,
    );
  }

  /// Classifies a delete refusal the way [classifyHttpError] classifies a save.
  ///
  /// Kept apart because the two functions fail for different reasons: a 422
  /// from `tap-tokenize-card` is a bad card number the customer can correct,
  /// while a 4xx from `tap-delete-card` is a card that is not theirs, and
  /// naming a field would send them back to a form they never opened.
  @visibleForTesting
  static SaveCardException classifyDeleteHttpError(
    FunctionsHttpException error,
  ) {
    if (error.status == 404) {
      final details = error.details;
      final message = details is Map ? details['message']?.toString() : null;
      // Two different 404s. Supabase's own says the function was not found —
      // a build problem no retry fixes. The function's says this customer has
      // no such card, which usually means somebody deleted it in another
      // session and the list on screen is stale.
      if (message?.toLowerCase().contains('function') ?? false) {
        debugPrint(
          'tap-delete-card is not deployed (404). Deploy the Edge Function '
          'before deleting cards.',
        );
        return SaveCardException(
          AppCopy.cardSavingNotConfigured,
          failure: SaveCardFailure.notConfigured,
        );
      }
      return SaveCardException(
        AppCopy.cardAlreadyRemoved,
        failure: SaveCardFailure.declined,
      );
    }
    if (error.status == 401 || error.status == 403) {
      return SaveCardException(
        AppCopy.cardSaveNotAllowed,
        failure: SaveCardFailure.notSignedIn,
      );
    }
    debugPrint('tap-delete-card returned ${error.status}');
    return SaveCardException(
      AppCopy.cardDeleteFailed,
      failure: SaveCardFailure.temporary,
    );
  }
}
