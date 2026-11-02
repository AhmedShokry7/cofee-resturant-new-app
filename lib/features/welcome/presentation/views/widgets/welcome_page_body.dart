import 'package:flutter/material.dart';

import 'package:new_coffee/features/welcome/presentation/views/widgets/welcome_hero_image.dart';
import 'package:new_coffee/features/welcome/presentation/views/widgets/welcome_panel_content.dart';
import 'package:new_coffee/features/welcome/presentation/views/widgets/wavy_container.dart';
import 'package:new_coffee/core/theme/tokens.dart';

/// The photograph and the panel that overlaps its bottom edge.
///
/// Layout only: it decides nothing and asks nothing of the backend.
class WelcomePageBody extends StatelessWidget {
  const WelcomePageBody({super.key});

  /// Image height as a share of the screen. The photo is tall enough for the
  /// wave to sink down close to the copy instead of leaving a dead gap.
  static const double _imageRatio = 0.63;

  /// The same share on a short screen, where the copy would otherwise be
  /// pushed under the panel.
  static const double _compactImageRatio = 0.62;

  /// Below this logical height the screen is treated as short.
  static const double _compactScreenMaxHeight = 720;

  /// The panel overlaps the photo by exactly the depth of the curve, so the
  /// wave always meets the bottom edge of the photo.
  static double get _curveDepth => WavyContainer.designCurveDepth;

  /// Gap between the curve and the copy, so the first line never touches it.
  static const double _clearance = 20;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isCompact = size.height < _compactScreenMaxHeight;
    final imageHeight =
        size.height * (isCompact ? _compactImageRatio : _imageRatio);

    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: imageHeight,
          child: const WelcomeHeroImage(),
        ),
        Positioned(
          top: imageHeight - _curveDepth,
          left: 0,
          right: 0,
          bottom: 0,
          child: WavyContainer(
            curveHeight: _curveDepth,
            padding: EdgeInsets.fromLTRB(
              AppSpacing.xxl,
              _clearance,
              AppSpacing.xl,
              AppSpacing.xxl,
            ),
            child: const SafeArea(top: false, child: WelcomePanelContent()),
          ),
        ),
      ],
    );
  }
}
