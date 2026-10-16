import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/services/shared_pref.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/cart/data/repositories/cart_repository.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/menu/data/repositories/product_repository.dart';

part 'cart_state.dart';

/// Owns the customer-facing cart.
///
/// The device cart is namespaced per account ([storageKeyFor]), so two
/// customers sharing one device never see each other's lines: switching
/// accounts reloads that account's own cart. A guest cart is adopted into the
/// account once, on the first load after sign-in, then cleared.
///
/// The server intentionally rejects client-supplied prices, and bundle
/// discounts have no server-side line representation yet, so the device cart
/// stays the checkout source of truth. Writes are mirrored best-effort into
/// the customer's per-branch server cart and must never block the UI.
class CartCubit extends Cubit<CartState> {
  CartCubit({
    required CartRepository cartRepository,
    required CatalogRepository catalogRepository,
    this.branchId,
    String? Function()? userIdProvider,
  }) : _cartRepository = cartRepository,
       _catalogRepository = catalogRepository,
       _userIdProvider = userIdProvider ?? _defaultUserId,
       super(const CartState(items: [])) {
    if (SupabaseService.isReady) {
      _authSubscription = SupabaseService.client.auth.onAuthStateChange.listen(
        (_) => load(),
      );
    }
    load();
  }

  final CartRepository _cartRepository;
  final CatalogRepository _catalogRepository;
  final String? Function() _userIdProvider;

  /// Branch whose catalogue rows apply to restored lines.
  String? branchId;

  StreamSubscription<dynamic>? _authSubscription;

  /// Device key for one account's cart. `null` is the signed-out guest cart.
  /// Never share a key across accounts: that leaks one customer's lines
  /// into another's.
  static String storageKeyFor(String? userId) => 'cart_v1_${userId ?? 'guest'}';

  static String? _defaultUserId() => SupabaseService.isReady
      ? SupabaseService.client.auth.currentUser?.id
      : null;

  String? get _userId => _userIdProvider();
  String get _key => storageKeyFor(_userId);

  /// Restored rows stay within the catalogue's configured page width.
  static const _catalogPageSize = 200;
  static const _maxItems = 50;

  /// Guards guest adoption: concurrent loads must not adopt the same guest
  /// lines twice (quantities would double), and a retry must not replay them.
  bool _adoptingGuestCart = false;

  Future<void> load() async {
    try {
      final raw = await SharedPref.getValue(key: _key);
      if (isClosed) return;
      Map<String, ProductModel>? productsById;
      Future<Map<String, ProductModel>> catalog() async {
        final cached = productsById;
        if (cached != null) return cached;
        final fresh = await _catalogRepository
            .getProducts(branchId: branchId, limit: _catalogPageSize)
            .then((products) => {for (final p in products) p.id: p});
        productsById = fresh;
        return fresh;
      }

      if (raw != null && raw.isNotEmpty) {
        final items = await _resolveItems(_decodeEntries(raw), catalog);
        if (isClosed) return;
        emit(CartState(items: items));
      }

      // One-time adoption: a guest cart becomes the account's cart on the
      // first load after sign-in, then the guest slot is cleared so a later
      // sign-out starts empty instead of replaying old lines. The slot is
      // claimed before processing so overlapping loads cannot adopt twice
      // (quantities would double), and a retry never replays adopted lines.
      if (_userId != null && !_adoptingGuestCart) {
        _adoptingGuestCart = true;
        try {
          final guestRaw = await SharedPref.getValue(key: storageKeyFor(null));
          final guestEntries = guestRaw == null || guestRaw.isEmpty
              ? const <Map<String, dynamic>>[]
              : _decodeEntries(guestRaw);
          if (guestEntries.isNotEmpty) {
            await SharedPref.setValue(
              key: storageKeyFor(null),
              value: jsonEncode([]),
            );
            if (isClosed) return;
            for (final entry in guestEntries) {
              final guestProductId = entry['productId']?.toString() ?? '';
              if (guestProductId.isEmpty) continue;
              final product =
                  (await catalog())[guestProductId] ??
                  await _catalogRepository.getById(
                    guestProductId,
                    branchId: branchId,
                  );
              if (product == null || isClosed) continue;
              add(
                product,
                quantity: entry['quantity'] as int? ?? 1,
                note: entry['note'] as String? ?? '',
                optionValueIds:
                    (entry['optionValueIds'] as List?)
                        ?.map((e) => e.toString())
                        .toList() ??
                    const [],
                unitPrice: (entry['unitPrice'] as num?)?.toDouble(),
              );
            }
          }
        } finally {
          _adoptingGuestCart = false;
        }
      }
    } catch (_) {
      // Best-effort: start with an empty cart rather than crash.
    }
  }

  Future<void> setBranch(String? branchId) {
    if (branchId == this.branchId) return Future.value();
    this.branchId = branchId;
    return load();
  }

