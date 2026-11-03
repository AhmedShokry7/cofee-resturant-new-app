import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/services/shared_pref.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/cart/data/model/cart_line.dart';
import 'package:new_coffee/features/cart/data/repositories/cart_repository.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/menu/data/repositories/batch_product_repository.dart';
import 'package:new_coffee/features/menu/data/repositories/product_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthChangeEvent, AuthState;

part 'cart_state.dart';
part 'cart_line_mapper.dart';

/// Owns the customer-facing cart.
///
/// The device copy is namespaced per account ([storageKeyFor]), so two
/// customers sharing one device never see each other's lines: switching
/// accounts reloads that account's own cart. A guest cart is adopted into the
/// account once, on the first load after sign-in, then cleared.
///
/// For a signed-in customer the server owns the cart. Every change is written
/// to the customer's per-branch server cart and every load reads it back, so
/// the same account sees the same cart on every device. The device copy stays
/// as an offline fallback and as the place where a bundle wrapper lives; it is
/// never presented as confirmed server data while the server cannot be
/// reached, and a change the server has not accepted yet is pushed again
/// instead of being dropped.
class CartCubit extends Cubit<CartState> {
  CartCubit({
    required this._cartRepository,
    required this._catalogRepository,
    this.branchId,
    String? Function()? userIdProvider,
  }) : _userIdProvider = userIdProvider ?? _defaultUserId,
       super(const CartState(items: [], isLoading: true)) {
    _identity = _userIdProvider();
    if (SupabaseService.isReady) {
      _authSubscription = SupabaseService.client.auth.onAuthStateChange.listen(
        _onAuthStateChanged,
      );
    }
    load();
  }

  final CartRepository _cartRepository;
  final CatalogRepository _catalogRepository;
  final String? Function() _userIdProvider;

  /// Branch whose catalogue rows apply to restored lines.
  String? branchId;

  StreamSubscription<AuthState>? _authSubscription;

  /// Device key for one account's cart. `null` is the signed-out guest cart.
  /// Never share a key across accounts: that leaks one customer's lines
  /// into another's.
  static String storageKeyFor(String? userId) => 'cart_v1_${userId ?? 'guest'}';

  static String? _defaultUserId() => SupabaseService.isReady
      ? SupabaseService.client.auth.currentUser?.id
      : null;

  /// Which storage slot the restored lines come from.
  String? get _userId => _userIdProvider();
  String get _key => storageKeyFor(_userId);

  /// Key of the flag that records "the device cart still has to reach the
  /// server". It lives next to the cart itself so the two always describe the
  /// same account.
  String get _pendingKey => '${_key}_pending';

  /// Identity whose lines are currently in state. Null means guest.
  ///
  /// Seeded from the same source the storage key uses, so the very first load
  /// is not mistaken for a transition: the constructor state is an empty cart,
  /// which is exactly what a guest identity looks like.
  String? _identity;

  /// Monotonic id of the newest load. Only the load holding the latest number
  /// may write state.
  ///
  /// Needed because an identity transition emits immediately, while a load that
  /// started under the previous identity is still in flight and would otherwise
  /// land afterwards and restore the previous customer's lines.
  int _loadGeneration = 0;

  /// Records that the signed-in customer changed and drops whatever the
  /// previous one had on screen.
  ///
  /// Emits immediately rather than waiting for the next load, so the previous
  /// customer's lines are never visible during the transition or after a failed
  /// read. Only in-memory state is dropped: the per-account storage slots are
  /// untouched, so switching back restores that customer's own cart.
  ///
  /// Returns true when this really was a different identity. An ordinary
  /// refresh, a branch change or a token rotation leaves the data alone.
  @visibleForTesting
  bool applyIdentityTransition(String? identity) {
    if (identity == _identity) return false;
    _identity = identity;
    // Invalidate anything already in flight under the previous identity.
    _loadGeneration++;
    // A queued write describes the previous identity's cart. Letting it run
    // would write that cart into the account that just signed in.
    _syncTimer?.cancel();
    _syncTimer = null;
    if (state.items.isNotEmpty) {
      // The new account's lines are not known yet, so this is a load in
      // progress and not an empty cart.
      emit(const CartState(items: [], isLoading: true));
    }
    return true;
  }

