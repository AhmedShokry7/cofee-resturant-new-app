import 'package:latlong2/latlong.dart';

/// One place returned by a geocoding lookup.
///
/// Nominatim answers with a single `display_name` ("Grand Central Terminal, Mid
/// Town, New York, ..."). That string is useful but reads badly in a two-line
/// suggestion row, so it is split once here into [title] (the place itself) and
/// [subtitle] (where it is). [label] keeps the untouched full name because that
/// is what belongs in the search field.
class PlaceSuggestion {
  const PlaceSuggestion({
    required this.label,
    required this.title,
    required this.subtitle,
    required this.latitude,
    required this.longitude,
    this.category,
  });

  /// Full display name, e.g. `New York, New York, United States`.
  final String label;

  /// Just the place, e.g. `New York`. Never empty when [label] is not.
  final String title;

  /// Everything after the title, e.g. `New York, United States`.
  final String subtitle;

  final double latitude;
  final double longitude;

  /// OSM `class`/`type` pair, e.g. `place/city`. Used only for the icon.
  final String? category;

  LatLng get latLng => LatLng(latitude, longitude);

  /// Builds a suggestion from a Nominatim result.
  ///
  /// Tolerates the two shapes the API returns: the array used by `/search` and
  /// the single object used by `/reverse`.
  factory PlaceSuggestion.fromJson(Map<String, dynamic> json) {
    final label = _text(json['display_name']);
    final parts = label
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    final title = parts.isEmpty ? label : parts.first;
    final subtitle = parts.length > 1 ? parts.skip(1).join(', ') : '';
    final type = _text(json['type']);
    final class_ = _text(json['class']);
    return PlaceSuggestion(
      label: label,
      title: title,
      subtitle: subtitle,
      latitude: _coordinate(json['lat']),
      longitude: _coordinate(json['lon']),
      category: type.isEmpty ? null : (class_.isEmpty ? type : '$class_/$type'),
    );
  }

  static String _text(Object? value) => value?.toString().trim() ?? '';

  /// Nominatim returns coordinates as strings; a malformed pair becomes 0,0 and
  /// the caller drops the result rather than placing a marker in the Atlantic.
  static double _coordinate(Object? value) =>
      double.tryParse(_text(value)) ?? 0.0;

  /// A 0,0 pin is never a real answer, it is a parse failure.
  bool get hasUsableCoordinates => latitude != 0 || longitude != 0;
}
