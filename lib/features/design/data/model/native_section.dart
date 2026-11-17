import 'package:flutter/material.dart';

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
    this.imageFit = 'contain',
    this.imageAlignment = 'center',
    this.verticalAlignment = 'center',
    this.imageWidth,
    this.imageHeight,
    this.imageGap = 16,
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
  final String imageFit;
  final String imageAlignment;
  final String verticalAlignment;
  final double? imageWidth;
  final double? imageHeight;
  final double imageGap;
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
    final animation = node?.property('animation');
    final fit = node?.property('imageFit');
    final alignment = node?.property('imageAlignment');
    final verticalAlignment = node?.property('verticalAlignment');
    final textAlignment = node?.property('textAlignment');
    final background = _validHex(node?.property('backgroundColor'));
    final textColor = _validHex(node?.property('textColor'));

    return SplashSettings(
      visible: !nativeHidden(node),
      imageUrl: url == null || url.isEmpty ? null : url,
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

  static Color colorFromHex(String value, {Color fallback = Colors.white}) {
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
      other.imageFit == imageFit &&
      other.imageAlignment == imageAlignment &&
      other.verticalAlignment == verticalAlignment &&
      other.imageWidth == imageWidth &&
      other.imageHeight == imageHeight &&
      other.imageGap == imageGap &&
      other.text == text &&
      other.textColor == textColor &&
      other.textSize == textSize &&
      other.textAlignment == textAlignment &&
      other.backgroundColor == backgroundColor &&
      other.duration == duration &&
      other.animation == animation &&
      other.animationDuration == animationDuration;

  @override
  int get hashCode => Object.hash(
    visible,
    imageUrl,
    imageFit,
    imageAlignment,
    verticalAlignment,
    imageWidth,
    imageHeight,
    imageGap,
    text,
    textColor,
    textSize,
    textAlignment,
    backgroundColor,
    duration,
    animation,
    animationDuration,
  );
}
