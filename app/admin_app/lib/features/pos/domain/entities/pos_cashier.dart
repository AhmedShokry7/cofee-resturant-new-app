import 'package:admin_app/features/pos/domain/entities/pos_json.dart';

/// A staff member the counter drawer can be opened for.
class PosCashier {
  const PosCashier({
    required this.id,
    required this.fullName,
    this.isSelf = false,
  });

  final String id;
  final String fullName;

  /// The row of the signed-in admin, so the form can offer "yourself" without
  /// repeating a name the cashier already knows.
  final bool isSelf;

  factory PosCashier.fromJson(Map<String, dynamic> json) => PosCashier(
    id: posText(json['id']),
    fullName: posText(json['full_name']),
    isSelf: posFlag(json['is_self']),
  );
}
