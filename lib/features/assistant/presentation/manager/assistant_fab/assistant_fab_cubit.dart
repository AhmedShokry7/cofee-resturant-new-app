import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/constant/app_constant.dart';
import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/services/shared_pref.dart';
import 'package:new_coffee/features/assistant/data/assistant_greetings.dart';
import 'package:new_coffee/features/assistant/data/assistant_hints.dart';
import 'package:new_coffee/features/assistant/data/assistant_memory.dart';
import 'package:new_coffee/features/auth/data/repositories/auth_repository.dart';
import 'package:new_coffee/features/home/data/greeting.dart';
import 'package:new_coffee/features/orders/data/model/order_item_model.dart';
import 'package:new_coffee/features/orders/data/model/order_status.dart';
import 'package:new_coffee/features/orders/data/repositories/order_repository.dart';

part 'assistant_fab_state.dart';

/// Decides what the assistant entry point says, and when.
///
/// The bubble is a greeting the app has to earn: it needs the saved session,
/// the signed-in name and the order in progress. That is data access, so it
/// lives here rather than in the button's widget, which only renders
/// [AssistantFabState].
class AssistantFabCubit extends Cubit<AssistantFabState> {
  AssistantFabCubit({
    required this.hintCycle,
    required this.hintVisible,
    this.firstHintDelay = const Duration(seconds: 3),
    this.orders,
    this.auth,
  }) : super(const AssistantFabState());

  /// How long a bubble stays on screen, and how often they rotate.
  final Duration hintCycle;
  final Duration hintVisible;
  final Duration firstHintDelay;

  /// Null when the host has no order history or no signed-in customer to greet.
  final OrdersRepository? orders;
  final AuthRepository? auth;

  Timer? _cycleTimer;
  Timer? _hideTimer;
  Timer? _firstTimer;

  /// Loads the welcome bubble and starts the hint rotation.
  Future<void> start() async {
    await _loadWelcome();
    if (isClosed) return;
    _firstTimer = Timer(firstHintDelay, showHint);
    _cycleTimer = Timer.periodic(hintCycle, (_) => _cycle());
  }

  /// Called while the chat sheet is open, so no bubble competes with it.
  void sheetOpened() {
    _hideTimer?.cancel();
    emit(state.copyWith(showHint: false, sheetOpen: true));
  }

  void sheetClosed() {
    if (isClosed) return;
    emit(state.copyWith(sheetOpen: false));
  }

  void showHint() {
    if (isClosed || state.sheetOpen) return;
    _hideTimer?.cancel();
    emit(state.copyWith(showHint: true));
    _hideTimer = Timer(hintVisible, _hideHint);
  }

  void _hideHint() {
    if (isClosed) return;
    emit(state.copyWith(showHint: false));
  }

  /// After the first welcome bubble the entry point rotates the generic hints.
  void _cycle() {
    if (isClosed || state.sheetOpen) return;
    final hints = _hints();
    emit(
      state.copyWith(
        hasCycled: true,
        hintIndex: (state.hintIndex + 1) % (hints.isEmpty ? 1 : hints.length),
      ),
    );
    showHint();
  }

  List<String> _hints() =>
      state.replyArabic ? assistantHintsAr : assistantHints;

  /// The text the bubble shows right now.
  String get bubbleText {
    if (!state.hasCycled && state.welcomeText != null)
      return state.welcomeText!;
    final hints = _hints();
    if (hints.isEmpty) return '';
    return hints[state.hintIndex % hints.length];
  }

  Future<void> _loadWelcome() async {
    try {
      final saved = await SharedPref.getValue(key: AppConstant.routesKey);
      final memory = await AssistantMemory.load();
      final isReturning = saved == AppConstant.homeRoute;
      String? firstName;
      try {
        final user = await auth?.currentUser();
        firstName = firstNameOf(user?.name);
      } catch (_) {
        firstName = null;
      }
      final activeOrders = await _activeOrders();
      if (isClosed) return;
      final replyArabic = memory.totalChats > 0
          ? memory.replyArabic
          : AppLocale.instance.isArabic;
      final now = DateTime.now();
      emit(
        state.copyWith(
          isReturningUser: isReturning,
          firstName: firstName,
          replyArabic: replyArabic,
          welcomeText: replyArabic
              ? AssistantGreetings.welcomeBubbleAr(
                  isReturning: isReturning,
                  firstName: firstName,
                  now: now,
                  activeOrders: activeOrders,
                )
              : AssistantGreetings.welcomeBubble(
                  isReturning: isReturning,
                  firstName: firstName,
                  now: now,
                  activeOrders: activeOrders,
                ),
        ),
      );
    } catch (_) {
      // The welcome bubble is best-effort; the generic hints still rotate.
    }
  }

  /// Guests and offline callers have no order history to greet with.
  Future<List<OrderItemModel>> _activeOrders() async {
    final orders = this.orders;
    if (orders == null) return const [];
    try {
      return await orders.listOrders(status: OrderStatus.active);
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> close() {
    _firstTimer?.cancel();
    _cycleTimer?.cancel();
    _hideTimer?.cancel();
    return super.close();
  }
}
