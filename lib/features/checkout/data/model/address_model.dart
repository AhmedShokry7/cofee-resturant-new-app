import 'package:new_coffee/core/data/db_values.dart';

class AddressModel {
  const AddressModel({
    required this.id,
    required this.label,
    required this.details,
    this.latitude,
    this.longitude,
    this.isDefault = false,
  });

  final String id;
  final String label;
  final String details;
  final double? latitude;
  final double? longitude;
  final bool isDefault;

  factory AddressModel.fromDatabase(Map<String, dynamic> json) {
    final map = Db.asMap(json);
    return AddressModel(
      id: Db.text(map['id']),
      label: Db.text(map['label']),
      details: Db.text(map['details']),
      latitude: Db.asDoubleOrNull(map['latitude']),
      longitude: Db.asDoubleOrNull(map['longitude']),
      isDefault: Db.asBool(map['is_default']),
    );
  }
}
