import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/constant/app_images.dart';
import 'package:new_coffee/features/design/data/model/native_section.dart';
import 'package:new_coffee/features/design/presentation/manager/design/design_cubit.dart';
import 'package:new_coffee/features/design/presentation/manager/design/design_state.dart';
import 'package:new_coffee/shared/widgets/db_image.dart';

/// محتوى الافتتاحية المنشور. رابط الصورة الخاص بها يعلو على شعار الهوية؛
/// وفي غيابه يبقى شعار الهوية أو الأصل المضمّن كما كان.
class SplashBrandMark extends StatelessWidget {
  const SplashBrandMark({super.key, this.settings = const SplashSettings()});

  final SplashSettings settings;

  static const double widthRatio = 0.66;
  static const double minWidth = 160;
  static const double maxWidth = 320;
  static const double assetWidth = 1024;
  static const double assetHeight = 827;
  static const double startScale = 0.92;

  @override
  Widget build(BuildContext context) {
    final shortestSide = MediaQuery.sizeOf(context).shortestSide;
    final defaultWidth = (shortestSide * widthRatio).clamp(minWidth, maxWidth);
    final width = (settings.imageWidth ?? defaultWidth)
        .clamp(40, shortestSide)
        .toDouble();
    final imageAlignment = _alignment(settings.imageAlignment);
    final textAlign = switch (settings.textAlignment) {
      'start' => TextAlign.start,
      'end' => TextAlign.end,
      _ => TextAlign.center,
    };

    final content = SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (settings.imageVisible)
            Align(
              alignment: imageAlignment,
              child: BlocBuilder<DesignCubit, DesignState>(
                buildWhen: (previous, next) => previous.logoUrl != next.logoUrl,
                builder: (context, design) {
                  final source = (settings.imageUrl?.trim().isNotEmpty ?? false)
                      ? settings.imageUrl
                      : design.logoUrl;
                  final image = source != null && source.trim().isNotEmpty
                      ? DbImage(
                          image: source,
                          fit: _fit(settings.imageFit),
                          alignment: DbImage.alignmentFromName(
                            settings.imageAlignment,
                          ),
                          width: width,
                          height: settings.imageHeight,
                          iconSize: 32,
                        )
                      : Image.asset(
                          AppImages.logo,
                          width: width,
                          height: settings.imageHeight,
                          fit: _fit(settings.imageFit),
                          alignment: DbImage.alignmentFromName(
                            settings.imageAlignment,
                          ),
                          filterQuality: FilterQuality.high,
                        );
                  return image;
                },
              ),
            ),
          if (settings.text != null) ...[
            SizedBox(height: settings.imageVisible ? settings.imageGap : 0),
            Text(
              settings.text!,
              textAlign: textAlign,
              style: TextStyle(
                color: SplashSettings.colorFromHex(
                  settings.textColor,
                  fallback: const Color(0xFF1A1A1A),
                ),
                fontSize: settings.textSize,
              ),
            ),
          ],
        ],
      ),
    );

    if (settings.animation == 'none' ||
        settings.animationDuration == Duration.zero) {
      return content;
    }
    return TweenAnimationBuilder<double>(
      key: ValueKey(
        '${settings.animation}:${settings.animationDuration.inMilliseconds}',
      ),
      tween: Tween<double>(begin: 0, end: 1),
      duration: settings.animationDuration,
      curve: Curves.easeOutCubic,
      child: content,
      builder: (context, progress, child) => Opacity(
        opacity: progress,
        child: Transform.scale(
          scale: settings.animation == 'fadeScale'
              ? startScale + (1 - startScale) * progress
              : 1,
          child: child,
        ),
      ),
    );
  }

  static BoxFit _fit(String name) => switch (name) {
    'cover' => BoxFit.cover,
    'fill' => BoxFit.fill,
    'fitWidth' => BoxFit.fitWidth,
    'fitHeight' => BoxFit.fitHeight,
    'scaleDown' => BoxFit.scaleDown,
    _ => BoxFit.contain,
  };

  static Alignment _alignment(String name) => switch (name) {
    'topLeft' => Alignment.topLeft,
    'topCenter' => Alignment.topCenter,
    'topRight' => Alignment.topRight,
    'centerLeft' => Alignment.centerLeft,
    'centerRight' => Alignment.centerRight,
    'bottomLeft' => Alignment.bottomLeft,
    'bottomCenter' => Alignment.bottomCenter,
    'bottomRight' => Alignment.bottomRight,
    _ => Alignment.center,
  };
}