  void add(
    ProductModel product, {
    int quantity = 1,
    String note = '',
    List<String> optionValueIds = const [],
    double? unitPrice,
    String? bundleId,
  }) {
    final items = [...state.items];
    final optionIds = [
      for (final id in optionValueIds)
        if (id.trim().isNotEmpty) id,
    ]..sort();
    final index = items.indexWhere(
      (item) =>
          item.product.id == product.id &&
          item.note == note &&
          _sameOptions(item.optionValueIds, optionIds),
    );
    if (index == -1) {
      items.add(
        CartItem(
          product: product,
          quantity: quantity.clamp(1, 99),
          note: note,
          optionValueIds: optionIds,
          unitPrice: unitPrice,
        ),
      );
    } else {
      items[index] = items[index].copyWith(
        quantity: (items[index].quantity + quantity).clamp(1, 99),
      );
    }
    emit(CartState(items: items));
    _persist();

    // Mirror best-effort into the per-branch server cart. Never blocks UI;
    // failures are reported, never silent and never fatal.
    _mirror(
      _cartRepository.addItem(
        productId: product.id,
        quantity: quantity,
        note: note,
        optionValueIds: optionValueIds,
        unitPrice: unitPrice ?? product.price,
        bundleId: bundleId,
        branchId: branchId,
      ),
    );
  }

  /// Kept for callers that only know a product. The cart page and stepper now
  /// use the line-specific variants below, so different notes/options for the
  /// same product are no longer conflated.
  void increment(String productId) => _changeQuantityForProduct(productId, 1);

  void decrement(String productId) => _changeQuantityForProduct(productId, -1);

  void remove(String productId) {
    emit(
      CartState(
        items: state.items
            .where((item) => item.product.id != productId)
            .toList(),
      ),
    );
    _persist();
  }

  void incrementLine(String lineId) => _changeQuantity(lineId, 1);

  void decrementLine(String lineId) => _changeQuantity(lineId, -1);

  void removeLine(String lineId) {
    emit(
      CartState(
        items: state.items.where((item) => item.lineId != lineId).toList(),
      ),
    );
    _persist();
  }

  void clear() {
    emit(const CartState(items: []));
    _persist();
    _mirror(_cartRepository.clearCart(branchId: branchId));
  }

  @override
  Future<void> close() {
    _authSubscription?.cancel();
    _authSubscription = null;
    return super.close();
  }

  void _mirror(Future<void> work) {
    work.then(
      (_) {},
      onError: (Object error, StackTrace stack) {
        if (!isClosed) addError(error, stack);
      },
    );
  }

  void _changeQuantityForProduct(String productId, int delta) {
    final items = [...state.items];
    final index = items.indexWhere((item) => item.product.id == productId);
    _applyQuantity(items, index, delta);
  }

  void _changeQuantity(String lineId, int delta) {
    final items = [...state.items];
    final index = items.indexWhere((item) => item.lineId == lineId);
    _applyQuantity(items, index, delta);
  }

  void _applyQuantity(List<CartItem> items, int index, int delta) {
    if (index == -1) return;
    final quantity = (items[index].quantity + delta).clamp(0, 99);
    if (quantity <= 0) {
      items.removeAt(index);
    } else {
      items[index] = items[index].copyWith(quantity: quantity);
    }
    emit(CartState(items: items));
    _persist();
  }

  static bool _sameOptions(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static List<Map<String, dynamic>> _decodeEntries(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return [
      for (final entry in decoded)
        if (entry is Map) Map<String, dynamic>.from(entry),
    ];
  }

  Future<List<CartItem>> _resolveItems(
    List<Map<String, dynamic>> entries,
    Future<Map<String, ProductModel>> Function() catalog,
  ) async {
    final items = <CartItem>[];
    for (final entry in entries) {
      final productId = entry['productId']?.toString();
      if (productId == null || productId.isEmpty) continue;
      final product =
          (await catalog())[productId] ??
          await _catalogRepository.getById(productId, branchId: branchId);
      if (product == null) continue;

      final quantity = (entry['quantity'] as num?)?.toInt().clamp(1, 99) ?? 1;
      items.add(
        CartItem(
          product: product,
          quantity: quantity,
          note: entry['note']?.toString() ?? '',
          optionValueIds: _optionIds(entry['optionValueIds']),
          unitPrice: (entry['unitPrice'] as num?)?.toDouble(),
        ),
      );
      if (items.length >= _maxItems) break;
    }
    return items;
  }

  static List<String> _optionIds(dynamic raw) {
    if (raw is List) {
      final ids = <String>[
        for (final value in raw)
          if (value?.toString().trim().isNotEmpty ?? false) value.toString(),
      ]..sort();
      return ids;
    }
    return const [];
  }

  Future<void> _persist() async {
    try {
      await SharedPref.setValue(
        key: _key,
        value: jsonEncode(
          state.items
              .take(_maxItems)
              .map(
                (item) => {
                  'productId': item.product.id,
                  'quantity': item.quantity,
                  if (item.note.isNotEmpty) 'note': item.note,
                  if (item.optionValueIds.isNotEmpty)
                    'optionValueIds': item.optionValueIds,
                  if (item.unitPrice != null) 'unitPrice': item.unitPrice,
                },
              )
              .toList(),
        ),
      );
    } catch (_) {
      // Best-effort: never break the cart if storage fails.
    }
  }
}
