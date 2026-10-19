import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:new_coffee/core/constant/app_constant.dart';
import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/constant/app_images.dart';
import 'package:new_coffee/core/navigation/root_navigator.dart';
import 'package:new_coffee/core/services/shared_pref.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/assistant/data/assistant_greetings.dart';
import 'package:new_coffee/features/assistant/data/assistant_hints.dart';
import 'package:new_coffee/features/assistant/data/assistant_memory.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/assistant/data/llm/http_llm_client.dart';
import 'package:new_coffee/features/assistant/data/llm/llm_config.dart';
import 'package:new_coffee/features/assistant/data/llm/supabase_llm_client.dart';
import 'package:new_coffee/features/assistant/presentation/manager/assistant/assistant_cubit.dart';
import 'package:new_coffee/features/assistant/presentation/views/assistant_sheet.dart';
import 'package:new_coffee/features/branch/presentation/manager/branch/branch_cubit.dart';
import 'package:new_coffee/features/home/data/greeting.dart';
import 'package:new_coffee/features/menu/data/repositories/product_repository.dart';
import 'package:new_coffee/features/orders/data/model/order_item_model.dart';
import 'package:new_coffee/features/orders/data/model/order_status.dart';
import 'package:new_coffee/features/orders/data/repositories/order_repository.dart';
import 'package:new_coffee/features/auth/data/repositories/auth_repository.dart';

/// Smart assistant entry point, owned by the Home page.
///
/// Rendered in [HomePage]'s [Scaffold.floatingActionButton] slot, so the
/// button exists exactly once and only while the Home tab is visible. Route
/// filtering is unnecessary: pushed pages, auth flows and the other tabs
/// never contain this widget.
class AssistantFab extends StatefulWidget {
  const AssistantFab({super.key});

  @visibleForTesting
  static const hintCycle = Duration(minutes: 2);

  @visibleForTesting
  static const hintVisible = Duration(seconds: 6);

  @override
  State<AssistantFab> createState() => _AssistantFabState();
}

class _AssistantFabState extends State<AssistantFab> {
  /// Bot artwork size inside the standard 56dp FAB.
  static const double _fabIconSize = 44;

  bool _sheetOpen = false;
  bool _showHint = false;

