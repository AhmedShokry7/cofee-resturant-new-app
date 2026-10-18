import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:latlong2/latlong.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/location/data/model/location_failure.dart';
import 'package:new_coffee/features/location/data/model/place_suggestion.dart';
import 'package:new_coffee/features/location/data/repositories/place_search_repository.dart';
import 'package:new_coffee/shared/widgets/custom_text_form_field.dart';

/// A picked location: the pin, and the place name it resolves to.
class PickedLocation {
  const PickedLocation(this.point, this.label);

  final LatLng point;
  final String label;
}

/// Search field + pin map for choosing where an order is delivered.
///
/// One widget, used by both the profile address form and the checkout address
/// form, so the two cannot drift apart again.
///
/// Behaviour worth knowing:
/// * typing lists matching places, Google-Maps style, debounced so a burst of
///   keystrokes costs one request;
/// * tapping the map or taking the device position fills the field with the
///   *place name*, not coordinates, via reverse geocoding — so the label and the
///   pin can never disagree;
/// * when reverse geocoding fails the field is left alone and the reason is
///   reported. It used to be filled with "24.71360, 46.67530", which was then
///   saved as the customer's address with no error anywhere;
/// * [onPicked] fires for every kind of pick: tapping a suggestion, tapping the
///   map, or taking the device position. A pin alone is a complete answer, so a
///   form must validate against this and must not additionally require the text
///   field to be non-empty.
class LocationPicker extends StatefulWidget {
  const LocationPicker({
    super.key,
    required this.repository,
    required this.controller,
    required this.onPicked,
    this.onLocationFailure,
    this.initialPoint,
    this.initialZoom = 14,
  });

  final PlaceSearchRepository repository;

  /// Owns the search field, so the hosting form can read what the customer
  /// typed and resolve it when they confirm without tapping a suggestion.
  final TextEditingController controller;

  /// Called on every deliberate pick: tapping a suggestion, tapping the map, or
  /// taking the device position. Centring the map on the device position does
  /// not count as one — the customer has to confirm a pin.
  final void Function(PickedLocation location) onPicked;

  /// Reported when the customer asks for their position and it cannot be had.
  ///
  /// Separate from the widget's own caption so the hosting form can explain it
  /// where the customer is actually looking.
  final void Function(LocationFailure failure)? onLocationFailure;

  /// Where the map opens and the pin starts. When null the widget opens on the
  /// device position, so an edited address never opens at an unrelated city.
  final LatLng? initialPoint;

  final double initialZoom;

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  /// Long enough to skip intermediate keystrokes, short enough that
  /// suggestions feel immediate.
  static const _debounce = Duration(milliseconds: 350);

  /// Below this the query has not settled yet; asking the geocoder would spend a
  /// rate-limited request and return nothing useful.
  static const _minQueryLength = 2;

  static const _searchZoom = 16.0;
  static const _tapZoom = 17.0;
  static const _maxSuggestions = 8;

  /// Bounded wait for a position fix. `high`/GPS indoors never answers, and
  /// with no limit the caller hung forever.
  static const _positionTimeout = Duration(seconds: 12);

  /// Zoomed-out fallback for "the device would not say where it is". A world
  /// view is honest; a zoomed pin on some default city is not, and a spinner
  /// that never resolves would leave the customer with no map at all.
  static const _unknownLocationZoom = 2.0;
  static const _unknownLocationCenter = LatLng(20.0, 0.0);

  final MapController _mapController = MapController();
  final _searchFocus = FocusNode();

  TextEditingController get _searchController => widget.controller;

  Timer? _debounceTimer;

  /// Guards against an older, slower response overwriting a newer one.
  int _searchGeneration = 0;

  List<PlaceSuggestion> _suggestions = const [];
  bool _isSearching = false;
  bool _isResolving = false;

  /// A position request is in flight. Guards the button so a second tap cannot
  /// start a competing acquisition.
  bool _isLocating = false;

  /// Monotonic id of the newest position request. A fix that resolves after a
  /// newer one started is discarded instead of overwriting it.
  int _positionGeneration = 0;

  /// Why the last position attempt failed. Null until one does.
  LocationFailure? _locationFailure;

  /// The customer's pin. Null until they pick one, which is what lets a form
  /// insist on a deliberate choice.
  LatLng? _point;

  /// Where the map is centred before any pick: the edited address, or the
  /// device position resolved on open.
  LatLng? _devicePoint;

