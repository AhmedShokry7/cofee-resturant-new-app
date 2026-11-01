import 'dart:async';

import 'package:flutter/material.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/features/splash/presentation/views/widgets/splash_brand_mark.dart';

/// The app splash.
///
/// Android 12+ always paints a system splash before Flutter's first frame, and
/// that one is locked to a fixed circle, so the brand mark is drawn here
/// instead where the size is fully under our control. The native launch window
/// is kept blank and white, so handing over to this screen is invisible.
///
/// Its only job is the handover: it holds the brand mark for
/// [SplashView.displayDuration] and then replaces itself with the route the
/// saved session asked for. Nothing is waited on in between - application
/// initialisation finished before this widget existed, and anything that has to
/// ask the customer for something belongs to the screen that follows.
class SplashView extends StatefulWidget {
  const SplashView({super.key, required this.targetRoute});

  static const routeName = "/splash";

  /// Route the app continues to once the splash is done.
  final String targetRoute;

  /// Long enough for the mark to register, short enough not to feel like a
  /// stall. This is presentation time only and never covers slow startup work.
  static const Duration displayDuration = Duration(milliseconds: 1000);

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> {
  Timer? _timer;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(SplashView.displayDuration, _openTargetRoute);
  }

  /// Hands over to the saved entry route exactly once.
  ///
  /// `mounted` alone is not enough: it stays true for the whole replacement
  /// animation, and a rebuild triggered by startup state (a locale change, for
  /// example) must not be able to schedule a second push. The guard is checked
  /// before `mounted` so a rebuild cannot reset the decision, and the target
  /// route is read at call time rather than captured, so a rebuilt widget
  /// navigates to its current destination instead of a stale one.
  void _openTargetRoute() {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;
    Navigator.of(context).pushReplacementNamed(widget.targetRoute);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Spelled out rather than inherited from the theme, because this screen
      // has to match the native launch window exactly: white in every system
      // appearance, whatever the app's own screens decide later.
      backgroundColor: AppColor.whiteColor,
      body: const Center(child: SplashBrandMark()),
    );
  }
}
