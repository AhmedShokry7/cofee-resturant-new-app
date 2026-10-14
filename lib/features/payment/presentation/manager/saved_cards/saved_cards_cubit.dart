import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/services/shared_pref.dart';
import 'package:new_coffee/features/payment/data/model/saved_card_model.dart';
import 'package:new_coffee/features/payment/data/saved_cards_list.dart';
import 'package:new_coffee/shared/utils/card_brand.dart';

part 'saved_cards_state.dart';

class SavedCardsCubit extends Cubit<SavedCardsState> {
  SavedCardsCubit() : super(SavedCardsState(cards: getSavedCardsList()));

  static const _storageKey = 'saved_cards_v1';

  Future<void> load() async {
    try {
      final raw = await SharedPref.getValue(key: _storageKey);
      if (raw == null || raw.isEmpty || isClosed) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final cards = decoded
          .map(_cardFromJson)
          .whereType<SavedCardModel>()
          .toList();
      emit(SavedCardsState(cards: cards));
    } catch (_) {
      // Best-effort: keep the bundled cards rather than crash.
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
