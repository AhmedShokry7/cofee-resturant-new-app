import 'package:new_coffee/core/theme/app_color.dart';
import 'package:material_ui/material_ui.dart';

import 'package:new_coffee/features/design/data/model/published_design.dart';

/// عقدة شاشة مدمجة في أقسام صفحة، بالترتيب المنشور.
///
/// الشاشات المدمجة تقرأ عقدها من المستند المنشور لتعديل ما يعرضه أصل الشاشة؛
/// خاصية غائبة تعني «كما هو»، و`visible: false` إخفاء صريح للمكوّن الأصلي.
PublishedSection? nativeSection(List<PublishedSection> sections, String type) {
  for (final section in sections) {
    if (section.type == type) return section;
  }
  return null;
}

/// هل عقدة شاشة مدمجة تطلب إخفاء المكوّن الأصلي؟
bool nativeHidden(PublishedSection? node) => node != null && !node.visible;

/// إعدادات شاشة الافتتاحية المنشورة. القيم الافتراضية تطابق شاشة اليوم حتى
/// يظل المستند القديم أو الغائب متوافقًا تمامًا.
@immutable
class SplashSettings {
  const SplashSettings({
    this.visible = true,
    this.imageUrl,
    this.imageVisible = true,
    this.imageFit = 'contain',
    this.imageShape = 'original',
    this.imageCornerRadius = 16,
    this.imageAlignment = 'center',
    this.verticalAlignment = 'center',
    this.imageWidth,
    this.imageHeight,
    this.imageGap = 16,
    this.contentPaddingHorizontal = 24,
    this.contentPaddingVertical = 24,
    this.imagePadding = 0,
    this.textPaddingHorizontal = 0,
    this.textPaddingVertical = 0,
    this.textMarginTop = 0,
    this.textMarginBottom = 0,
    this.textWeight = 'regular',
    this.text,
    this.textColor = '#1A1A1A',
    this.textSize = 16,
    this.textAlignment = 'center',
    this.backgroundColor = '#FFFFFF',
    this.duration = const Duration(milliseconds: 1000),
    this.animation = 'fadeScale',
    this.animationDuration = const Duration(milliseconds: 300),
  });

  final bool visible;
  final String? imageUrl;
  final bool imageVisible;
  final String imageFit;
  final String imageShape;
  final double imageCornerRadius;
  final String imageAlignment;
  final String verticalAlignment;
  final double? imageWidth;
  final double? imageHeight;
  final double imageGap;
  final double contentPaddingHorizontal;
  final double contentPaddingVertical;
  final double imagePadding;
  final double textPaddingHorizontal;
  final double textPaddingVertical;
  final double textMarginTop;
  final double textMarginBottom;
  final String textWeight;
  final String? text;
  final String textColor;
  final double textSize;
  final String textAlignment;
  final String backgroundColor;
  final Duration duration;
  final String animation;
  final Duration animationDuration;

