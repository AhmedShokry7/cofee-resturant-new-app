import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:new_coffee/core/constant/app_constant.dart';
import 'package:new_coffee/core/constant/app_images.dart';
import 'package:new_coffee/core/navigation/app_route_observer.dart';
import 'package:new_coffee/core/navigation/root_navigator.dart';
import 'package:new_coffee/core/services/shared_pref.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/assistant/data/assistant_greetings.dart';
import 'package:new_coffee/features/assistant/data/assistant_hints.dart';
import 'package:new_coffee/features/assistant/data/assistant_memory.dart';
import 'package:new_coffee/features/assistant/presentation/manager/assistant/assistant_cubit.dart';
import 'package:new_coffee/features/assistant/presentation/views/assistant_sheet.dart';
import 'package:new_coffee/features/home/data/greeting.dart';
import 'package:new_coffee/features/orders/data/orders_list.dart';
import 'package:new_coffee/features/auth/data/repositories/auth_repository.dart';
import 'package:new_coffee/features/auth/presentation/views/auth_page.dart';
import 'package:new_coffee/features/auth/presentation/views/forget_password_page.dart';
import 'package:new_coffee/features/auth/presentation/views/otp_page.dart';
import 'package:new_coffee/features/auth/presentation/views/phone_auth_page.dart';
import 'package:new_coffee/features/auth/presentation/views/reset_password_page.dart';
import 'package:new_coffee/features/auth/presentation/views/sign_up_page.dart';
import 'package:new_coffee/features/on_boarding/presentation/views/on_boarding_page.dart';
import 'package:new_coffee/features/welcome/presentation/view/welcome_view.dart';

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
  static const double _fabSize = 72;

  /// Routes where the assistant button must stay hidden
  /// (welcome / onboarding / auth flow).
  static const Set<String> _hiddenRoutes = {
    WelcomePage.routeName,
    OnBoardingView.routeName,
    AuthPage.routeName,
    SignUpPage.routeName,
    ForgetPasswordPage.routeName,
    ResetPasswordPage.routeName,
    PhoneAuthPage.routeName,
    OtpPage.routeName,
  };

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
      final activeOrders = getOrdersList()
          .where((order) => order.status.name == 'active')
          .toList();
      setState(() {
        _isReturningUser = isReturning;
        _firstName = firstName;
        _replyArabic = memory.replyArabic;
        _welcomeText = memory.replyArabic
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
        create: (_) => AssistantCubit()
          ..start(isReturning: _isReturningUser, firstName: _firstName),
        child: const AssistantSheet(),
      ),
    );
    if (mounted) setState(() => _sheetOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_sheetOpen) return const SizedBox.shrink();
    return ValueListenableBuilder<String?>(
      valueListenable: AppRouteObserver.instance.currentRouteName,
      builder: (context, routeName, _) {
        if (_hiddenRoutes.contains(routeName)) {
          return const SizedBox.shrink();
        }
        return Stack(
          children: [
            Positioned(
              key: const ValueKey('assistant_fab_pos'),
              right: 4.w,
              bottom: 55.h,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedOpacity(
                opacity: _showHint ? 1 : 0,
                duration: const Duration(milliseconds: 300),
                child: _showHint
                    ? Container(
                        constraints: BoxConstraints(maxWidth: 230.w),
                        margin: EdgeInsets.only(
                          bottom: SpacingTokens.sm.h,
                        ),
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
                              color: AppColor.blackColor.withValues(
                                alpha: 0.12,
                              ),
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
              GestureDetector(
                onTap: _openSheet,
                child: Image.asset(
                  AppImages.aiBot,
                  key: const ValueKey('assistant_fab_image'),
                  width: _fabSize.w,
                  height: _fabSize.w,
                ),
              ),
            ],
          ),
        ),
      ],
    );
      },
    );
  }
}

