import 'package:flutter_test/flutter_test.dart';

import 'package:new_coffee/features/design/data/model/native_section.dart';
import 'package:new_coffee/features/design/data/model/published_design.dart';

void main() {
  test('customer splash parser reads the admin-published contract', () {
    final section = PublishedSection.fromJson({
      'id': 'splash_settings',
      'type': 'splash.settings',
      'visible': true,
      'properties': {
        'imageVisible': true,
        'imageUrl': 'https://cdn.example.test/brand.png',
        'text_ar': 'أهلًا',
        'text_en': 'Hello',
        'textColor': '#234567',
        'textSize': 21,
        'textAlignment': 'end',
        'backgroundColor': '#F0E0D0',
        'imageFit': 'cover',
        'imageWidth': 240,
        'imageHeight': 190,
        'verticalAlignment': 'bottom',
        'imageGap': 19,
        'imageAlignment': 'bottomRight',
        'durationMs': 3500,
        'animation': 'fade',
        'animationDurationMs': 700,
      },
    });
    final splash = SplashSettings.fromSections([section!]);

    expect(splash.visible, isTrue);
    expect(splash.imageUrl, 'https://cdn.example.test/brand.png');
    expect(splash.imageFit, 'cover');
    expect(splash.imageWidth, 240);
    expect(splash.imageHeight, 190);
    expect(splash.verticalAlignment, 'bottom');
    expect(splash.imageAlignment, 'bottomRight');
    expect(splash.imageGap, 19);
    expect(splash.text, isNotEmpty);
    expect(splash.textColor, '#234567');
    expect(splash.textSize, 21);
    expect(splash.textAlignment, 'end');
    expect(splash.backgroundColor, '#F0E0D0');
    expect(splash.duration, const Duration(milliseconds: 3500));
    expect(splash.animation, 'fade');
    expect(splash.animationDuration, const Duration(milliseconds: 700));
  });
}
