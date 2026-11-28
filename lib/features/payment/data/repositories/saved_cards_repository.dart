import 'package:flutter/foundation.dart';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:new_coffee/core/config/app_config.dart';
import 'package:new_coffee/core/locale/app_copy.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/payment/data/model/saved_card_model.dart';
import 'package:new_coffee/features/payment/data/moyasar_checkout_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show
        FunctionResponse,
        FunctionException,
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
    // The OS may reclaim the app while the bank's 3DS page is open. Recover
    // the pending token when the customer next opens their card list.
    await _recoverPendingCard(userId);
    final rows = await _client
        .from('saved_cards')
        .select()
        .eq('user_id', userId)
        .eq('is_active', true)
        .eq('provider', 'moyasar')
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
    // Cardholder data goes directly from the app to Moyasar with its public
    // key. Supabase only receives the resulting token ID after 3DS.
    final key = MoyasarCheckoutConfig.publishableKey;
    if (!key.startsWith('pk_test_') && !key.startsWith('pk_live_')) {
      throw const SaveCardException(
        AppCopy.cardSavingNotConfigured,
        failure: SaveCardFailure.notConfigured,
      );
    }
    final http.Response tokenResponse;
    try {
      tokenResponse = await http.post(
        Uri.parse('https://api.moyasar.com/v1/tokens'),
        headers: {
          'Authorization': 'Basic ${base64Encode(utf8.encode('$key:'))}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'name': holderName,
          'number': number,
          'month': int.parse(expiryMonth),
          'year': int.parse(expiryYear),
          'cvc': cvv,
          'callback_url':
              '${AppConfig.supabaseUrl}/functions/v1/moyasar-token-callback',
          'metadata': {'user_id': _client.auth.currentUser!.id},
        }),
      );
    } catch (_) {
      throw const SaveCardException(
        AppCopy.saveCardFailed,
        failure: SaveCardFailure.temporary,
      );
    }
    if (tokenResponse.statusCode < 200 || tokenResponse.statusCode >= 300) {
      throw const SaveCardException(
        AppCopy.cardDeclined,
        failure: SaveCardFailure.declined,
      );
    }
    final token = jsonDecode(tokenResponse.body);
    if (token is! Map || token['id'] is! String ||
        token['verification_url'] is! String) {
      throw const SaveCardException(AppCopy.saveCardFailed);
    }
    final tokenId = token['id'] as String;
    final userId = _client.auth.currentUser!.id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('moyasar_pending_card_$userId', tokenId);
    final verificationUrl = Uri.tryParse(token['verification_url'] as String);
    if (verificationUrl == null || verificationUrl.scheme != 'https') {
      throw const SaveCardException(AppCopy.saveCardFailed);
    }
    final launched = await launchUrl(
      verificationUrl,
      mode: LaunchMode.inAppBrowserView,
    );
    if (!launched) throw const SaveCardException(AppCopy.saveCardFailed);
    // The function fetches the token with Moyasar's secret key on every try.
    // Only an active, 3DS-verified token can become a saved card.
    for (var attempt = 0; attempt < 150; attempt++) {
      await Future<void>.delayed(const Duration(seconds: 2));
      try {
        final card = await _storeVerifiedCard(tokenId);
        if (card != null) {
          await prefs.remove('moyasar_pending_card_$userId');
          return card;
        }
      } on FunctionException catch (error) {
        // The 3DS redirect and the provider's token update are asynchronous.
        // Supabase may also briefly return a relay/network error while the
        // browser hands control back. Neither outcome means the card failed.
        if (error.status == 0 ||
            error.status == 409 ||
            error.status == 502 ||
            error.status == 503) {
          continue;
        }
        if (error is FunctionsHttpException) throw classifyHttpError(error);
        debugPrint('moyasar-save-card relay returned ${error.status}');
        throw const SaveCardException(AppCopy.saveCardFailed);
      }
    }
    throw const SaveCardException(AppCopy.saveCardFailed);
  }

  Future<SavedCardModel?> _storeVerifiedCard(String tokenId) async {
    final response = await _client.functions.invoke(
      'moyasar-save-card',
      body: {'tokenId': tokenId},
    );
    final data = response.data;
    if ((response.status == 200 || response.status == 201) &&
        data is Map<String, dynamic>) {
      final card = SavedCardModel.fromDatabase(data);
      if (card.id.isNotEmpty) return card;
    }
    return null;
  }

  Future<void> _recoverPendingCard(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'moyasar_pending_card_$userId';
    final tokenId = prefs.getString(key);
    if (tokenId == null || tokenId.isEmpty) return;
    try {
      final saved = await _storeVerifiedCard(tokenId);
      if (saved != null) await prefs.remove(key);
    } on FunctionException catch (error) {
      // A pending 3DS challenge is still retryable on the next visit. Invalid
      // or rejected tokens are removed so they cannot block the card list.
      if (error.status != 0 &&
          error.status != 409 &&
          error.status != 502 &&
          error.status != 503) {
        await prefs.remove(key);
      }
    } catch (_) {
      // Card listing remains available during a temporary network failure.
    }
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
        'moyasar-save-card is not deployed (404). Deploy the Edge Function '
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
      debugPrint('moyasar-save-card returned ${error.status}');
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
        'moyasar-delete-card',
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

  /// The one answer `moyasar-delete-card` gives that means the card is gone.
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
    debugPrint('moyasar-delete-card refused: status=$status error=$reason');
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
  /// from Moyasar is a bad card number the customer can correct,
  /// while a 4xx from card deletion is a card that is not theirs, and
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
          'moyasar-delete-card is not deployed (404). Deploy the Edge Function '
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
    debugPrint('moyasar-delete-card returned ${error.status}');
    return SaveCardException(
      AppCopy.cardDeleteFailed,
      failure: SaveCardFailure.temporary,
    );
  }
}
