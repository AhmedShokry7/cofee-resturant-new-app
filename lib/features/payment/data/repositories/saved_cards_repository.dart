import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/payment/data/model/saved_card_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class SavedCardsRepository {
  Future<List<SavedCardModel>> listSavedCards();
  Future<void> deleteSavedCard(String id);
}

class SupabaseSavedCardsRepository implements SavedCardsRepository {
  SupabaseSavedCardsRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  @override
  Future<List<SavedCardModel>> listSavedCards() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];
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
  Future<void> deleteSavedCard(String id) async {
    await _client.functions.invoke(
      'tap-delete-card',
      body: {'cardId': id},
    );
  }
}
