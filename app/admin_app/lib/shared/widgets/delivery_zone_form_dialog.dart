import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/models/admin_delivery_zone.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/shared/widgets/currency_icon.dart';

/// The form of a delivery zone: its names, its fees and its centre.
class DeliveryZoneFormDialog extends StatefulWidget {
  const DeliveryZoneFormDialog({
    super.key,
    this.initial,
    this.defaultLatitude,
    this.defaultLongitude,
    this.branchAddress,
  });

  /// When provided the dialog edits this zone instead of creating one.
  final AdminDeliveryZone? initial;
  final double? defaultLatitude;
  final double? defaultLongitude;
  final String? branchAddress;

  @override
  State<DeliveryZoneFormDialog> createState() => _DeliveryZoneFormDialogState();
}

class _DeliveryZoneFormDialogState extends State<DeliveryZoneFormDialog> {
  final MapController _mapController = MapController();
  late final TextEditingController _nameAr;
  late final TextEditingController _nameEn;
  late final TextEditingController _fee;
  late final TextEditingController _minOrder;
  late final TextEditingController _radius;
  late final TextEditingController _lat;
  late final TextEditingController _lng;
  late final TextEditingController _minutes;
  late final TextEditingController _feePerKm;
  late final TextEditingController _maxFee;
  late final TextEditingController _freeOver;
  late String _feeMethod;
  late bool _isActive;
  late bool _centerChosen;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    final zone = widget.initial;
    _nameAr = TextEditingController(text: zone?.nameAr ?? '');
    _nameEn = TextEditingController(text: zone?.nameEn ?? '');
    _fee = TextEditingController(text: zone?.deliveryFee.toString() ?? '');
    _minOrder = TextEditingController(
      text: zone?.minOrderAmount.toString() ?? '',
    );
    _radius = TextEditingController(text: zone?.radiusKm?.toString() ?? '20');
    _lat = TextEditingController(
      text:
          zone?.centerLatitude?.toString() ??
          widget.defaultLatitude?.toString() ??
          '',
    );
    _lng = TextEditingController(
      text:
          zone?.centerLongitude?.toString() ??
          widget.defaultLongitude?.toString() ??
          '',
    );
    _minutes = TextEditingController(
      text: zone?.estimatedMinutes?.toString() ?? '',
    );
    _feePerKm = TextEditingController(text: zone?.feePerKm?.toString() ?? '');
    _maxFee = TextEditingController(
      text: zone?.maxDeliveryFee?.toString() ?? '',
    );
    _freeOver = TextEditingController(
      text: zone?.freeDeliveryOver?.toString() ?? '',
    );
    _feeMethod = zone?.feeMethod ?? 'fixed';
    _isActive = zone?.isActive ?? true;
    _centerChosen =
        (zone?.centerLatitude != null && zone?.centerLongitude != null) ||
        (_branchCenter != null);
  }

  @override
  void dispose() {
    _mapController.dispose();
    for (final controller in [
      _nameAr,
      _nameEn,
      _fee,
      _minOrder,
      _radius,
      _lat,
      _lng,
      _minutes,
      _feePerKm,
      _maxFee,
      _freeOver,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  /// A money field: blank stays zero as the zone table stores it, but text
  /// that is not a number is refused instead of being written as a free
  /// delivery. The digits of either language are read.
  double? _amount(TextEditingController controller) {
    final text = controller.text.trim();
    if (text.isEmpty) return 0;
    return parseLocalizedNumber(text);
  }

  /// A number field, read in the digits of either language; blank is `null`.
  double? _number(TextEditingController controller) =>
      parseLocalizedNumber(controller.text);

  /// A whole-number field: a value the zone table stores as an integer count.
  int? _integer(TextEditingController controller) =>
      parseLocalizedInt(controller.text);

  void _accept() {
    final nameAr = _nameAr.text.trim();
    final nameEn = _nameEn.text.trim();
    final radius = _number(_radius);
    final latitude = _number(_lat);
    final longitude = _number(_lng);
    final deliveryFee = _amount(_fee);
    final minimumOrder = _amount(_minOrder);
    final estimatedMinutes = _integer(_minutes);
    final maxFee = _number(_maxFee);
    final freeOver = _number(_freeOver);
    if (nameAr.isEmpty ||
        !_centerChosen ||
        radius == null ||
        radius <= 0 ||
        latitude == null ||
        latitude < -90 ||
        latitude > 90 ||
        longitude == null ||
        longitude < -180 ||
        longitude > 180 ||
        deliveryFee == null ||
        deliveryFee < 0 ||
        minimumOrder == null ||
        minimumOrder < 0 ||
        (estimatedMinutes != null && estimatedMinutes <= 0) ||
        (maxFee != null && maxFee < 0) ||
        (freeOver != null && freeOver < 0)) {
      setState(() => _validationError = S.invalidDeliveryZoneFields);
      return;
    }
    final feePerKm = _number(_feePerKm);
    if (_feeMethod == 'per_km' && (feePerKm ?? 0) <= 0) {
      setState(() => _validationError = S.invalidPerKmFee);
      return;
    }
    setState(() => _validationError = null);
    Navigator.of(context).pop(
      AdminDeliveryZone(
        id: widget.initial?.id ?? '',
        nameAr: nameAr,
        nameEn: nameEn.isEmpty ? nameAr : nameEn,
        deliveryFee: deliveryFee,
        minOrderAmount: minimumOrder,
        radiusKm: radius,
        estimatedMinutes: estimatedMinutes,
        centerLatitude: latitude,
        centerLongitude: longitude,
        feeMethod: _feeMethod,
        feePerKm: feePerKm,
        maxDeliveryFee: maxFee,
        freeDeliveryOver: freeOver,
        isActive: _isActive,
      ),
    );
  }

  LatLng get _center =>
      LatLng(_number(_lat) ?? 24.7136, _number(_lng) ?? 46.6753);

  LatLng? get _branchCenter =>
      widget.defaultLatitude != null && widget.defaultLongitude != null
      ? LatLng(widget.defaultLatitude!, widget.defaultLongitude!)
      : null;

  List<LatLng> get _deliveryRadiusOutline {
    final radiusKm = parseLocalizedNumber(_radius.text) ?? 20;
    final distance = Distance();
    return List<LatLng>.generate(
      72,
      (index) => distance.offset(_center, radiusKm * 1000, index * 5),
      growable: false,
    );
  }

  void _pickCenter(LatLng point) {
    setState(() {
      _centerChosen = true;
      _lat.text = point.latitude.toStringAsFixed(6);
      _lng.text = point.longitude.toStringAsFixed(6);
    });
  }

  void _onCoordinateChanged(String _) {
    final latitude = parseLocalizedNumber(_lat.text);
    final longitude = parseLocalizedNumber(_lng.text);
    if (latitude == null ||
        longitude == null ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return;
    }
    setState(() => _centerChosen = true);
    _mapController.move(LatLng(latitude, longitude), 10);
  }

  Widget _row(List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(children: children),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool decimal = true,
    bool money = false,
    ValueChanged<String>? onChanged,
  }) {
    return Expanded(
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: money ? const CurrencyIcon(size: 10) : null,
        ),
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        onChanged: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? S.addZone : S.editZone),
      content: SizedBox(
        width: AppDimensions.dialogBodyWidthPanel,
        child: SingleChildScrollView(
          child: Column(
            children: [
              if ((widget.branchAddress ?? '').trim().isNotEmpty)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.storefront_outlined, size: 18),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          widget.branchAddress!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              if (_validationError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _validationError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ),
              _row([
                Expanded(
                  child: TextField(
                    controller: _nameAr,
                    decoration: InputDecoration(labelText: S.zoneNameArabic),
                    textDirection: TextDirection.rtl,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: TextField(
                    controller: _nameEn,
                    decoration: InputDecoration(labelText: S.zoneNameEnglish),
                  ),
                ),
              ]),
              _row([
                _field(_fee, S.deliveryFeeAmount, money: true),
                const SizedBox(width: AppSpacing.md),
                _field(_minOrder, S.minimumOrder, money: true),
              ]),
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: DropdownButtonFormField<String>(
                  initialValue: _feeMethod,
                  decoration: InputDecoration(labelText: S.deliveryFeeMethod),
                  items: [
                    DropdownMenuItem(
                      value: 'fixed',
                      child: Text(S.fixedDeliveryFee),
                    ),
                    DropdownMenuItem(
                      value: 'per_km',
                      child: Text(S.feePerKilometer),
                    ),
                    DropdownMenuItem(
                      value: 'free',
                      child: Text(S.freeDelivery),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _feeMethod = value);
                  },
                ),
              ),
              if (_feeMethod == 'per_km')
                Padding(
                  padding: EdgeInsets.only(bottom: AppSpacing.md),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(S.directDistanceFeeHint),
                  ),
                ),
              _row([
                _field(
                  _radius,
                  S.deliveryRadiusKm,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(width: AppSpacing.md),
                _field(_minutes, S.estimatedDeliveryMinutes, decimal: false),
              ]),
              _row([
                _field(_lat, S.centerLatitude, onChanged: _onCoordinateChanged),
                const SizedBox(width: AppSpacing.md),
                _field(
                  _lng,
                  S.centerLongitude,
                  onChanged: _onCoordinateChanged,
                ),
              ]),
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(S.zoneMapTapHint),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: SizedBox(
                  height: 280,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    child: FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _branchCenter ?? _center,
                        initialZoom: 10,
                        onTap: (_, point) => _pickCenter(point),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.admin_app',
                        ),
                        if (_centerChosen || _branchCenter != null)
                          PolygonLayer(
                            polygons: [
                              Polygon(
                                points: _deliveryRadiusOutline,
                                color: AppColor.mapRadiusSurface.withValues(
                                  alpha: 0.24,
                                ),
                                borderColor: AppColor.mapRadiusSurface,
                                borderStrokeWidth: 3,
                              ),
                            ],
                          ),
                        if (_centerChosen)
                          MarkerLayer(
                            markers: [
                              if (_branchCenter != null)
                                Marker(
                                  point: _branchCenter!,
                                  width: 38,
                                  height: 38,
                                  child: const Icon(
                                    Icons.storefront,
                                    color: AppColor.mapBranchPin,
                                    size: 30,
                                  ),
                                ),
                              Marker(
                                point: _center,
                                width: 36,
                                height: 36,
                                child: const Icon(
                                  Icons.location_on,
                                  color: AppColor.mapZonePin,
                                  size: 34,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              _row([
                _field(_feePerKm, S.feePerKilometer, money: true),
                const SizedBox(width: AppSpacing.md),
                _field(_maxFee, S.maxDeliveryFee, money: true),
              ]),
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Row(
                  children: [_field(_freeOver, S.freeDeliveryMinimum)],
                ),
              ),
              Row(
                children: [
                  Text(S.active),
                  const SizedBox(width: AppSpacing.md),
                  Switch(
                    value: _isActive,
                    onChanged: (value) => setState(() => _isActive = value),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(S.cancel),
        ),
        FilledButton(onPressed: _accept, child: Text(S.save)),
      ],
    );
  }
}
