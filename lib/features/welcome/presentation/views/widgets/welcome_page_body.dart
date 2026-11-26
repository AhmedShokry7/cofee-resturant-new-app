import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/tokens.dart';
import 'package:new_coffee/features/design/data/model/native_section.dart';
import 'package:new_coffee/features/design/data/model/published_design.dart';
import 'package:new_coffee/features/design/presentation/manager/design/design_cubit.dart';
import 'package:new_coffee/features/welcome/presentation/views/widgets/welcome_hero_image.dart';
import 'package:new_coffee/features/welcome/presentation/views/widgets/welcome_panel_content.dart';
import 'package:new_coffee/features/welcome/presentation/views/widgets/wavy_container.dart';

/// The editable hero image and wave panel for the customer welcome page.
class WelcomePageBody extends StatelessWidget {
  const WelcomePageBody({super.key});

  static const double _imageRatio = 0.63;
  static const double _compactImageRatio = 0.62;
  static const double _compactScreenMaxHeight = 720;
  static const double _clearance = 20;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isCompact = size.height < _compactScreenMaxHeight;
    final sections = context.select(
      (DesignCubit cubit) => cubit.state.pageSections('welcome'),
    );
    final settings = nativeSection(sections, DesignWidgetTypes.welcomeSpacing);
    final hero = nativeSection(sections, DesignWidgetTypes.welcomeHero);
    final defaultRatio = isCompact ? _compactImageRatio : _imageRatio;
    final ratio = (hero?.numberProperty('heightRatio') ?? defaultRatio).clamp(
      0.25,
      0.85,
    );
    final curveDepth =
        (settings?.numberProperty('curveDepth') ??
                WavyContainer.designCurveDepth)
            .clamp(0.0, 140.0);
    final imageHeight = nativeHidden(hero) ? curveDepth : size.height * ratio;
    final clearance = settings?.numberProperty('top') ?? _clearance;
    final horizontal =
        settings?.numberProperty('paddingHorizontal') ?? AppSpacing.xxl;
    final bottom = settings?.numberProperty('paddingBottom') ?? AppSpacing.xxl;
    final panelColor = _hexColor(settings?.property('panelColor'));

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
          top: imageHeight - curveDepth,
          left: 0,
          right: 0,
          bottom: 0,
          child: WavyContainer(
            curveHeight: curveDepth,
            color: panelColor ?? AppColor.cardSurface,
            padding: EdgeInsets.fromLTRB(
              horizontal,
              clearance,
              horizontal,
              bottom,
            ),
            child: const SafeArea(top: false, child: WelcomePanelContent()),
          ),
        ),
      ],
    );
  }

  static Color? _hexColor(String? value) {
    if (value == null ||
        !RegExp(r'^#(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$').hasMatch(value)) {
      return null;
    }
    final parsed = int.parse(value.substring(1), radix: 16);
    return value.length == 9 ? Color(parsed) : Color(0xFF000000 | parsed);
  }
}
