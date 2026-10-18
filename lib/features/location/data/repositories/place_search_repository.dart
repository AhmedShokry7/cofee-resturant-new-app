import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/features/location/data/model/place_suggestion.dart';

/// Look-up of places by free text, and of place names by coordinates.
///
/// The map tiles are already OpenStreetMap, so the geocoder is OpenStreetMap
/// too: no API key to ship, no billing, and the marker and the label always
/// describe the same data the map drew.
abstract class PlaceSearchRepository {
  /// Suggestions for a partial query, best match first. Empty when nothing
  /// matched — an empty list is an answer, not a failure.
  Future<List<PlaceSuggestion>> search(String query, {int limit = 8});

  /// The place at [latitude]/[longitude]. Null when OpenStreetMap has no name
  /// for that point.
  Future<PlaceSuggestion?> reverse({
    required double latitude,
    required double longitude,
  });
}

/// Raised when a lookup could not be completed. Callers show a message; they
/// must not present this as "no places found".
class PlaceSearchException implements Exception {
  const PlaceSearchException(this.cause);

  final Object? cause;

  @override
  String toString() => 'PlaceSearchException($cause)';
}

/// [PlaceSearchRepository] backed by the public Nominatim service.
///
/// Nominatim asks for at most one request per second and for a User-Agent that
/// identifies the app, so every call funnels through [_throttle] and identifies
/// itself in [http.Client] headers.
class NominatimPlaceSearchRepository implements PlaceSearchRepository {
  NominatimPlaceSearchRepository({
    http.Client? client,
    this.host = 'https://nominatim.openstreetmap.org',
    this.minimumInterval = const Duration(milliseconds: 1100),
    this.requestTimeout = const Duration(seconds: 12),
  }) : _client = client ?? http.Client();

  static const _searchPath = '/search';
  static const _reversePath = '/reverse';

  /// Zoom 18 is the most precise level Nominatim answers, which is what makes
  /// a tapped pin resolve to a building or street number rather than a city.
  static const _reverseZoom = 18;

  final http.Client _client;
  final String host;

  /// Gap between two requests. Nominatim's published limit is one per second;
  /// tests shorten it.
  final Duration minimumInterval;

  /// A stalled request must not outlive the screen that asked for it.
  final Duration requestTimeout;

  DateTime _lastRequestAt = DateTime.fromMillisecondsSinceEpoch(0);
  Future<void>? _queue;

  @override
  Future<List<PlaceSuggestion>> search(String query, {int limit = 8}) async {
    final q = query.trim();
    if (q.isEmpty) return const [];

    final body = await _get({
      'q': q,
      'format': 'jsonv2',
      'addressdetails': '1',
      'limit': '$limit',
    }, path: _searchPath);

    if (body is! List) return const [];
    return [
      for (final row in body)
        if (row is Map<String, dynamic>)
          PlaceSuggestion.fromJson(row),
    ].where((place) => place.hasUsableCoordinates).toList();
  }

  @override
  Future<PlaceSuggestion?> reverse({
    required double latitude,
    required double longitude,
  }) async {
    final body = await _get({
      'lat': '$latitude',
      'lon': '$longitude',
      'format': 'jsonv2',
      'addressdetails': '1',
      // The default zoom can fall back to a whole city, which would label every
      // tap in a neighbourhood the same.
      'zoom': '$_reverseZoom',
    }, path: _reversePath);

    if (body is! Map<String, dynamic>) return null;
    if (body['error'] != null) return null;
    final place = PlaceSuggestion.fromJson(body);
    return place.label.isEmpty ? null : place;
  }

  Future<Object?> _get(
    Map<String, String> query, {
    required String path,
  }) async {
    await _throttle();
    final uri = Uri.parse('$host$path').replace(queryParameters: {
      ...query,
      // Results come back in the app's language, so an Arabic UI never shows
      // Latin street names.
      'accept-language': AppLocale.instance.isArabic ? 'ar' : 'en',
    });

    try {
      // A stalled connection used to hang the caller forever — with no HTTP
      // timeout, `get` can outlive the screen that asked for it.
      final response = await _client
          .get(uri, headers: _headers)
          .timeout(requestTimeout);
      if (response.statusCode != 200) {
        throw PlaceSearchException('HTTP ${response.statusCode}');
      }
      try {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } on FormatException catch (error) {
        throw PlaceSearchException(error);
      }
    } on PlaceSearchException {
      rethrow;
    } on TimeoutException catch (error) {
      throw PlaceSearchException(error);
    } catch (error) {
      throw PlaceSearchException(error);
    }
  }

  /// Nominatim's published limit is one request per second. Calls are chained
  /// rather than delayed independently so a burst cannot fan out.
  Future<void> _throttle() {
    final pending = _queue ??= Future<void>.value();
    final next = pending.then((_) => _waitTurn());
    // The chain head is the future the guard compares against. Previously the
    // stored head was `next.whenComplete(...)` — a *different* Future object —
    // so `identical(_queue, next)` was never true and the completed tail was
    // retained for the whole lifetime of this repository, which is a
    // process-wide singleton.
    _queue = next;
    unawaited(
      next.whenComplete(() {
        if (identical(_queue, next)) _queue = null;
      }),
    );
    return next;
  }

  Future<void> _waitTurn() async {
    final wait = _lastRequestAt.add(minimumInterval).difference(DateTime.now());
    if (wait > Duration.zero) await Future<void>.delayed(wait);
    // Stamp at dispatch time. The rate limit is about request rate, so the
    // gap must be measured from when one request goes out to when the next
    // does — not from completion. Stamping at completion meant a slow request
    // measured as already-satisfied and the next went out immediately.
    _lastRequestAt = DateTime.now();
  }

  Map<String, String> get _headers {
    // The service asks callers to identify themselves. Browsers forbid setting
    // User-Agent, so the header is only sent where it is allowed.
    if (kIsWeb) return const {};
    return const {
      'User-Agent': 'NewCoffee/1.0 (Flutter; contact: support@newcoffee.app)',
      'Accept-Language': 'ar,en',
    };
  }
}