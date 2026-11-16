import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/features/design/data/model/native_section.dart';
import 'package:new_coffee/features/design/data/model/published_design.dart';
import 'package:new_coffee/features/design/presentation/manager/design/design_cubit.dart';
import 'package:new_coffee/features/welcome/presentation/views/widgets/welcome_hero_image.dart';
import 'package:new_coffee/features/welcome/presentation/views/widgets/welcome_panel_content.dart';
import 'package:new_coffee/features/welcome/presentation/views/widgets/wavy_container.dart';
import 'package:new_coffee/core/theme/tokens.dart';
import 'package:new_coffee/shared/widgets/design_page_sections.dart';

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

    // المسافات المنشورة تعلو على الأصل: `top` بين الموجة والنصّ، و`gap`
    // بين العنوان ووصفه. غياب عقدة `welcome.spacing` يعني المسافات المرسومة.
    final spacing = context.select(
      (DesignCubit cubit) => nativeSection(
        cubit.state.pageSections('welcome'),
        DesignWidgetTypes.welcomeSpacing,
      ),
    );
    final clearance = spacing?.numberProperty('top') ?? _clearance;

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
              clearance,
              AppSpacing.xl,
              AppSpacing.xxl,
            ),
            child: SafeArea(
              top: false,
              child: DesignPageSectionsInline(
                pageId: 'welcome',
                child: const WelcomePanelContent(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
