import 'dart:async';

import 'package:flutter/material.dart';
import 'package:new_coffee/core/constant/app_images.dart';
import 'package:new_coffee/features/location/data/services/location_permission_service.dart';
import 'package:new_coffee/features/main/presentation/views/main_page.dart';
import 'package:new_coffee/core/theme/app_color.dart';

/// The app splash.
///
/// Android 12+ always paints a system splash before Flutter's first frame, and
/// that one is locked to a fixed circle, so the brand mark is drawn here
/// instead where the size is fully under our control. The native launch window
/// is kept blank and white so handing over to this screen is invisible.
class SplashView extends StatefulWidget {
  const SplashView({super.key, required this.targetRoute});

  static const routeName = "/splash";

  /// Route the app continues to once the splash is done.
  final String targetRoute;

  /// Long enough for the mark to register, short enough not to feel like a
  /// stall. Application initialisation already finished before this widget
  /// exists (see `main`), so this is presentation time only and never covers
  /// slow startup work.
  static const Duration displayDuration = Duration(milliseconds: 900);

  /// Entrance length. Sits inside the 220-300ms band the rest of the app uses
  /// for transitions, so the splash does not feel slower than the UI it hands
  /// over to.
  static const Duration entranceDuration = Duration(milliseconds: 300);

  /// Scale the mark starts from; it reaches full size as the fade completes.
  static const double _startScale = 0.92;

  /// Fraction of the narrow screen edge the logo is allowed to take.
  static const double _logoWidthRatio = 0.66;
  static const double _minLogoWidth = 160;
  static const double _maxLogoWidth = 320;

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
  ///
  /// The handover happens first and the location prompt is fired afterwards,
  /// off the critical path. Asking for permission before navigating meant the
  /// first screen was blocked on a system dialog: on a device where that
  /// dialog never came back, the app stayed frozen on the splash forever.
  Future<void> _openTargetRoute() async {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;
    Navigator.of(context).pushReplacementNamed(widget.targetRoute);
    if (widget.targetRoute == MainPage.routeName) {
      // The service never throws, so the request cannot break the app. It
      // only marks itself as prompted, so it asks at most once per install.
      unawaited(LocationPermissionService.requestOnFirstLaunch());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The asset is wider than it is tall (1024x827), so sizing on the narrow
    // screen edge keeps it at most ~53% of the short side in either
    // orientation and it can never be clipped.
    final shortestSide = MediaQuery.sizeOf(context).shortestSide;
    final logoWidth = (shortestSide * SplashView._logoWidthRatio).clamp(
      SplashView._minLogoWidth,
      SplashView._maxLogoWidth,
    );

    return Scaffold(
      backgroundColor: AppColor.whiteColor,
      body: Center(
        // Drives the entrance without owning an AnimationController, and passes
        // the finished logo through `child` so the image is not rebuilt on
        // every frame of the fade.
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: SplashView.entranceDuration,
          curve: Curves.easeOutCubic,
          builder: (context, progress, logo) => Opacity(
            opacity: progress,
            child: Transform.scale(
              scale:
                  SplashView._startScale +
                  (1 - SplashView._startScale) * progress,
              child: logo,
            ),
          ),
          child: Image.asset(
            AppImages.logo,
            width: logoWidth,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    );
  }
}
