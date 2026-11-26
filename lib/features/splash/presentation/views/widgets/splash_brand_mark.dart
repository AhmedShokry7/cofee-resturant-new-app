import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/constant/app_images.dart';
import 'package:new_coffee/features/design/data/model/native_section.dart';
import 'package:new_coffee/features/design/presentation/manager/design/design_cubit.dart';
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
    final maxImageWidth = shortestSide < minWidth ? minWidth : shortestSide;
    final width = (settings.imageWidth ?? defaultWidth)
        .clamp(40.0, maxImageWidth)
        .toDouble();
    final imageHeight =
        settings.imageShape == 'circle' || settings.imageShape == 'square'
        ? width
        : settings.imageHeight;
    final imageAlignment = _alignment(settings.imageAlignment);
    final textAlign = switch (settings.textAlignment) {
      'start' => TextAlign.start,
      'end' => TextAlign.end,
      _ => TextAlign.center,
    };

    final content = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: settings.contentPaddingHorizontal,
        vertical: settings.contentPaddingVertical,
      ),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (settings.imageVisible)
              Align(
                alignment: imageAlignment,
                child: Padding(
                  padding: EdgeInsets.all(settings.imagePadding),
                  child: _brandImage(context, settings, width, imageHeight),
                ),
              ),
            if (settings.text != null) ...[
              SizedBox(
                height: settings.imageVisible
                    ? settings.imageGap + settings.textMarginTop
                    : settings.textMarginTop,
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  settings.textPaddingHorizontal,
                  settings.textPaddingVertical,
                  settings.textPaddingHorizontal,
                  settings.textPaddingVertical + settings.textMarginBottom,
                ),
                child: Text(
                  settings.text!,
                  textAlign: textAlign,
                  style: TextStyle(
                    color: SplashSettings.colorFromHex(
                      settings.textColor,
                      fallback: AppColor.inkDefault,
                    ),
                    fontSize: settings.textSize,
                    fontWeight: switch (settings.textWeight) {
                      'light' => AppFontWeights.regular,
                      'medium' => AppFontWeights.medium,
                      'bold' => AppFontWeights.bold,
                      _ => AppFontWeights.regular,
                    },
                  ),
                ),
              ),
            ],
          ],
        ),
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

  /// الصورة الخاصة بالافتتاحية تقول كلمتها قبل شعار الهوية؛ غيابها يعود للشعار.
  ///
  /// نراقب كامل حالة التصميم لا `logoUrl` وحده: مستند المعاينة قد يتغيّر
  /// بصورة الافتتاحية نفسها، وفي تلك الحالة لا يتحرك `logoUrl` إطلاقًا.
  Widget _brandImage(
    BuildContext context,
    SplashSettings settings,
    double width,
    double? height,
  ) {
    final logoUrl = context.watch<DesignCubit>().state.logoUrl;
    final custom = settings.imageUrl?.trim();
    final source = custom != null && custom.isNotEmpty ? custom : logoUrl;
    if (source != null && source.trim().isNotEmpty) {
      return _shapeImage(
        settings,
        DbImage(
          key: ValueKey('splash-image-$source'),
          image: source,
          fit: _fit(settings.imageFit),
          alignment: DbImage.alignmentFromName(settings.imageAlignment),
          width: width,
          height: height,
          iconSize: 32,
        ),
        width,
        height,
      );
    }
    return _shapeImage(
      settings,
      Image.asset(
        AppImages.logo,
        key: const ValueKey('splash-image-default'),
        width: width,
        height: height,
        fit: _fit(settings.imageFit),
        alignment: DbImage.alignmentFromName(settings.imageAlignment),
        filterQuality: FilterQuality.high,
      ),
      width,
      height,
    );
  }

  Widget _shapeImage(
    SplashSettings settings,
    Widget image,
    double width,
    double? height,
  ) {
    final radius = switch (settings.imageShape) {
      'circle' => width / 2,
      'rounded' => settings.imageCornerRadius,
      _ => 0.0,
    };
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(width: width, height: height, child: image),
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
