import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:latlong2/latlong.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/features/addresses/data/model/address_model.dart';
import 'package:new_coffee/features/location/data/repositories/place_search_repository.dart';
import 'package:new_coffee/features/location/presentation/widgets/location_picker.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';
import 'package:new_coffee/shared/widgets/custom_text_form_field.dart';

/// The address editor: a label, a pin or a typed place, and the rules that
/// decide whether the result may be saved.
///
/// The address book and the checkout flow used to carry two copies of this
/// form, so every rule written here had to be written twice — including the
/// guard below that rejects a coordinate-only label.
class AddressFormBody extends StatefulWidget {
  const AddressFormBody({
    super.key,
    this.address,
    required this.onSave,
  });

  /// The saved address being edited, null when adding a new one.
  final AddressModel? address;

  /// Called with what the customer confirmed, once it passed the checks.
  ///
  /// [AddressModel.id] is empty for a new address: the server assigns the real
  /// one, and both callers read it back from the repository result.
  final ValueChanged<AddressModel> onSave;

  @override
  State<AddressFormBody> createState() => _AddressFormBodyState();
}

class _AddressFormBodyState extends State<AddressFormBody> {
  final _nameController = TextEditingController();

  /// Owned here rather than inside the picker so confirming can read it: a
  /// customer who types a place name and confirms without tapping a suggestion
  /// must still get real coordinates.
  final _searchController = TextEditingController();

  /// Null until the customer picks a spot.
  PickedLocation? _picked;

  @override
  void initState() {
    super.initState();
    final address = widget.address;
    if (address != null) {
      _nameController.text = address.label;
      _searchController.text = address.details;
      if (address.latitude != null && address.longitude != null) {
        _picked = PickedLocation(
          LatLng(address.latitude!, address.longitude!),
          address.details,
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Turns what is on screen into a location.
  ///
  /// A pin is already a complete answer, so it is preferred. Free text is only
  /// resolved when there is no pin — or when the customer edited the text after
  /// picking — and a name the geocoder does not recognise falls back to the pin
  /// rather than discarding a deliberate choice.
  Future<PickedLocation?> _resolveLocation() async {
    final typed = _searchController.text.trim();
    final picked = _picked;
    if (typed.isEmpty) return picked;
    if (picked != null && typed == picked.label) return picked;

    try {
      final places = await context
          .read<PlaceSearchRepository>()
          .search(typed, limit: 1);
      if (!mounted || places.isEmpty) return picked;
      final resolved = PickedLocation(places.first.latLng, places.first.label);
      setState(() => _picked = resolved);
      return resolved;
    } on PlaceSearchException {
      return picked;
    }
  }

  /// A reverse-geocoded label that is only numbers is not an address.
  ///
  /// OpenStreetMap answers with `"24.71360, 46.67530"` when it has no name for
  /// a point, and that string used to be saved as the customer's `details` with
  /// no error anywhere — an address that is literally coordinates. Anything
  /// numeric-looking is rejected here so it cannot be persisted.
  static bool _looksLikeCoordinates(String value) {
    final compact = value.replaceAll(RegExp(r'[\s.,-]'), '');
    return compact.isNotEmpty && RegExp(r'^\d+$').hasMatch(compact);
  }

  void _warn(String message) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );

  Future<void> _confirm() async {
    final label = _nameController.text.trim();
    if (label.isEmpty) {
      _warn(S.addAddressName);
      return;
    }
    final picked = await _resolveLocation();
    if (!mounted) return;
    if (picked == null) {
      _warn(S.addAddressLocation);
      return;
    }
    if (_looksLikeCoordinates(picked.label)) {
      _warn(S.locationUnavailable);
      return;
    }

    final existing = widget.address;
    final draft = existing == null
        ? AddressModel(
            id: '',
            label: label,
            details: picked.label,
            latitude: picked.point.latitude,
            longitude: picked.point.longitude,
          )
        : existing.copyWith(
            label: label,
            details: picked.label,
            latitude: picked.point.latitude,
            longitude: picked.point.longitude,
          );

    widget.onSave(draft);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              SpacingTokens.lg.w,
              SpacingTokens.md.h,
              SpacingTokens.lg.w,
              SpacingTokens.sm.h,
            ),
            child: CustomTextFormField(
              controller: _nameController,
              hint: S.addressNameHint,
              textInputAction: TextInputAction.next,
              bottomPadding: 8,
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: SpacingTokens.lg.w),
              child: LocationPicker(
                repository: context.read<PlaceSearchRepository>(),
                controller: _searchController,
                initialPoint: _picked?.point,
                onPicked: (location) => setState(() => _picked = location),
                onLocationFailure: (_) {},
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              SpacingTokens.lg.w,
              SpacingTokens.sm.h,
              SpacingTokens.lg.w,
              SpacingTokens.md.h,
            ),
            child: CustomBtn(text: S.confirm, onPressed: _confirm),
          ),
        ],
      ),
    );
  }
}
