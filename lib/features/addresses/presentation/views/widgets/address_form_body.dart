import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/addresses/data/model/address_model.dart';
import 'package:new_coffee/features/location/data/model/location_failure.dart';
import 'package:new_coffee/features/location/data/repositories/place_search_repository.dart';
import 'package:new_coffee/features/location/presentation/widgets/location_picker.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';
import 'package:new_coffee/shared/widgets/custom_text_form_field.dart';
import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/theme/tokens.dart';

/// The address editor: a label, a pin or a typed place, and the rules that
/// decide whether the result may be saved.
///
/// The address book and the checkout flow used to carry two copies of this
/// form, so every rule written here had to be written twice — including the
/// guard below that rejects a coordinate-only label.
class AddressFormBody extends StatefulWidget {
  const AddressFormBody({super.key, this.address, required this.onSave});

  /// The saved address being edited, null when adding a new one.
  final AddressModel? address;

  /// Called with what the customer confirmed, once it passed the checks.
  ///
  /// [AddressModel.id] is empty for a new address: the server assigns the real
  /// one, and both callers read it back from the repository result.
  ///
  /// The handler answers `null` once the server has the row, or the sentence to
  /// show when it has not. The editor waits for that before closing: a screen
  /// that popped on the tap used to report an address the customer never got.
  final Future<String?> Function(AddressModel draft) onSave;

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

  /// The save is on its way, so the button cannot be tapped into a second row
  /// on the server.
  bool _isSaving = false;

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
      final places = await context.read<PlaceSearchRepository>().search(
        typed,
        limit: 1,
      );
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

  void _warn(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

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

    // The write is awaited before this screen closes: a refused save keeps the
    // draft on screen with the reason, instead of a list that never shows the
    // address the customer just typed.
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isSaving = true);
    final failure = await widget.onSave(draft);
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (failure != null) {
      messenger.showSnackBar(SnackBar(content: Text(failure)));
      return;
    }
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: CustomTextFormField(
              controller: _nameController,
              hint: S.addressNameHint,
              icon: AppIcons.location,
              textInputAction: TextInputAction.next,
              bottomPadding: AppSpacing.sm,
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: LocationPicker(
                repository: context.read<PlaceSearchRepository>(),
                controller: _searchController,
                initialPoint: _picked?.point,
                onPicked: (location) => setState(() => _picked = location),
                // The picker keeps its own caption, but the customer is looking
                // at this form: a position that could not be had has to say so
                // here rather than leave the pin silently still.
                onLocationFailure: (failure) => _warn(failure.userMessage),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: CustomBtn(
              text: S.confirm,
              isLoading: _isSaving,
              onPressed: _isSaving ? null : _confirm,
            ),
          ),
        ],
      ),
    );
  }
}