  bool get _showSuggestions =>
      _searchFocus.hasFocus &&
      _suggestions.isNotEmpty &&
      _searchController.text.trim().length >= _minQueryLength;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialPoint;
    if (initial != null) {
      _point = initial;
      _devicePoint = initial;
    } else {
      _openOnDevicePosition();
    }
    _searchFocus.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchFocus
      ..removeListener(_onFocusChanged)
      ..dispose();
    _mapController.dispose();
    super.dispose();
  }

  /// Opens a brand-new address on the customer instead of on a fixed city, and
  /// fails softly: if the device will not say where it is, the map stays on the
  /// world view and waits for a tap or a search.
  ///
  /// The permission prompt is deliberately NOT requested here. Asking from
  /// `initState`, before the customer has touched anything, pops a system
  /// dialog unprompted — which is a Play Store policy problem, and races with
  /// the tap on "use my current location": if they deny the unprompted one, the
  /// prompt they then want is already in the denied state.
  Future<void> _openOnDevicePosition() async {
    // A cheap cached fix only, so the map opens somewhere sensible without a
    // permission prompt or a cold GPS acquisition.
    final position = await _lastKnownPosition();
    if (!mounted || position == null) return;
    _applyDevicePoint(position);
  }

  void _applyDevicePoint(Position position) {
    setState(() => _devicePoint = LatLng(position.latitude, position.longitude));
    // `initialCenter` is only read on the map's first build, which may already
    // have happened at the world view, so the camera has to be moved
    // explicitly. Deferred to the next frame so the controller is attached.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _point == null) {
        _mapController.move(_devicePoint!, widget.initialZoom);
      }
    });
  }

  // ---------------------------------------------------------------- search

  void _onFocusChanged() {
    // `FocusNode.hasFocus` does not schedule a build on its own.
    if (mounted) setState(() {});
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    final query = _searchController.text.trim();
    if (query.length < _minQueryLength) {
      setState(() {
        _suggestions = const [];
        _isSearching = false;
      });
      return;
    }
    setState(() {});
    _debounceTimer = Timer(_debounce, () => _runSearch(query));
  }

  Future<void> _runSearch(String query) async {
    final generation = ++_searchGeneration;
    setState(() => _isSearching = true);
    try {
      final results = await widget.repository.search(
        query,
        limit: _maxSuggestions,
      );
      // The customer kept typing, or cleared the field, while this was in
      // flight: the answer no longer describes what is on screen.
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _suggestions = results;
        _isSearching = false;
      });
    } on PlaceSearchException {
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _suggestions = const [];
        _isSearching = false;
      });
    }
  }

  void _selectSuggestion(PlaceSuggestion place) {
    _setSearchText(place.label);
    setState(() {
      _suggestions = const [];
      _isSearching = false;
    });
    _searchFocus.unfocus();
    _pin(place.latLng, place.label, zoom: _searchZoom);
  }

  void _clearSearch() {
    _debounceTimer?.cancel();
    _searchController.clear();
    setState(() {
      _suggestions = const [];
      _isSearching = false;
    });
  }

  /// Writes the field without re-triggering the search that produced the text.
  void _setSearchText(String value) {
    _debounceTimer?.cancel();
    _searchController.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  // ------------------------------------------------------------------ picks

  void _pin(LatLng point, String label, {required double zoom}) {
    setState(() => _point = point);
    widget.onPicked(PickedLocation(point, label));
    _mapController.move(point, zoom);
  }

  void _movePin(LatLng point, {required double zoom}) {
    setState(() => _point = point);
    _mapController.move(point, zoom);
  }

  Future<void> _onMapTap(TapPosition _, LatLng point) async {
    // A deliberate pin supersedes anything a position request was going to
    // produce, so an in-flight fix cannot jump the map afterwards.
    _positionGeneration++;
    _movePin(point, zoom: _tapZoom);
    final label = await _resolveLabel(point);
    // A newer tap, or a pick from search, landed while this was in flight.
    if (!mounted || _point != point) return;
    if (label != null) {
      _setSearchText(label);
      setState(() {});
      widget.onPicked(PickedLocation(point, label));
    } else {
      // The pin is a complete answer on its own; only its name is missing.
      widget.onLocationFailure?.call(LocationFailure.unavailable);
    }
  }

  /// Turns a pin into the name of the place under it.
  ///
  /// An unnamed point is legitimate — OpenStreetMap is not complete — so it
  /// Fills in the address under the device position.
  ///
  /// Guarded against re-entry: a second tap while the first fix is in flight
  /// used to start a second acquisition, and because cold fixes are slower than
  /// warm ones the two resolve out of order — so the *older*, stale fix would
  /// land last and win.
  Future<void> _useCurrentLocation() async {
    if (_isLocating) return;
    setState(() {
      _isLocating = true;
      _locationFailure = null;
    });
    final generation = ++_positionGeneration;

    final result = await _devicePosition();
    if (!mounted) return;
    // A newer request, or a pick from the map or the search list, superseded
    // this one. Dropping it here is what stops a slow earlier fix from
    // overwriting a fast later one.
    if (generation != _positionGeneration || _point != null) {
      setState(() => _isLocating = false);
      return;
    }
    if (result.position == null) {
      setState(() {
        _isLocating = false;
        _locationFailure = result.failure ?? LocationFailure.unavailable;
      });
      widget.onLocationFailure?.call(_locationFailure!);
      return;
    }

    final point = LatLng(
      result.position!.latitude,
      result.position!.longitude,
    );
    _movePin(point, zoom: _searchZoom);
    final label = await _resolveLabel(point);
    if (!mounted || generation != _positionGeneration || _point != point) return;
    setState(() => _isLocating = false);
    if (label != null) {
      _setSearchText(label);
      widget.onPicked(PickedLocation(point, label));
    } else {
      // The pin is right; only its name is unknown. Reported rather than
      // invented, because the invented version — a coordinate string — was
      // being saved as the customer's address.
      widget.onLocationFailure?.call(LocationFailure.unavailable);
    }
  }

  /// Turns a pin into the place name under it.
  ///
  /// Returns null when the name could not be established, and never a
  /// coordinate string: "24.71360, 46.67530" looks like an address to the saving
  /// code and gets written to `customer_addresses.details` as one.
  Future<String?> _resolveLabel(LatLng point) async {
    setState(() => _isResolving = true);
    String? label;
    try {
      final place = await widget.repository.reverse(
        latitude: point.latitude,
        longitude: point.longitude,
      );
      // Null here means OpenStreetMap genuinely has no name for this point,
      // which is a different answer from "the request failed".
      label = place?.label;
    } on PlaceSearchException catch (error) {
      debugPrint('Reverse geocoding failed: $error');
      label = null;
    }
    if (mounted) setState(() => _isResolving = false);
    return (label == null || label.trim().isEmpty) ? null : label;
  }

  static String _coordinates(LatLng point) =>
      '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';

  Future<Position?> _lastKnownPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      if (!await _hasPermission()) return null;
      return await Geolocator.getLastKnownPosition();
    } catch (_) {
      return null;
    }
  }

  Future<bool> _hasPermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  Future<({Position? position, LocationFailure? failure})> _devicePosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return (position: null, failure: LocationFailure.servicesDisabled);
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return (
          position: null,
          failure: LocationFailure.permissionPermanentlyDenied,
        );
      }
      if (permission == LocationPermission.denied) {
        return (position: null, failure: LocationFailure.permissionDenied);
      }

      // A cached fix first so the pin appears immediately, then refine.
      final last = await _lastKnownPosition();
      final fresh = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          // `medium`, not `high`. `high` maps to PRIORITY_HIGH_ACCURACY, which
          // means GPS, and a cold GPS fix indoors routinely never arrives —
          // with no timeLimit that call simply hung forever and the row looked
          // completely inert, with no spinner and no error. `medium` is a
          // network/WiFi-assisted fix, which is what address picking wants and
          // what the weather feature in this app already uses.
          accuracy: LocationAccuracy.medium,
          // Without this the platform future is never wrapped in a timeout, so
          // "hangs forever" was unbounded rather than merely slow.
          timeLimit: _positionTimeout,
        ),
      );
      // Prefer the fresh fix, but keep the cached one if the fresh one somehow
      // has nothing — never return null just because the refine step stalled.
      return (position: fresh ?? last, failure: null);
    } on TimeoutException {
      final last = await _lastKnownPosition();
      if (last != null) return (position: last, failure: null);
      return (position: null, failure: LocationFailure.timeout);
    } catch (error) {
      debugPrint('Device position failed: $error');
      final last = await _lastKnownPosition();
      if (last != null) return (position: last, failure: null);
      return (position: null, failure: LocationFailure.unavailable);
    }
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CustomTextFormField(
          controller: _searchController,
          focusNode: _searchFocus,
          hint: S.searchLocation,
          prefixIcon: const Icon(
            HugeIcons.strokeRoundedSearch01,
            color: AppColor.greyColor,
          ),
          // A picked place is a complete answer; the map below stays usable
          // for fine-tuning.
          textInputAction: TextInputAction.search,
          bottomPadding: 8,
          onChanged: (_) => _onSearchChanged(),
          suffixIcon: _searchSuffix(),
        ),
        _useCurrentLocationRow(),
        if (_locationFailure != null)
          Padding(
            padding: EdgeInsets.only(bottom: SpacingTokens.sm.h),
            child: Text(
              S.locationFailed(_locationFailure!),
              style: AppFonts.regular12(context).copyWith(
                color: AppColor.greyColor,
              ),
            ),
          ),
        if (widget.onLocationFailure != null &&
            _locationFailure == LocationFailure.permissionPermanentlyDenied)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: GestureDetector(
              onTap: Geolocator.openAppSettings,
              child: Text(
                S.openSettings,
                style: AppFonts.medium12(context).copyWith(
                  color: AppColor.primaryColor,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        const Divider(height: 1),
        SizedBox(height: SpacingTokens.sm.h),
        Expanded(child: _mapSlot()),
      ],
    );
  }

  Widget? _searchSuffix() {
    if (_isSearching) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_searchController.text.isEmpty) return null;
    return IconButton(
      onPressed: _clearSearch,
      icon: Icon(
        HugeIcons.strokeRoundedCancel01,
        size: 20.r,
        color: AppColor.greyColor,
      ),
    );
  }

  Widget _useCurrentLocationRow() => GestureDetector(
    onTap: _useCurrentLocation,
    behavior: HitTestBehavior.opaque,
    child: Padding(
      padding: EdgeInsets.symmetric(vertical: SpacingTokens.xs.h),
      child: Row(
        children: [
          Icon(
            HugeIcons.strokeRoundedLocation01,
            size: 24.w,
            color: AppColor.primaryColor,
          ),
          SizedBox(width: SpacingTokens.sm.w),
          Expanded(
            child: Text(S.useCurrentLocation, style: AppFonts.medium16(context)),
          ),
          // Bound to the acquisition, not to the reverse-geocode. It used to
          // hang off `_isResolving`, so while the position itself was still
          // being fetched — the part that could take seconds or never answer —
          // the row showed nothing at all and looked dead.
          if (_isLocating || _isResolving)
            const SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    ),
  );

  Widget _mapSlot() {
    final known = _point ?? _devicePoint;
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: known ?? _unknownLocationCenter,
            initialZoom: known == null ? _unknownLocationZoom : widget.initialZoom,
            onTap: _onMapTap,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.new_cofee',
              tileProvider: NetworkTileProvider(
                cachingProvider: DisabledMapCachingProvider(),
              ),
            ),
            if (_point != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: _point!,
                    width: 40,
                    height: 40,
                    child: Icon(
                      HugeIcons.strokeRoundedLocation01,
                      size: 36.w,
                      color: AppColor.primaryColor,
                    ),
                  ),
                ],
              ),
          ],
        ),
        if (_showSuggestions)
          Positioned(top: 0, left: 0, right: 0, child: _suggestionList()),
      ],
    );
  }

  Widget _suggestionList() => Container(
    constraints: const BoxConstraints(maxHeight: 220),
    margin: EdgeInsets.symmetric(horizontal: SpacingTokens.md.w),
    decoration: BoxDecoration(
      color: AppColor.whiteColor,
      borderRadius: BorderRadius.circular(16.r),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.12),
          blurRadius: 16.r,
          offset: Offset(0, 4.h),
        ),
      ],
    ),
    clipBehavior: Clip.antiAlias,
    child: ListView.separated(
      shrinkWrap: true,
      padding: EdgeInsets.symmetric(vertical: SpacingTokens.xs.h),
      itemCount: _suggestions.length,
      separatorBuilder: (_, _) => Divider(
        height: 1,
        indent: 52.w,
        color: AppColor.borderColor,
      ),
      itemBuilder: (context, index) =>
          _suggestionRow(_suggestions[index]),
    ),
  );

  Widget _suggestionRow(PlaceSuggestion place) => InkWell(
    onTap: () => _selectSuggestion(place),
    child: Padding(
      padding: EdgeInsets.symmetric(
        horizontal: SpacingTokens.md.w,
        vertical: SpacingTokens.sm.h,
      ),
      child: Row(
        children: [
          Icon(
            HugeIcons.strokeRoundedSearch01,
            size: 20.w,
            color: AppColor.greyColor,
          ),
          SizedBox(width: SpacingTokens.md.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  place.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.medium14(context),
                ),
                if (place.subtitle.isNotEmpty)
                  Text(
                    place.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.regular12(context).copyWith(
                      color: AppColor.greyColor,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}