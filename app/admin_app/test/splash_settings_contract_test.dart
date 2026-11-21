import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/features/splash_management/domain/splash_settings.dart';

void main() {
  group('SplashSettings design document contract', () {
    test('round trips all customer splash properties', () {
      const settings = SplashSettings(
        enabled: false,
        imageVisible: false,
        imageUrl: 'https://cdn.example.test/splash.png',
        textAr: 'أهلًا بكم',
        textEn: 'Welcome',
        textColor: '#123456',
        textSize: 22,
        textAlignment: 'end',
        backgroundColor: '#ABCDEF',
        imageFit: 'cover',
        imageWidth: 210,
        imageHeight: 180,
        verticalAlignment: 'bottom',
        imageGap: 25,
        imageAlignment: 'bottomRight',
        durationMs: 4200,
        animation: 'fade',
        animationDurationMs: 800,
      );

      final doc = SplashSettings.writeToDocument(null, settings);
      final restored = SplashSettings.fromDocument(doc);

      expect(restored.enabled, isFalse);
      expect(restored.toProperties(), settings.toProperties());
    });

    test('updates splash without removing other customer pages or theme', () {
      final source = <String, dynamic>{
        'schema_version': 2,
        'theme': {
          'colors': {'primary': '#112233'},
        },
        'pages': [
          {
            'page': 'home',
            'root': {
              'id': 'root_home',
              'type': 'page.home',
              'children': [
                {'id': 'home_header', 'type': 'section.header'},
              ],
            },
          },
          {
            'page': 'splash',
            'root': {
              'id': 'root_splash',
              'type': 'page.home',
              'children': [
                {
                  'id': 'splash_settings',
                  'type': 'splash.settings',
                  'visible': true,
                  'properties': {'customFlag': 'preserved'},
                },
              ],
            },
          },
        ],
      };

      final updated = SplashSettings.writeToDocument(
        source,
        const SplashSettings(backgroundColor: '#00FF00'),
      );

      expect(updated['theme'], source['theme']);
      final pages = updated['pages'] as List;
      expect(pages.map((page) => (page as Map)['page']), ['home', 'splash']);
      final splashNode = ((pages[1] as Map)['root'] as Map)['children'] as List;
      expect(
        (splashNode.single as Map)['properties']['customFlag'],
        'preserved',
      );
      expect(SplashSettings.fromDocument(updated).backgroundColor, '#00FF00');
    });
  });
}
