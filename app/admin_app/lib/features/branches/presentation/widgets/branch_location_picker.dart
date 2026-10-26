import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';

/// A simplified location picker for the admin: a map with a draggable pin
/// and a search field. Returns a `PickedLocation` with the point and label.
class AdminLocationPicker extends StatefulWidget {
  const AdminLocationPicker({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.initialAddress,
    this.onPicked,
    this.onAddressChanged,
  });

  final double? initialLatitude;
  final double? initialLongitude;
  final String? initialAddress;

  /// Called when the pin is moved or a suggestion is selected.
  final void Function(LatLng point, String? address)? onPicked;
  final ValueChanged<String>? onAddressChanged;

  @override
  State<AdminLocationPicker> createState() => _AdminLocationPickerState();
}

class _AdminLocationPickerState extends State<AdminLocationPicker> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  LatLng? _point;
  bool _isLocating = false;

  @override
  void initState() {
    super.initState();
    _addressController.text = widget.initialAddress ?? '';
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _point = LatLng(widget.initialLatitude!, widget.initialLongitude!);
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    _searchController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      final permission = await Geolocator.checkPermission();
      LocationPermission perm = permission;
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(S.locationPermissionDenied)));
        }
        setState(() => _isLocating = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 12),
        ),
      );
      if (!mounted) return;
      final point = LatLng(position.latitude, position.longitude);
      setState(() => _point = point);
      _mapController.move(point, 15);
      final address = await _reverseGeocode(point);
      if (!mounted) return;
      if (address != null && address.isNotEmpty) {
        _addressController.text = address;
      }
      widget.onPicked?.call(point, address);
      setState(() => _isLocating = false);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.couldNotGetLocation('$error'))),
        );
      }
      setState(() => _isLocating = false);
    }
  }

  Future<void> _onMapTap(TapPosition _, LatLng point) async {
    setState(() => _point = point);
    _mapController.move(point, 15);
    final address = await _reverseGeocode(point);
    if (!mounted || _point != point) return;
    if (address != null && address.isNotEmpty) {
      _addressController.text = address;
    }
    widget.onPicked?.call(point, address);
  }

  Future<String?> _reverseGeocode(LatLng point) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=${point.latitude}&lon=${point.longitude}&accept-language=ar',
      );
      final response = await http.get(
        url,
        headers: {'User-Agent': 'admin_app/1.0'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final address = data['display_name'] as String?;
        if (address != null && address.trim().isNotEmpty) {
          return address.trim();
        }
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final point = _point ?? const LatLng(24.7136, 46.6753);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _addressController,
                decoration: InputDecoration(
                  labelText: S.branchAddress,
                  hintText: S.enterAddressManually,
                ),
                onChanged: widget.onAddressChanged,
              ),
            ),
            const SizedBox(width: AppDimensions.sm),
            Material(
              color: AppColor.lightGreyColor,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _isLocating ? null : _useCurrentLocation,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: _isLocating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(
                          HugeIcons.strokeRoundedLocation01,
                          size: 20,
                          color: AppColor.primaryColor,
                        ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.md),
        SizedBox(
          height: 300,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: point,
                initialZoom: 13,
                onTap: _onMapTap,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.admin_app',
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
                          size: 36,
                          color: AppColor.primaryColor,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.sm),
        if (_point != null)
          Text(
            'Lat: ${_point!.latitude.toStringAsFixed(5)}, '
            'Lng: ${_point!.longitude.toStringAsFixed(5)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColor.greyColor,
            ),
          ),
      ],
    );
  }
}
