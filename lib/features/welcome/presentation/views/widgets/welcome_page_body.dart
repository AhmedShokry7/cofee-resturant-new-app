import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/services/session_repository.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/features/on_boarding/presentation/views/on_boarding_view.dart';
import 'package:new_coffee/features/welcome/presentation/views/widgets/custom_welcome_images.dart';
import 'package:new_coffee/features/welcome/presentation/views/widgets/welcome_page_text_body.dart';
import 'package:new_coffee/features/welcome/presentation/views/widgets/welcome_page_text_title.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';
import 'package:new_coffee/shared/widgets/wavy_container.dart';

class WelcomePageBody extends StatelessWidget {
  const WelcomePageBody({super.key});

  /// Image height as a share of the screen. The photo is tall enough for the
  /// wave to sink down close to the copy instead of leaving a dead gap.
  static const double _imageRatio = 0.63;
  static const double _compactImageRatio = 0.62;

  /// Depth of the wave. The panel overlaps the photo by the same amount, so
  /// the wave always meets the bottom edge of the photo.
  static const double _curveHeight = 55;

  /// Reduce the gap between the curve and the content.
  static const double _curveClearance = 20;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isCompact = size.height < 720;

    final imageHeight =
        size.height * (isCompact ? _compactImageRatio : _imageRatio);

    return Scaffold(
      body: Stack(
        children: [
          // Main photography
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: imageHeight,
            child: const CustomWelcomeImages(),
          ),

          // Curved content panel overlapping the bottom of the image
          Positioned(
            top: imageHeight - _curveHeight.h,
            left: 0,
            right: 0,
            bottom: 0,
            child: WavyContainer(
              curveHeight: _curveHeight.h,
              padding: EdgeInsets.fromLTRB(
                SpacingTokens.xl.w,
                _curveClearance.h,
                SpacingTokens.xl.w,
                SpacingTokens.lg.h,
              ),
              child: SafeArea(
                top: false,
                child: _WelcomePanelContent(isCompact: isCompact),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomePanelContent extends StatelessWidget {
  const _WelcomePanelContent({required this.isCompact});

  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    // The panel is laid out inside a Positioned with `bottom: 0`, so its height
    // is already bounded and the column lays out directly, without scrolling.
    // Nothing scales the copy: the title and body render at their real size.
    return Column(
      children: [
        const Spacer(flex: 2),

        const WelcomeViewTextTitle(),

        SizedBox(height: SpacingTokens.md.h),

        const WelcomeViewTextBody(),

        SizedBox(height: SpacingTokens.xl.h),

        SizedBox(
          width: double.infinity,
          child: CustomBtn(
            text: S.letsGetStarted,
            onPressed: () async {
              // The marker is written before navigating: a fire-and-forget
              // write could still be in flight when the app is killed, and the
              // customer would then meet the onboarding again on the next
              // launch.
              await const SessionRepository().markOnboardingSeen();
              if (!context.mounted) return;
              Navigator.pushReplacementNamed(context, OnBoardingView.routeName);
            },
          ),
        ),

        SizedBox(height: SpacingTokens.sm.h),
      ],
    );
  }
}