  /// The cart is namespaced per account, so it reloads exactly when the
  /// account behind [_userId] changes.
  ///
  /// `signedIn` may be a different customer entirely, whose lines live under a
  /// different key, and `signedOut` must leave nothing of the signed-in cart on
  /// screen. `passwordRecovery` is grouped with `signedIn` on purpose: GoTrue
  /// emits it *instead of* `signedIn` when a recovery link establishes the
  /// session, and this app supports exactly that flow, so skipping it would
  /// leave the previous customer's lines on screen. `initialSession` is ignored
  /// on purpose: the auth stream replays its latest event to every new
  /// listener, and the constructor load above already read that session, so
  /// honouring it here would load twice. The guest adoption below is a write and
  /// is guarded separately by [_adoptingGuestCart], so no two loads can ever
  /// claim the same guest lines. `tokenRefreshed` rotates a token and leaves the
  /// account, therefore the cart, untouched; `userUpdated` changes a profile,
  /// not the cart.
  @visibleForTesting
  bool shouldReloadOnAuthEvent(AuthState auth) =>
      auth.event == AuthChangeEvent.signedIn ||
      auth.event == AuthChangeEvent.passwordRecovery ||
      auth.event == AuthChangeEvent.signedOut;

  void _onAuthStateChanged(AuthState auth) {
    if (!shouldReloadOnAuthEvent(auth)) return;
    applyIdentityTransition(auth.session?.user.id);
    load();
  }

  /// Lines one cart can hold, from the shared [CartLimits] contract.
  static const _maxItems = CartLimits.maxLines;

  /// Guards guest adoption: concurrent loads must not adopt the same guest
  /// lines twice (quantities would double), and a retry must not replay them.
  bool _adoptingGuestCart = false;

  /// While guest lines are being merged, account persistence is deferred so an
  /// interrupted adoption cannot leave a partially written account cart.
  bool _suppressPersist = false;

  /// While guest lines are being merged, the server write is deferred too, so
  /// the merge reaches the server as one cart instead of one write per line.
  bool _suppressServerSync = false;

  /// Rapid cart edits are coalesced into a single server write.
  ///
  /// A customer stepping through quantities would otherwise spend the server's
  /// write budget on taps instead of on real changes.
  static const _syncDebounce = Duration(milliseconds: 700);

  Timer? _syncTimer;

  /// Tail of the queue that serialises server writes.
  Future<void> _writeChain = Future<void>.value();

  /// The newest load, so a caller can wait for it.
  Future<void>? _pendingLoad;

  Future<void> load() {
    final future = _load(readServer: true);
    _pendingLoad = future;
    return future;
  }

  /// Completes when the newest load has finished.
  ///
  /// The constructor starts a load without awaiting it, so a caller that has
  /// to observe the result — a test, or a screen that opens right after the
  /// app started — needs a handle on it.
  @visibleForTesting
  Future<void> get settled => _pendingLoad ?? Future<void>.value();

  /// Writes the cart to the server right now instead of waiting for the
  /// debounce window to close.
  Future<void> flushServerSync() => _syncToServer();

