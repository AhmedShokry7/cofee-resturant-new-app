import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/constant/app_images.dart';
import 'package:new_coffee/features/design/data/model/native_section.dart';
import 'package:new_coffee/features/design/data/model/published_design.dart';
import 'package:new_coffee/features/design/presentation/manager/design/design_cubit.dart';
import 'package:new_coffee/shared/widgets/db_image.dart';

/// Displays the welcome page's image using its published design properties.
class WelcomeHeroImage extends StatelessWidget {
  const WelcomeHeroImage({super.key});

  @override
  Widget build(BuildContext context) {
    final node = context.select(
      (DesignCubit cubit) => nativeSection(
        cubit.state.pageSections('welcome'),
        DesignWidgetTypes.welcomeHero,
      ),
    );
    if (nativeHidden(node)) return const SizedBox.shrink();

    final opacity = (node?.numberProperty('opacity') ?? 1).clamp(0.0, 1.0);
    final fit = DbImage.fitFromName(node?.property('fit'));
    final alignment = DbImage.alignmentFromName(
      node?.property('alignment') ?? 'topCenter',
    );
    final imageUrl = node?.property('imageUrl')?.trim() ?? '';
    final Widget image = imageUrl.isEmpty
        ? Image(
            image: const AssetImage(AppImages.welcomeImage),
            fit: fit,
            alignment: alignment,
          )
        : DbImage(image: imageUrl, fit: fit, alignment: alignment);
    return Opacity(opacity: opacity, child: image);
  }
}
