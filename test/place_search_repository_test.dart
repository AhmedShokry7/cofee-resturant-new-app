import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/features/location/data/model/place_suggestion.dart';
import 'package:new_coffee/features/location/data/repositories/place_search_repository.dart';

/// Cover for the geocoding layer that turns free text into a pin and a pin back
/// into a place name.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));

  NominatimPlaceSearchRepository repositoryReturning(
    Object body, {
    int statusCode = 200,
    void Function(Uri uri)? onRequest,
    String host = 'https://nominatim.test',
  }) {
    final client = MockClient((request) async {
      onRequest?.call(request.url);
      return http.Response(
        jsonEncode(body),
        statusCode,
        headers: {'content-type': 'application/json'},
      );
    });
    // No real waiting: the throttle is exercised separately.
    return NominatimPlaceSearchRepository(
      client: client,
      host: host,
      minimumInterval: Duration.zero,
    );
  }

  group('PlaceSuggestion', () {
    test('splits the display name into a title and a subtitle', () {
      final place = PlaceSuggestionFactory.build(
        'Grand Central Terminal, Mid Town, New York, United States',
      );

      expect(place.title, 'Grand Central Terminal');
      expect(place.subtitle, 'Mid Town, New York, United States');
      // The full name is what belongs in the search field.
      expect(
        place.label,
        'Grand Central Terminal, Mid Town, New York, United States',
      );
    });

    test('a single-segment name leaves the subtitle empty', () {
      final place = PlaceSuggestionFactory.build('New York');

      expect(place.title, 'New York');
      expect(place.subtitle, isEmpty);
    });

    test('coordinates arrive as strings and become numbers', () {
      final place = PlaceSuggestionFactory.build(
        'New York',
        lat: '40.712776',
        lon: '-74.005974',
      );

      expect(place.latitude, 40.712776);
      expect(place.longitude, -74.005974);
    });

    test('an unparseable coordinate pair is reported as unusable', () {
      final place = PlaceSuggestionFactory.build('Nowhere', lat: 'x', lon: 'y');

      expect(place.hasUsableCoordinates, isFalse);
    });
  });

  group('search', () {
    test('sends the query and the app language', () async {
      Uri? seen;
      final repository = repositoryReturning(
        const <Map<String, dynamic>>[],
        onRequest: (uri) => seen = uri,
      );

      await repository.search('New York');

      expect(seen!.queryParameters['q'], 'New York');
      expect(seen!.queryParameters['accept-language'], 'en');
      expect(seen!.path, contains('/search'));
    });

    test('asks for results in Arabic when the UI is Arabic', () async {
      AppLocale.instance.debugSet(AppLanguage.arabic);
      Uri? seen;
      final repository = repositoryReturning(
        const <Map<String, dynamic>>[],
        onRequest: (uri) => seen = uri,
      );

      await repository.search('نيويورك');

      expect(seen!.queryParameters['accept-language'], 'ar');
    });

    test('parses rows into suggestions', () async {
      final repository = repositoryReturning([
        {
          'display_name': 'New York, New York, United States',
          'lat': '40.712776',
          'lon': '-74.005974',
          'class': 'place',
          'type': 'city',
        },
      ]);

      final places = await repository.search('New York');

      expect(places, hasLength(1));
      expect(places.single.title, 'New York');
      expect(places.single.category, 'place/city');
    });

    test('drops rows with no usable coordinates', () async {
      final repository = repositoryReturning([
        {'display_name': 'Broken', 'lat': 'x', 'lon': 'y'},
      ]);

      expect(await repository.search('Broken'), isEmpty);
    });

    test('an empty query never reaches the network', () async {
      var calls = 0;
      final repository = repositoryReturning(
        const <Map<String, dynamic>>[],
        onRequest: (_) => calls++,
      );

      expect(await repository.search('   '), isEmpty);
      expect(calls, 0);
    });
  });

  group('reverse', () {
    test(
      'asks for the most precise zoom so a pin resolves to a building',
      () async {
        Uri? seen;
        final repository = repositoryReturning({
          'display_name': '350 5th Ave, New York',
        }, onRequest: (uri) => seen = uri);

        await repository.reverse(latitude: 40.7484, longitude: -73.9857);

        expect(seen!.queryParameters['zoom'], '18');
        expect(seen!.queryParameters['lat'], '40.7484');
        expect(seen!.path, contains('/reverse'));
      },
    );

    test('returns the place name for the point', () async {
      final repository = repositoryReturning({
        'display_name': 'Empire State Building, New York',
        'lat': '40.7484',
        'lon': '-73.9857',
      });

      final place = await repository.reverse(
        latitude: 40.7484,
        longitude: -73.9857,
      );

      expect(place?.title, 'Empire State Building');
    });

    test('an unnamed point is null, not an exception', () async {
      final repository = repositoryReturning({'error': 'Unable to geocode'});

      expect(await repository.reverse(latitude: 0.5, longitude: 0.5), isNull);
    });
  });

  group('failures', () {
    test('a non-200 response is an exception, not an empty result', () async {
      final repository = repositoryReturning(
        const <Map<String, dynamic>>[],
        statusCode: 503,
      );

      expect(
        () => repository.search('New York'),
        throwsA(isA<PlaceSearchException>()),
      );
    });

    test('an unparseable body is an exception', () async {
      final client = MockClient((_) async => http.Response('not json', 200));
      final repository = NominatimPlaceSearchRepository(
        client: client,
        host: 'https://nominatim.test',
        minimumInterval: Duration.zero,
      );

      expect(
        () => repository.search('New York'),
        throwsA(isA<PlaceSearchException>()),
      );
    });
  });

  group('rate limiting', () {
    test('bursts are serialised and spaced out', () async {
      final starts = <Duration>[];
      var clock = Duration.zero;
      final client = MockClient((_) async {
        starts.add(clock);
        return http.Response('[]', 200);
      });
      final repository = NominatimPlaceSearchRepository(
        client: client,
        host: 'https://nominatim.test',
        // Short enough to keep the test fast, long enough to observe spacing.
        minimumInterval: const Duration(milliseconds: 40),
      );

      // The repository delays with Future.delayed, which the test clock only
      // advances through pumpWidget, so run the burst inside a fake-async-free
      // harness: just await it and measure the real elapsed order.
      final started = DateTime.now();
      await Future.wait([
        repository.search('a'),
        repository.search('b'),
        repository.search('c'),
      ]);
      final elapsed = DateTime.now().difference(started);

      expect(starts, hasLength(3));
      // Three serialised calls at 40ms apart cannot finish instantly.
      expect(elapsed, greaterThanOrEqualTo(const Duration(milliseconds: 60)));
    });
  });
}

/// Small helper so the model tests read as the API response they describe.
class PlaceSuggestionFactory {
  static PlaceSuggestion build(
    String displayName, {
    String lat = '0',
    String lon = '0',
  }) => PlaceSuggestion.fromJson({
    'display_name': displayName,
    'lat': lat,
    'lon': lon,
  });
}