  /// Restores the cart.
  ///
  /// For a signed-in customer with a branch the server owns the result: the
  /// server cart replaces the device copy. A change the server has not
  /// accepted yet is pushed first, because the device is then the newer of the
  /// two and the server would otherwise answer with the older cart. When the
  /// server cannot be reached the device copy is kept and the failure is
  /// reported, so an old cache is never shown as confirmed server data.
  Future<void> _load({required bool readServer}) async {
    final generation = ++_loadGeneration;
    try {
      final raw = await SharedPref.getValue(key: _key);
      if (isClosed) return;
      Map<String, ProductModel>? productsById;
      Future<Map<String, ProductModel>> catalog() async {
        final cached = productsById;
        if (cached != null) return cached;
        // Cart restoration knows its product IDs, so the resolver will fetch
        // exactly those IDs in one batch instead of downloading a 200-row
        // catalogue page and then issuing per-item fallbacks.
        productsById = <String, ProductModel>{};
        return productsById!;
      }

      // An empty storage slot is a real answer: this account's cart is empty.
      // Skipping the emit used to leave the previous account's lines on screen
      // because nothing replaced them. Resolving zero entries never touches the
      // catalogue, so an empty cart still costs no request.
      final cachedEntries = (raw == null || raw.isEmpty)
          ? const <Map<String, dynamic>>[]
          : decodeCartEntries(raw);

      Object? serverError;
      List<CartLine>? serverLines;
      // The lines above were read from the previous identity's slot; a
      // transition that happened meanwhile must not let them be written into
      // the new account's cart.
      if (generation != _loadGeneration) return;
      if (readServer && _canSyncToServer) {
        // A change the server has not accepted yet is newer than anything the
        // server can answer with, so it goes first. Let any queued write
        // finish first so the two never reach the server out of order.
        if (await _hasPendingSync()) {
          _syncTimer?.cancel();
          _syncTimer = null;
          await _writeChain;
          if (isClosed || generation != _loadGeneration) return;
          try {
            await _saveLines(serverLinesForEntries(cachedEntries));
            await _setPendingSync(false);
          } catch (error) {
            serverError = error;
          }
        }
        if (serverError == null) {
          try {
            serverLines = await _cartRepository.fetchLines(branchId: branchId);
          } catch (error) {
            serverError = error;
          }
        }
      }
      if (isClosed) return;
      // A newer load, or a newer identity, already owns the state.
      if (generation != _loadGeneration) return;

      final entries = serverLines == null
          ? cachedEntries
          : mergeServerLines(serverLines, cachedEntries);
      final items = await _resolveItems(entries, catalog);
      if (isClosed) return;
      if (generation != _loadGeneration) return;
      // Emitted whatever the result is: an empty cart is an answer, and the
      // load flag has to clear for it too, or the page would spin on a skeleton
      // for a customer who genuinely has nothing in the cart.
      emit(
        CartState(
          items: items,
          error: serverError == null ? null : S.cartSyncFailed,
          isLoading: false,
        ),
      );
      if (serverError != null) addError(serverError);

      // One-time adoption: a guest cart becomes the account's cart on the
      // first load after sign-in, then the guest slot is cleared so a later
      // sign-out starts empty instead of replaying old lines. The slot is
      // claimed before processing so overlapping loads cannot adopt twice
      // (quantities would double), and a retry never replays adopted lines.
      if (_userId != null && !_adoptingGuestCart) {
        _adoptingGuestCart = true;
        _suppressPersist = true;
        _suppressServerSync = true;
        String? guestRaw;
        List<Map<String, dynamic>> guestEntries = const [];
        final preAdoptionItems = List<CartItem>.from(state.items);
        try {
          guestRaw = await SharedPref.getValue(key: storageKeyFor(null));
          guestEntries = guestRaw == null || guestRaw.isEmpty
              ? const <Map<String, dynamic>>[]
              : decodeCartEntries(guestRaw);
          if (guestEntries.isNotEmpty) {
            // Claim the guest slot first so concurrent/retried loads cannot
            // adopt the same lines twice.
            await SharedPref.setValue(
              key: storageKeyFor(null),
              value: jsonEncode([]),
            );

            bool aborted = false;
            for (final entry in guestEntries) {
              if (isClosed ||
                  generation != _loadGeneration ||
                  _identity != _userId) {
                aborted = true;
                break;
              }

              if (entry['isBundle'] == true) {
                final bundleId =
                    entry['bundleId']?.toString() ??
                    entry['productId']?.toString() ??
                    '';
                if (bundleId.isEmpty) continue;
                final components = <CartBundleComponent>[];
                final rawComponents = entry['bundleComponents'];
                if (rawComponents is List) {
                  for (final raw in rawComponents) {
                    if (raw is Map) {
                      components.add(
                        CartBundleComponent.fromJson(
                          Map<String, dynamic>.from(raw),
                        ),
                      );
                    }
                  }
                }
                if (isClosed ||
                    generation != _loadGeneration ||
                    _identity != _userId) {
                  aborted = true;
                  break;
                }
                final guestImage =
                    entry['bundleImage']?.toString().trim() ?? '';
                addBundle(
                  bundleId: bundleId,
                  title: entry['bundleTitle']?.toString() ?? S.bundleLabel,
                  image: guestImage.isEmpty
                      ? await _bundleFallbackImage(components, catalog)
                      : guestImage,
                  price:
                      (entry['bundlePrice'] as num?)?.toDouble() ??
                      (entry['unitPrice'] as num?)?.toDouble() ??
                      0,
                  components: components,
                  quantity: entry['quantity'] as int? ?? 1,
                  note: entry['note'] as String? ?? '',
                  optionValueIds:
                      (entry['optionValueIds'] as List?)
                          ?.map((e) => e.toString())
                          .toList() ??
                      const <String>[],
                );
                continue;
              }

              final guestProductId = entry['productId']?.toString() ?? '';
              if (guestProductId.isEmpty) continue;
              final product =
                  (await catalog())[guestProductId] ??
                  await _catalogRepository.getById(
                    guestProductId,
                    branchId: branchId,
                  );
              if (isClosed ||
                  generation != _loadGeneration ||
                  _identity != _userId) {
                aborted = true;
                break;
              }
              if (product == null) continue;
              add(
                product,
                quantity: entry['quantity'] as int? ?? 1,
                note: entry['note'] as String? ?? '',
                optionValueIds:
                    (entry['optionValueIds'] as List?)
                        ?.map((e) => e.toString())
                        .toList() ??
                    const <String>[],
                unitPrice: (entry['unitPrice'] as num?)?.toDouble(),
                bundleId: entry['bundleId']?.toString(),
              );
            }

            if (aborted ||
                isClosed ||
                generation != _loadGeneration ||
                _identity != _userId) {
              aborted = true;
            }

            if (aborted) {
              // Restore the claimed guest slot. The account slot was not
              // persisted during adoption because persistence was suppressed.
              await SharedPref.setValue(
                key: storageKeyFor(null),
                value: guestRaw ?? jsonEncode(guestEntries),
              );
              if (!isClosed &&
                  generation == _loadGeneration &&
                  _identity == _userId) {
                emit(CartState(items: preAdoptionItems));
              }
            } else {
              // One authoritative write after all lines have merged.
              _suppressPersist = false;
              await _persist();
              // The merged cart has to reach the server as well.
              await _setPendingSync(true);
            }
          }
        } catch (error, stackTrace) {
          // Restore the guest slot; do not overwrite the account slot because
          // adoption never persisted it.
          bool restored = false;
          try {
            await SharedPref.setValue(
              key: storageKeyFor(null),
              value: guestRaw ?? jsonEncode(guestEntries),
            );
            restored = true;
          } catch (restoreError, restoreStackTrace) {
            if (!isClosed) {
              addError(restoreError, restoreStackTrace);
            }
          }
          if (!restored) {
            // Report that recovery itself failed.
            if (!isClosed) {
              addError(StateError('Guest cart restoration failed'), stackTrace);
            }
          }
          if (!isClosed &&
              generation == _loadGeneration &&
              _identity == _userId) {
            // The customer reads a sentence about the cart, never the
            // exception; the cause still goes to addError below.
            emit(CartState(items: preAdoptionItems, error: S.cartSyncFailed));
          }
          if (!isClosed) {
            addError(error, stackTrace);
          }
        } finally {
          _suppressPersist = false;
          _suppressServerSync = false;
          _adoptingGuestCart = false;
        }
        if (!isClosed &&
            generation == _loadGeneration &&
            _identity == _userId) {
          _scheduleServerSync();
        }
      }
    } catch (error, stackTrace) {
      // Best-effort: start with an empty cart rather than crash, but keep
      // the failure visible so a sync problem is recoverable.
      if (!isClosed) {
        emit(CartState(items: state.items, error: S.couldNotLoadCart));
        addError(error, stackTrace);
      }
    }
  }

