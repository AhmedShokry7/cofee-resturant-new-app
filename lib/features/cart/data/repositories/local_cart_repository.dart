import 'dart:convert';

import 'package:new_coffee/core/services/shared_pref.dart';
import 'package:new_coffee/features/cart/data/repositories/cart_repository.dart';

class LocalCartRepository implements CartRepository {
  LocalCartRepository();

  static const _storageKey = 'cart_v1_local';

  @override
  Future<void> addItem({
    required String productId,
    required int quantity,
    required String note,
    required List<String> optionValueIds,
    required double unitPrice,
    String? bundleId,
  }) async {
    final raw = await SharedPref.getValue(key: _storageKey);
    List<dynamic> items = raw != null && raw.isNotEmpty ? jsonDecode(raw) as List<dynamic> : [];
    final index =
        items.indexWhere((item) => item['productId'] == productId && _sameNoteAndOptions(item, note, optionValueIds));

    if (index == -1) {
      items.add({
        'productId': productId,
        'quantity': quantity,
        'note': note,
        'optionValueIds': optionValueIds,
        'unitPrice': unitPrice,
      });
    } else {
      items[index]['quantity'] = (items[index]['quantity'] ?? 0 + quantity).clamp(1, 99);
    }
    await SharedPref.setValue(key: _storageKey, value: jsonEncode(items));
  }

  @override
  Future<void> removeItem(String lineId) async {
    final raw = await SharedPref.getValue(key: _storageKey);
    List<dynamic> items = raw != null && raw.isNotEmpty ? jsonDecode(raw) as List<dynamic> : [];
    final parts = lineId.split('::');
    if (parts.isEmpty) return;
    final productId = parts[0];
    items.removeWhere((item) => item['productId'] == productId);
    await SharedPref.setValue(key: _storageKey, value: jsonEncode(items));
  }

  @override
  Future getCartSummary() async {
    final raw = await SharedPref.getValue(key: _storageKey);
    List<dynamic> items = raw != null && raw.isNotEmpty ? jsonDecode(raw) as List<dynamic> : [];
    return items.map((item) => {
      'productId': item['productId'],
      'quantity': item['quantity'],
      'note': item['note'],
      'optionValueIds': List<String>.from(item['optionValueIds'] ?? []),
      'unitPrice': item['unitPrice'],
    }).toList();
  }

  @override
  Future<void> clearCart() async {
    await SharedPref.setValue(key: _storageKey, value: jsonEncode([]));
  }

  bool _sameNoteAndOptions(Map<String, dynamic> a, String note, List<String> optionValueIds) {
    final aNote = a['note'] ?? '';
    final aOptions = List<String>.from(a['optionValueIds'] ?? []);
    return aNote == note && _listEq(aOptions, optionValueIds);
  }

  bool _listEq(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}