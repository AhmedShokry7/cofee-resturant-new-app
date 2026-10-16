import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/services/shared_pref.dart';
import 'package:new_coffee/features/payment/data/model/saved_card_model.dart';
import 'package:new_coffee/shared/utils/card_brand.dart';

part 'saved_cards_state.dart';

/// Saved payment cards, stored on the device.
///
/// There is deliberately no server table for saved cards: no order references
/// one, and a card number is not an address. These rows stay local, and the
/// list starts empty: only cards the customer actually adds are ever shown.
class SavedCardsCubit extends Cubit<SavedCardsState> {
  SavedCardsCubit() : super(const SavedCardsState(cards: []));

  static const _storageKey = 'saved_cards_v1';

  Future<void> load() async {
    try {
      final raw = await SharedPref.getValue(key: _storageKey);
      if (raw == null || raw.isEmpty || isClosed) {
        if (!isClosed) emit(const SavedCardsState(cards: []));
        return;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final cards = decoded
          .map(_cardFromJson)
          .whereType<SavedCardModel>()
          .toList();
      emit(SavedCardsState(cards: cards));
    } catch (_) {
      // Best-effort: an unreadable store yields an empty list, never an error.
      if (!isClosed) emit(const SavedCardsState(cards: []));
    }
  }

  void addCard(SavedCardModel card) {
    emit(SavedCardsState(cards: [...state.cards, card]));
    _persist();
  }

  void removeCard(String id) {
    emit(
      SavedCardsState(
        cards: state.cards.where((card) => card.id != id).toList(),
      ),
    );
    _persist();
  }

  static SavedCardModel? _cardFromJson(dynamic value) {
    if (value is! Map) return null;
    try {
      return SavedCardModel(
        id: value['id']?.toString() ?? '',
        brand: CardBrand.values.firstWhere(
          (brand) => brand.name == value['brand']?.toString(),
          orElse: () => CardBrand.unknown,
        ),
        last4: value['last4']?.toString() ?? '',
        holder: value['holder']?.toString() ?? '',
        expiry: value['expiry']?.toString() ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic> _cardToJson(SavedCardModel card) => {
    'id': card.id,
    'brand': card.brand.name,
    'last4': card.last4,
    'holder': card.holder,
    'expiry': card.expiry,
  };

  Future<void> _persist() async {
    try {
      await SharedPref.setValue(
        key: _storageKey,
        value: jsonEncode(state.cards.map(_cardToJson).toList()),
      );
    } catch (_) {
      // Best-effort: never break card management if storage fails.
    }
  }
}
