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
import 'package:new_coffee/features/menu/data/repositories/product_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthChangeEvent, AuthState;

part 'cart_state.dart';

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
    required CartRepository cartRepository,
    required CatalogRepository catalogRepository,
    this.branchId,
    String? Function()? userIdProvider,
  }) : _cartRepository = cartRepository,
       _catalogRepository = catalogRepository,
       _userIdProvider = userIdProvider ?? _defaultUserId,
       super(const CartState(items: [])) {
    _identity = _userIdProvider();
    if (SupabaseService.isReady) {
      _authSubscription = SupabaseService.client.auth.onAuthStateChange
          .listen(_onAuthStateChanged);
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
    if (state.items.isNotEmpty) {
      emit(const CartState(items: []));
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

  /// Restored rows stay within the catalogue's configured page width.
  static const _catalogPageSize = 200;
  static const _maxItems = 50;

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
  @visibleForTesting
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
        final fresh = await _catalogRepository
            .getProducts(branchId: branchId, limit: _catalogPageSize)
            .then((products) => {for (final p in products) p.id: p});
        productsById = fresh;
        return fresh;
      }

      // An empty storage slot is a real answer: this account's cart is empty.
      // Skipping the emit used to leave the previous account's lines on screen
      // because nothing replaced them. Resolving zero entries never touches the
      // catalogue, so an empty cart still costs no request.
      final cachedEntries = (raw == null || raw.isEmpty)
          ? const <Map<String, dynamic>>[]
          : _decodeEntries(raw);

      Object? serverError;
      List<CartLine>? serverLines;
      if (readServer && _canSyncToServer) {
        // A change the server has not accepted yet is newer than anything the
        // server can answer with, so it goes first.
        if (await _hasPendingSync()) {
          try {
            await _saveLines(_linesFromEntries(cachedEntries));
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
          : _mergeServerLines(serverLines, cachedEntries);
      final items = await _resolveItems(entries, catalog);
      if (isClosed) return;
      if (generation != _loadGeneration) return;
      if (items.isNotEmpty || state.items.isNotEmpty || serverError != null) {
        emit(
          CartState(
            items: items,
            error: serverError == null ? null : S.cartSyncFailed,
          ),
        );
        if (serverError != null) addError(serverError);
      }

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
              : _decodeEntries(guestRaw);
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
              addError(
                StateError('Guest cart restoration failed'),
                stackTrace,
              );
            }
          }
          if (!isClosed &&
              generation == _loadGeneration &&
              _identity == _userId) {
            emit(
              CartState(
                items: preAdoptionItems,
                error: error.toString(),
              ),
            );
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
        emit(CartState(items: state.items, error: error.toString()));
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
          bundleId: bundleId,
        ),
      );
    } else {
      items[index] = items[index].copyWith(
        quantity: (items[index].quantity + quantity).clamp(1, 99),
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
          _sameOptions(item.optionValueIds, optionIds),
    );
    if (index == -1) {
      items.add(
        CartItem(
          product: product,
          quantity: quantity.clamp(1, 99),
          note: note,
          optionValueIds: optionIds,
          unitPrice: price,
          bundleId: bundleId,
          bundleComponents: components,
        ),
      );
    } else {
      items[index] = items[index].copyWith(
        quantity: (items[index].quantity + quantity).clamp(1, 99),
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
    _syncTimer?.cancel();
    _syncTimer = Timer(_syncDebounce, () {
      unawaited(_syncToServer());
    });
  }

  /// Writes the current cart to the server.
  ///
  /// A failure is reported, never swallowed: the customer keeps the lines on
  /// the device, the pending flag stays set so the next attempt pushes them
  /// again, and the error reaches the screen.
  Future<void> _syncToServer() async {
    _syncTimer?.cancel();
    _syncTimer = null;
    if (isClosed) return;
    if (!_canSyncToServer) return;
    final lines = _linesFromState();
    try {
      await _saveLines(lines);
      await _setPendingSync(false);
      if (!isClosed && state.error != null) {
        emit(CartState(items: state.items));
      }
    } catch (error, stackTrace) {
      await _setPendingSync(true);
      if (!isClosed) {
        emit(CartState(items: state.items, error: S.cartSyncFailed));
        addError(error, stackTrace);
      }
    }
  }

  Future<void> _saveLines(List<CartLine> lines) =>
      _cartRepository.saveLines(branchId: branchId, lines: lines);

  /// The server lines for the cart the customer is looking at.
  ///
  /// A bundle is one line on the device but its component lines on the
  /// server, exactly like the checkout sends it, so the server keeps charging
  /// the bundle share.
  List<CartLine> _linesFromState() => [
        for (final item in state.items)
          if (item.isBundle)
            for (final component in item.bundleComponents)
              CartLine(
                productId: component.productId,
                quantity: component.quantity * item.quantity,
                note: item.note,
                optionValueIds: item.optionValueIds,
                bundleId: item.bundleId,
              )
          else
            CartLine(
              productId: item.product.id,
              quantity: item.quantity,
              note: item.note,
              optionValueIds: item.optionValueIds,
              bundleId: item.bundleId,
            ),
      ];

  /// The server lines for a stored cart.
  List<CartLine> _linesFromEntries(List<Map<String, dynamic>> entries) => [
        for (final entry in entries)
          if (entry['isBundle'] != true)
            CartLine(
              productId: entry['productId']?.toString() ?? '',
              quantity: (entry['quantity'] as num?)?.toInt() ?? 1,
              note: entry['note']?.toString() ?? '',
              optionValueIds: canonicalOptionIds(
                (entry['optionValueIds'] as List?)
                        ?.map((e) => e.toString()) ??
                    const <String>[],
              ),
            ),
      ];

  /// Combines the server cart with the device copy.
  ///
  /// The server owns the product lines. A bundle is a device-side wrapper
  /// around component lines, so it is re-attached to the component lines the
  /// server kept; a bundle the server does not know any more is dropped,
  /// because the server is the authority.
  List<Map<String, dynamic>> _mergeServerLines(
    List<CartLine> serverLines,
    List<Map<String, dynamic>> cachedEntries,
  ) {
    final remaining = List<CartLine>.of(serverLines);
    final merged = <Map<String, dynamic>>[];

    for (final entry in cachedEntries) {
      if (entry['isBundle'] != true) continue;
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
      if (components.isEmpty) continue;

      final note = entry['note']?.toString() ?? '';
      final optionIds = canonicalOptionIds(
        (entry['optionValueIds'] as List?)?.map((e) => e.toString()) ??
            const <String>[],
      );
      final matched = <CartLine>[];
      var complete = true;
      for (final component in components) {
        final index = remaining.indexWhere(
          (line) =>
              line.productId == component.productId &&
              line.note == note &&
              _sameOptions(line.optionValueIds, optionIds),
        );
        if (index == -1) {
          complete = false;
          break;
        }
        matched.add(remaining.removeAt(index));
      }
      if (!complete) {
        // The bundle is not on the server any more: put the lines that were
        // taken back and let the server decide.
        remaining.insertAll(0, matched);
        continue;
      }

      var quantity = 1 << 30;
      for (var i = 0; i < matched.length; i++) {
        final perBundle = components[i].quantity;
        final held = perBundle <= 0
            ? matched[i].quantity
            : matched[i].quantity ~/ perBundle;
        if (held < quantity) quantity = held;
      }
      merged.add({
        ...entry,
        'quantity': quantity.clamp(1, 99),
      });
    }

    for (final line in remaining) {
      merged.add({
        'productId': line.productId,
        'quantity': line.quantity,
        if (line.note.isNotEmpty) 'note': line.note,
        if (line.optionValueIds.isNotEmpty)
          'optionValueIds': line.optionValueIds,
        if (line.unitPrice != null) 'unitPrice': line.unitPrice,
      });
    }
    return merged;
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
    _onCartChanged();
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
      if (entry['isBundle'] == true) {
        final bundleId = entry['bundleId']?.toString() ?? entry['productId']?.toString() ?? '';
        if (bundleId.isEmpty) continue;
        final title = entry['bundleTitle']?.toString() ?? S.bundleLabel;
        final price = (entry['bundlePrice'] as num?)?.toDouble() ?? (entry['unitPrice'] as num?)?.toDouble() ?? 0.0;
        final quantity = (entry['quantity'] as num?)?.toInt().clamp(1, 99) ?? 1;
        final components = <CartBundleComponent>[];
        final rawComponents = entry['bundleComponents'];
        if (rawComponents is List) {
          for (final raw in rawComponents) {
            if (raw is Map) {
              components.add(CartBundleComponent.fromJson(Map<String, dynamic>.from(raw)));
            }
          }
        }
        var image = entry['bundleImage']?.toString().trim() ?? '';
        if (image.isEmpty) {
          image = await _bundleFallbackImage(components, catalog);
        }
        final product = ProductModel(id: 'bundle:$bundleId', name: title, price: price, image: image);
        items.add(CartItem(product: product, quantity: quantity, note: entry['note']?.toString() ?? '', optionValueIds: _optionIds(entry['optionValueIds']), unitPrice: price, bundleId: bundleId, bundleComponents: components));
        if (items.length >= _maxItems) break;
        continue;
      }
      final productId = entry['productId']?.toString();
      if (productId == null || productId.isEmpty) continue;
      final product =
          (await catalog())[productId] ??
          await _catalogRepository.getById(productId, branchId: branchId);
      // Preserve unavailable lines on a branch switch instead of silently
      // dropping them; the customer can review before checkout.
      final resolvedProduct = product ??
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

      final quantity = (entry['quantity'] as num?)?.toInt().clamp(1, 99) ?? 1;
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
    for (final component in components) {
      final product =
          (await catalog())[component.productId] ??
          await _catalogRepository.getById(
            component.productId,
            branchId: branchId,
          );
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
      await SharedPref.setValue(
        key: _pendingKey,
        value: pending ? '1' : '',
      );
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