  /// Whether the cart can be written to and read from the server right now.
  bool get _canSyncToServer =>
      _userId != null && (branchId?.trim() ?? '').isNotEmpty;

  /// Points the cart at another branch.
  ///
  /// The cart belongs to the customer, not to the branch: the lines stay, only
  /// the prices and the availability follow the new branch. The very first
  /// branch is different — there the server holds the cart for that branch,
  /// so it is read back. A later switch mirrors the cart into the new
  /// branch's server cart instead, which is what keeps both branches in step
  /// with what the customer sees.
  Future<void> setBranch(String? branchId) async {
    if (branchId == this.branchId) return Future.value();
    final previous = this.branchId;
    this.branchId = branchId;
    final firstBranch = previous == null || previous.trim().isEmpty;
    if (firstBranch) {
      await load();
      return;
    }
    await _load(readServer: false);
    await _syncToServer();
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
          sameOptionIds(item.optionValueIds, optionIds),
    );
    if (index == -1 && items.length >= _maxItems) {
      // The device slot and the restored list both stop at this many lines, so
      // a line added past the cap would sit on screen and disappear on the next
      // restart. The customer is told the line was not taken.
      emit(
        CartState(items: state.items, error: S.cartLineLimitReached(_maxItems)),
      );
      return;
    }
    if (index == -1) {
      items.add(
        CartItem(
          product: product,
          quantity: quantity.clamp(1, CartLimits.maxQuantity),
          note: note,
          optionValueIds: optionIds,
          unitPrice: unitPrice,
          bundleId: bundleId,
        ),
      );
    } else {
      items[index] = items[index].copyWith(
        quantity: (items[index].quantity + quantity).clamp(
          1,
          CartLimits.maxQuantity,
        ),
        // A re-add updates the price (and bundle membership) on both sides,
        // matching the server's ON CONFLICT update.
        unitPrice: unitPrice,
        bundleId: bundleId,
      );
    }
    emit(CartState(items: items));
    _onCartChanged();
  }

  /// Adds an entire bundle as a single cart line.
  ///
  /// The bundle keeps its own identity, name, image and price; its components
  /// are retained for checkout expansion but never become separate cart lines.
  void addBundle({
    required String bundleId,
    required String title,
    required String image,
    required double price,
    required List<CartBundleComponent> components,
    int quantity = 1,
    String note = '',
    List<String> optionValueIds = const [],
  }) {
    final items = [...state.items];
    final optionIds = [
      for (final id in optionValueIds)
        if (id.trim().isNotEmpty) id,
    ]..sort();
    final product = ProductModel(
      id: 'bundle:$bundleId',
      name: title,
      price: price,
      image: image,
    );
    final index = items.indexWhere(
      (item) =>
          item.isBundle &&
          item.bundleId == bundleId &&
          item.note == note &&
          sameOptionIds(item.optionValueIds, optionIds),
    );
    if (index == -1 && items.length >= _maxItems) {
      emit(
        CartState(items: state.items, error: S.cartLineLimitReached(_maxItems)),
      );
      return;
    }
    if (index == -1) {
      items.add(
        CartItem(
          product: product,
          quantity: quantity.clamp(1, CartLimits.maxQuantity),
          note: note,
          optionValueIds: optionIds,
          unitPrice: price,
          bundleId: bundleId,
          bundleComponents: components,
        ),
      );
    } else {
      items[index] = items[index].copyWith(
        quantity: (items[index].quantity + quantity).clamp(
          1,
          CartLimits.maxQuantity,
        ),
        unitPrice: price,
        bundleComponents: components,
      );
    }
    emit(CartState(items: items));
    _onCartChanged();
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
    _onCartChanged();
  }

  void incrementLine(String lineId) => _changeQuantity(lineId, 1);

  void decrementLine(String lineId) => _changeQuantity(lineId, -1);

  void removeLine(String lineId) {
    emit(
      CartState(
        items: state.items.where((item) => item.lineId != lineId).toList(),
      ),
    );
    _onCartChanged();
  }

  void clear() {
    emit(const CartState(items: []));
    _onCartChanged();
  }

  @override
  Future<void> close() {
    _authSubscription?.cancel();
    _authSubscription = null;
    _syncTimer?.cancel();
    _syncTimer = null;
    return super.close();
  }

  /// A cart change: keep the device copy and send the cart to the server.
  ///
  /// The device copy is written first so a change survives an app that is
  /// killed before the server answered, and the "pending" flag records that
  /// the server still has to catch up.
  void _onCartChanged() {
    _persist();
    if (_suppressServerSync) return;
    _setPendingSync(true);
    _scheduleServerSync();
  }

  void _scheduleServerSync() {
    if (_suppressServerSync) return;
    if (!_canSyncToServer) return;
    final identity = _userId;
    _syncTimer?.cancel();
    _syncTimer = Timer(_syncDebounce, () {
      // The account may have changed while the window was open.
      if (_userId != identity) return;
      unawaited(_syncToServer());
    });
  }

  /// Writes the current cart to the server.
  ///
  /// A failure is reported, never swallowed: the customer keeps the lines on
  /// the device, the pending flag stays set so the next attempt pushes them
  /// again, and the error reaches the screen.
  ///
  /// Writes are queued: two changes can never reach the server out of order,
  /// which would let an older cart overwrite a newer one.
  Future<void> _syncToServer() {
    final identity = _userId;
    final next = _writeChain.then((_) => _writeNow(identity));
    _writeChain = next;
    return next;
  }

  Future<void> _writeNow(String? identity) async {
    _syncTimer?.cancel();
    _syncTimer = null;
    if (isClosed) return;
    if (_userId != identity) return;
    if (!_canSyncToServer) return;
    final lines = serverLinesForItems(state.items);
    try {
      await _saveLines(lines);
      if (isClosed || _userId != identity) return;
      await _setPendingSync(false);
      if (!isClosed && state.error != null) {
        emit(CartState(items: state.items));
      }
    } catch (error, stackTrace) {
      if (_userId != identity) return;
      await _setPendingSync(true);
      if (!isClosed) {
        emit(CartState(items: state.items, error: S.cartSyncFailed));
        addError(error, stackTrace);
      }
    }
  }

  Future<void> _saveLines(List<CartLine> lines) =>
      _cartRepository.saveLines(branchId: branchId, lines: lines);

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
    final quantity = (items[index].quantity + delta).clamp(
      0,
      CartLimits.maxQuantity,
    );
    if (quantity <= 0) {
      items.removeAt(index);
    } else {
      items[index] = items[index].copyWith(quantity: quantity);
    }
    emit(CartState(items: items));
    _onCartChanged();
  }

  Future<List<CartItem>> _resolveItems(
    List<Map<String, dynamic>> entries,
    Future<Map<String, ProductModel>> Function() catalog,
  ) async {
    if (entries.isEmpty) return const [];
    final productsById = await catalog();
    final requestedIds = <String>{};
    for (final entry in entries) {
      if (entry['isBundle'] == true) {
        final rawComponents = entry['bundleComponents'];
        if (rawComponents is List) {
          for (final raw in rawComponents) {
            if (raw is Map) {
              final id = raw['productId']?.toString() ?? '';
              if (id.isNotEmpty) requestedIds.add(id);
            }
          }
        }
      } else {
        final id = entry['productId']?.toString() ?? '';
        if (id.isNotEmpty) requestedIds.add(id);
      }
    }
    final missingIds = requestedIds
        .where((id) => !productsById.containsKey(id))
        .toList(growable: false);
    if (missingIds.isNotEmpty) {
      try {
        final missingProducts = await getProductsByIds(
          _catalogRepository,
          missingIds,
          branchId: branchId,
        );
        productsById.addAll({
          for (final product in missingProducts) product.id: product,
        });
      } catch (error, stackTrace) {
        addError(error, stackTrace);
      }
    }

    final items = <CartItem>[];
    for (final entry in entries) {
      if (entry['isBundle'] == true) {
        final bundleId =
            entry['bundleId']?.toString() ??
            entry['productId']?.toString() ??
            '';
        if (bundleId.isEmpty) continue;
        final title = entry['bundleTitle']?.toString() ?? S.bundleLabel;
        final price =
            (entry['bundlePrice'] as num?)?.toDouble() ??
            (entry['unitPrice'] as num?)?.toDouble() ??
            0.0;
        final quantity =
            (entry['quantity'] as num?)?.toInt().clamp(
              1,
              CartLimits.maxQuantity,
            ) ??
            1;
        final components = <CartBundleComponent>[];
        final rawComponents = entry['bundleComponents'];
        if (rawComponents is List) {
          for (final raw in rawComponents) {
            if (raw is Map) {
              components.add(
                CartBundleComponent.fromJson(Map<String, dynamic>.from(raw)),
              );
            }
          }
        }
        var image = entry['bundleImage']?.toString().trim() ?? '';
        if (image.isEmpty) {
          image = await _bundleFallbackImage(components, catalog);
        }
        final product = ProductModel(
          id: 'bundle:$bundleId',
          name: title,
          price: price,
          image: image,
        );
        items.add(
          CartItem(
            product: product,
            quantity: quantity,
            note: entry['note']?.toString() ?? '',
            optionValueIds: _optionIds(entry['optionValueIds']),
            unitPrice: price,
            bundleId: bundleId,
            bundleComponents: components,
          ),
        );
        if (items.length >= _maxItems) break;
        continue;
      }
      final productId = entry['productId']?.toString();
      if (productId == null || productId.isEmpty) continue;
      final product = productsById[productId];
      // Preserve unavailable lines on a branch switch instead of silently
      // dropping them; the customer can review before checkout.
      final resolvedProduct =
          product ??
          (branchId == null || branchId!.trim().isEmpty
              ? null
              : ProductModel(
                  id: productId,
                  name: S.productUnavailable,
                  price: (entry['unitPrice'] as num?)?.toDouble() ?? 0,
                  image: '',
                ));
      if (resolvedProduct == null) continue;
      final productToUse = resolvedProduct;

      final quantity =
          (entry['quantity'] as num?)?.toInt().clamp(
            1,
            CartLimits.maxQuantity,
          ) ??
          1;
      items.add(
        CartItem(
          product: productToUse,
          quantity: quantity,
          note: entry['note']?.toString() ?? '',
          optionValueIds: _optionIds(entry['optionValueIds']),
          unitPrice: (entry['unitPrice'] as num?)?.toDouble(),
          bundleId: entry['bundleId']?.toString(),
        ),
      );
      if (items.length >= _maxItems) break;
    }
    return items;
  }

  /// Picture for a bundle line whose own `image_url` column is empty.
  ///
  /// `catalog.bundles.image_url` is nullable and usually unset, and every
  /// bundle screen outside the cart already borrows the first component's
  /// picture. Reusing the same rule here means a restored cart line shows the
  /// same picture the customer just saw, instead of the "no image" tile.
  Future<String> _bundleFallbackImage(
    List<CartBundleComponent> components,
    Future<Map<String, ProductModel>> Function() catalog,
  ) async {
    final productsById = await catalog();
    final missingIds = components
        .map((component) => component.productId)
        .where((id) => !productsById.containsKey(id))
        .toSet()
        .toList(growable: false);
    if (missingIds.isNotEmpty) {
      final missingProducts = await getProductsByIds(
        _catalogRepository,
        missingIds,
        branchId: branchId,
      );
      productsById.addAll({
        for (final product in missingProducts) product.id: product,
      });
    }
    for (final component in components) {
      final product = productsById[component.productId];
      final image = product?.displayImageUrl;
      if (image != null && image.trim().isNotEmpty) return image.trim();
    }
    return '';
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
    if (_suppressPersist) return;
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
                  if (item.bundleId != null && item.bundleId!.isNotEmpty)
                    'bundleId': item.bundleId,
                  if (item.isBundle) 'isBundle': true,
                  if (item.isBundle) 'bundleTitle': item.product.name,
                  if (item.isBundle) 'bundleImage': item.product.image,
                  if (item.isBundle) 'bundlePrice': item.product.price,
                  if (item.isBundle)
                    'bundleComponents': item.bundleComponents
                        .map((component) => component.toJson())
                        .toList(),
                },
              )
              .toList(),
        ),
      );
    } catch (_) {
      // Best-effort: never break the cart if storage fails.
    }
  }

  /// Records that the server still has to accept the device cart.
  Future<void> _setPendingSync(bool pending) async {
    if (_userId == null) return;
    try {
      await SharedPref.setValue(key: _pendingKey, value: pending ? '1' : '');
    } catch (_) {
      // Best-effort: a missing flag only means one more attempt later.
    }
  }

  Future<bool> _hasPendingSync() async {
    if (_userId == null) return false;
    final raw = await SharedPref.getValue(key: _pendingKey);
    return raw != null && raw.isNotEmpty && raw != '0';
  }
}