  static SplashSettings fromSections(List<PublishedSection> sections) {
    final node = nativeSection(sections, DesignWidgetTypes.splashSettings);
    final url = node?.property('imageUrl')?.trim();
    final text = node?.localizedText('text')?.trim();
    final durationMs = node?.numberProperty('durationMs');
    final animationDurationMs = node?.numberProperty('animationDurationMs');
    final width = node?.numberProperty('imageWidth');
    final height = node?.numberProperty('imageHeight');
    final gap = node?.numberProperty('imageGap');
    final size = node?.numberProperty('textSize');
    double number(String key, double fallback, double max) {
      final value = node?.numberProperty(key);
      return value != null && value >= 0 && value <= max ? value : fallback;
    }

    final animation = node?.property('animation');
    final fit = node?.property('imageFit');
    final alignment = node?.property('imageAlignment');
    final verticalAlignment = node?.property('verticalAlignment');
    final textAlignment = node?.property('textAlignment');
    final imageShape = node?.property('imageShape');
    final textWeight = node?.property('textWeight');
    final background = _validHex(node?.property('backgroundColor'));
    final textColor = _validHex(node?.property('textColor'));

    return SplashSettings(
      visible: !nativeHidden(node),
      imageUrl: url == null || url.isEmpty ? null : url,
      imageVisible: node?.flagProperty('imageVisible', fallback: true) ?? true,
      imageFit:
          const {
            'contain',
            'cover',
            'fill',
            'fitWidth',
            'fitHeight',
            'scaleDown',
          }.contains(fit)
          ? fit!
          : 'contain',
      imageShape:
          const {'original', 'circle', 'square', 'rounded'}.contains(imageShape)
          ? imageShape!
          : 'original',
      imageCornerRadius: number('imageCornerRadius', 16, 200),
      verticalAlignment:
          const {'top', 'center', 'bottom'}.contains(verticalAlignment)
          ? verticalAlignment!
          : 'center',
      imageAlignment:
          const {
            'topCenter',
            'topLeft',
            'topRight',
            'centerLeft',
            'center',
            'centerRight',
            'bottomLeft',
            'bottomCenter',
            'bottomRight',
          }.contains(alignment)
          ? alignment!
          : 'center',
      imageWidth: width != null && width >= 40 && width <= 600 ? width : null,
      imageHeight: height != null && height >= 40 && height <= 700
          ? height
          : null,
      imageGap: gap != null && gap >= 0 && gap <= 100 ? gap : 16,
      contentPaddingHorizontal: number('contentPaddingHorizontal', 24, 200),
      contentPaddingVertical: number('contentPaddingVertical', 24, 300),
      imagePadding: number('imagePadding', 0, 100),
      textPaddingHorizontal: number('textPaddingHorizontal', 0, 100),
      textPaddingVertical: number('textPaddingVertical', 0, 100),
      textMarginTop: number('textMarginTop', 0, 100),
      textMarginBottom: number('textMarginBottom', 0, 100),
      textWeight:
          const {'light', 'regular', 'medium', 'bold'}.contains(textWeight)
          ? textWeight!
          : 'regular',
      text: text == null || text.isEmpty ? null : text,
      textColor: textColor ?? '#1A1A1A',
      textSize: size != null && size >= 8 && size <= 48 ? size : 16,
      textAlignment: const {'start', 'center', 'end'}.contains(textAlignment)
          ? textAlignment!
          : 'center',
      backgroundColor: background ?? '#FFFFFF',
      duration: Duration(
        milliseconds: (durationMs ?? 1000).round().clamp(0, 30000).toInt(),
      ),
      animation: const {'none', 'fade', 'fadeScale'}.contains(animation)
          ? animation!
          : 'fadeScale',
      animationDuration: Duration(
        milliseconds: (animationDurationMs ?? 300)
            .round()
            .clamp(0, 5000)
            .toInt(),
      ),
    );
  }

  static String? _validHex(String? value) {
    if (value == null ||
        !RegExp(r'^#(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$').hasMatch(value)) {
      return null;
    }
    return value;
  }

  static Color colorFromHex(
    String value, {
    Color fallback = AppColor.whiteColor,
  }) {
    final hex = _validHex(value);
    if (hex == null) return fallback;
    final color = int.parse(hex.substring(1), radix: 16);
    return hex.length == 9 ? Color(color) : Color(0xFF000000 | color);
  }

  @override
  bool operator ==(Object other) =>
      other is SplashSettings &&
      other.visible == visible &&
      other.imageUrl == imageUrl &&
      other.imageVisible == imageVisible &&
      other.imageFit == imageFit &&
      other.imageShape == imageShape &&
      other.imageCornerRadius == imageCornerRadius &&
      other.imageAlignment == imageAlignment &&
      other.verticalAlignment == verticalAlignment &&
      other.imageWidth == imageWidth &&
      other.imageHeight == imageHeight &&
      other.imageGap == imageGap &&
      other.contentPaddingHorizontal == contentPaddingHorizontal &&
      other.contentPaddingVertical == contentPaddingVertical &&
      other.imagePadding == imagePadding &&
      other.textPaddingHorizontal == textPaddingHorizontal &&
      other.textPaddingVertical == textPaddingVertical &&
      other.textMarginTop == textMarginTop &&
      other.textMarginBottom == textMarginBottom &&
      other.textWeight == textWeight &&
      other.text == text &&
      other.textColor == textColor &&
      other.textSize == textSize &&
      other.textAlignment == textAlignment &&
      other.backgroundColor == backgroundColor &&
      other.duration == duration &&
      other.animation == animation &&
      other.animationDuration == animationDuration;

  @override
  int get hashCode => Object.hashAll([
    visible,
    imageUrl,
    imageVisible,
    imageFit,
    imageShape,
    imageCornerRadius,
    imageAlignment,
    verticalAlignment,
    imageWidth,
    imageHeight,
    imageGap,
    contentPaddingHorizontal,
    contentPaddingVertical,
    imagePadding,
    textPaddingHorizontal,
    textPaddingVertical,
    textMarginTop,
    textMarginBottom,
    textWeight,
    text,
    textColor,
    textSize,
    textAlignment,
    backgroundColor,
    duration,
    animation,
    animationDuration,
  ]);
}
