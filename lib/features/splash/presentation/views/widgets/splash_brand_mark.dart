import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/constant/app_images.dart';
import 'package:new_coffee/core/theme/motion_tokens.dart';
import 'package:new_coffee/features/design/presentation/manager/design/design_cubit.dart';
import 'package:new_coffee/features/design/presentation/manager/design/design_state.dart';
import 'package:new_coffee/shared/widgets/db_image.dart';

/// The brand mark, arriving with the splash.
///
/// The asset is wider than it is tall ([SplashBrandMark.assetWidth] over
/// [SplashBrandMark.assetHeight]), so sizing it on the narrow screen edge keeps
/// it at most about half of the short side in either orientation and it can
/// never be clipped.
class SplashBrandMark extends StatelessWidget {
  const SplashBrandMark({super.key});

  /// Fraction of the narrow screen edge the mark is allowed to take.
  static const double widthRatio = 0.66;

  /// The bounds the mark is clamped between, so a small phone still reads a
  /// brand and a tablet does not get a wall of logo.
  static const double minWidth = 160;
  static const double maxWidth = 320;

  /// The dimensions of [AppImages.logo], kept here because the picture and the
  /// space it needs are decided together.
  static const double assetWidth = 1024;
  static const double assetHeight = 827;

  /// The scale the mark starts from; it reaches full size as the fade
  /// completes.
  static const double startScale = 0.92;

  @override
  Widget build(BuildContext context) {
    final shortestSide = MediaQuery.sizeOf(context).shortestSide;
    final width = (shortestSide * widthRatio).clamp(minWidth, maxWidth);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: MotionTokens.entrance,
      curve: MotionTokens.entranceCurve,
      // Drives the entrance without owning an AnimationController, and passes
      // the finished logo through `child` so the image is not rebuilt on every
      // frame of the fade.
      builder: (context, progress, logo) => Opacity(
        opacity: progress,
        child: Transform.scale(
          scale: startScale + (1 - startScale) * progress,
          child: logo,
        ),
      ),
      // لوجو الهوية المنشورة يعلو على المضمّن: رابط صالح يعني اللوجو الجديد،
      // وغيابه يعني الملف المرفق كما كان.
      child: BlocBuilder<DesignCubit, DesignState>(
        builder: (context, design) {
          final logoUrl = design.logoUrl;
          if (logoUrl != null && logoUrl.trim().isNotEmpty) {
            return DbImage(
              image: logoUrl,
              fit: BoxFit.contain,
              width: width,
              iconSize: 32,
            );
          }
          return Image.asset(
            AppImages.logo,
            width: width,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          );
        },
      ),
    );
  }
}
