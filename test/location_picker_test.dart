import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:latlong2/latlong.dart';

import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/features/location/data/model/place_suggestion.dart';
import 'package:new_coffee/features/location/data/repositories/place_search_repository.dart';
import 'package:new_coffee/features/location/presentation/widgets/location_picker.dart';

class _FakePlaceSearch implements PlaceSearchRepository {
  _FakePlaceSearch({this.results = const [], this.failSearch = false});

  List<PlaceSuggestion> results;
  List<String> queries = [];
  int reverseCalls = 0;
  bool failSearch;

  @override
  Future<List<PlaceSuggestion>> search(String query, {int limit = 8}) async {
    queries.add(query);
    if (failSearch) throw const PlaceSearchException('offline');
    return results.take(limit).toList();
  }

  @override
  Future<PlaceSuggestion?> reverse({
    required double latitude,
    required double longitude,
  }) async {
    reverseCalls++;
    return null;
  }
}

PlaceSuggestion _place(String title, {String? subtitle}) => PlaceSuggestion(
  label: subtitle == null ? title : '$title, $subtitle',
  title: title,
  subtitle: subtitle ?? '',
  latitude: 40.712776,
  longitude: -74.005974,
);

Future<void> _setSurface(WidgetTester tester) async {
  tester.view.physicalSize = const Size(360, 800) * 3.0;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Mounts the picker with an initial pin so the map never waits on the device
/// location plugin, which has no implementation under `flutter test`.
Future<void> _pumpPicker(
  WidgetTester tester,
  PlaceSearchRepository repository, {
  required TextEditingController controller,
  void Function(PickedLocation location)? onPicked,
  LatLng? initialPoint = const LatLng(40.712776, -74.005974),
}) async {
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(360, 690),
      minTextAdapt: true,
      builder: (context, _) => MaterialApp(
        home: Scaffold(
          body: LocationPicker(
            repository: repository,
            controller: controller,
            initialPoint: initialPoint,
            onPicked: onPicked ?? (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));

  late TextEditingController controller;

  setUp(() => controller = TextEditingController());
  tearDown(() => controller.dispose());

  testWidgets('typing lists matching places', (tester) async {
    await _setSurface(tester);
    final repository = _FakePlaceSearch(
      results: [
        _place('New York', subtitle: 'New York, United States'),
        _place('New York Mills', subtitle: 'New York, United States'),
      ],
    );
    await _pumpPicker(tester, repository, controller: controller);

    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'New Yo');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(repository.queries, ['New Yo']);
    expect(find.text('New York'), findsOneWidget);
    expect(find.text('New York Mills'), findsOneWidget);
  });

  testWidgets('a burst of keystrokes costs one request', (tester) async {
    await _setSurface(tester);
    final repository = _FakePlaceSearch();
    await _pumpPicker(tester, repository, controller: controller);

    await tester.tap(find.byType(TextField));
    for (final fragment in ['N', 'Ne', 'New', 'New Y']) {
      await tester.enterText(find.byType(TextField), fragment);
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(repository.queries, ['New Y']);
  });

  testWidgets('a query below the minimum length never reaches the geocoder', (
    tester,
  ) async {
    await _setSurface(tester);
    final repository = _FakePlaceSearch();
    await _pumpPicker(tester, repository, controller: controller);

    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'N');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(repository.queries, isEmpty);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('picking a suggestion fills the field and reports the place', (
    tester,
  ) async {
    await _setSurface(tester);
    final repository = _FakePlaceSearch(
      results: [_place('New York', subtitle: 'New York, United States')],
    );
    PickedLocation? picked;
    await _pumpPicker(
      tester,
      repository,
      controller: controller,
      onPicked: (location) => picked = location,
    );

    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'New York');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    // The subtitle is unique, so the tap cannot land on the field's own text.
    await tester.tap(find.text('New York, United States'));
    await tester.pumpAndSettle();

    expect(controller.text, 'New York, New York, United States');
    expect(picked, isNotNull);
    expect(picked!.label, 'New York, New York, United States');
    expect(picked!.point.latitude, closeTo(40.712776, 0.000001));
    // The suggestion list is gone once a place is chosen.
    expect(find.text('New York'), findsNothing);
  });

  testWidgets('a geocoder failure shows no suggestions and does not throw', (
    tester,
  ) async {
    await _setSurface(tester);
    final repository = _FakePlaceSearch(failSearch: true);
    await _pumpPicker(tester, repository, controller: controller);

    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'New York');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(repository.queries, ['New York']);
  });

  testWidgets('the clear button empties the field', (tester) async {
    await _setSurface(tester);
    final repository = _FakePlaceSearch(
      results: [_place('New York', subtitle: 'New York, United States')],
    );
    await _pumpPicker(tester, repository, controller: controller);

    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'New York');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    await tester.tap(find.byIcon(HugeIcons.strokeRoundedCancel01));
    await tester.pump();

    expect(controller.text, isEmpty);
  });

  testWidgets('the place name from a pick is what the field shows', (
    tester,
  ) async {
    await _setSurface(tester);
    final repository = _FakePlaceSearch(
      results: [_place('Empire State Building', subtitle: 'New York')],
    );
    await _pumpPicker(tester, repository, controller: controller);

    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'Empire');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    await tester.tap(find.text('Empire State Building'));
    await tester.pumpAndSettle();

    // The full name, not just the title the customer typed.
    expect(controller.text, 'Empire State Building, New York');
    expect(find.text('Empire State Building, New York'), findsOneWidget);
  });
}