  /// First bubble is a smart welcome (personal + order-aware);
  /// afterwards the bubble rotates through the generic hints.
  bool _hasCycled = false;
  String? _welcomeText;
  bool _isReturningUser = false;
  String? _firstName;
  bool _replyArabic = false;
  int _hintIndex = 0;
  Timer? _cycleTimer;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _loadWelcome();
    Timer(const Duration(seconds: 3), () {
      if (mounted) _displayHint();
    });
    _cycleTimer = Timer.periodic(AssistantFab.hintCycle, (_) {
      if (!mounted || _sheetOpen) return;
      _hasCycled = true;
      final hints = _replyArabic ? assistantHintsAr : assistantHints;
      _hintIndex = (_hintIndex + 1) % hints.length;
      _displayHint();
    });
  }

  /// Has this device completed the auth flow before?
  Future<List<OrderItemModel>> _activeOrders() async {
    try {
      return await context.read<OrdersRepository>().listOrders(
        status: OrderStatus.active,
      );
    } catch (_) {
      // Guests and offline callers have no order history to greet with.
      return const [];
    }
  }

  Future<void> _loadWelcome() async {
    AuthRepository? repository;
    try {
      repository = context.read<AuthRepository>();
    } catch (_) {
      repository = null;
    }
    try {
      final saved = await SharedPref.getValue(key: AppConstant.routesKey);
      final memory = await AssistantMemory.load();
      final isReturning = saved == AppConstant.homeRoute;
      String? firstName;
      try {
        final user = await repository?.currentUser();
        firstName = firstNameOf(user?.name);
      } catch (_) {
        firstName = null;
      }
      if (!mounted) return;
      final activeOrders = await _activeOrders();
      if (!mounted) return;
      setState(() {
        _isReturningUser = isReturning;
        _firstName = firstName;
        _replyArabic = memory.totalChats > 0
            ? memory.replyArabic
            : AppLocale.instance.isArabic;
        _welcomeText = _replyArabic
            ? AssistantGreetings.welcomeBubbleAr(
                isReturning: isReturning,
                firstName: firstName,
                now: DateTime.now(),
                activeOrders: activeOrders,
              )
            : AssistantGreetings.welcomeBubble(
                isReturning: isReturning,
                firstName: firstName,
                now: DateTime.now(),
                activeOrders: activeOrders,
              );
      });
    } catch (_) {
      // Welcome bubble is best-effort; generic hints still rotate.
    }
  }

  void _displayHint() {
    if (!mounted) return;
    setState(() => _showHint = true);
    _hideTimer?.cancel();
    _hideTimer = Timer(AssistantFab.hintVisible, () {
      if (mounted) setState(() => _showHint = false);
    });
  }

  /// First display is the smart welcome bubble (when loaded);
  /// every rotation afterwards uses the generic hints.
  String get _currentHintText {
    if (!_hasCycled && _welcomeText != null) return _welcomeText!;
    final hints = _replyArabic ? assistantHintsAr : assistantHints;
    return hints[_hintIndex % hints.length];
  }

  @override
  void dispose() {
    _cycleTimer?.cancel();
    _hideTimer?.cancel();
    super.dispose();
  }

  Future<void> _openSheet() async {
    final navContext = rootNavigatorKey.currentContext;
    if (navContext == null) return;
    setState(() {
      _sheetOpen = true;
      _showHint = false;
    });
    await showModalBottomSheet<void>(
      context: navContext,
      backgroundColor: AppColor.whiteColor,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (_) => BlocProvider(
        create: (_) => AssistantCubit(
          catalog: navContext.read<CatalogRepository>(),
          orders: navContext.read<OrdersRepository>(),
          branchId: navContext.read<BranchCubit>().state.selected?.id,
          llmClient: SupabaseService.isConfigured
              ? const SupabaseLlmClient()
              : const HttpLlmClient(LlmConfig()),
        )..start(isReturning: _isReturningUser, firstName: _firstName),
        child: const AssistantSheet(),
      ),
    );
    if (mounted) setState(() => _sheetOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    // While the sheet is open the entry point hides; ownership by the Home
    // page scaffold already limits visibility to the Home tab.
    if (_sheetOpen) return const SizedBox.shrink();
    return Column(
      key: const ValueKey('assistant_fab_pos'),
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedOpacity(
          opacity: _showHint ? 1 : 0,
          duration: const Duration(milliseconds: 300),
          child: _showHint
              ? Container(
                  constraints: BoxConstraints(maxWidth: 230.w),
                  margin: EdgeInsets.only(bottom: SpacingTokens.sm.h),
                  padding: EdgeInsets.symmetric(
                    horizontal: SpacingTokens.md.w,
                    vertical: SpacingTokens.sm.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppColor.whiteColor,
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(color: AppColor.borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: AppColor.blackColor.withValues(alpha: 0.12),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(top: 2.h),
                        child: Icon(
                          HugeIcons.strokeRoundedSparkles,
                          size: 14.w,
                          color: AppColor.primaryColor,
                        ),
                      ),
                      SizedBox(width: SpacingTokens.xs.w),
                      Flexible(
                        child: Text(
                          _currentHintText,
                          style: AppFonts.medium14(context).copyWith(
                            color: AppColor.blackColor,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
        FloatingActionButton(
          onPressed: _openSheet,
          backgroundColor: AppColor.whiteColor,
          elevation: 6,
          shape: const CircleBorder(),
          child: Image.asset(
            AppImages.aiBot,
            key: const ValueKey('assistant_fab_image'),
            width: _fabIconSize.w,
            height: _fabIconSize.w,
          ),
        ),
      ],
    );
  }
}
