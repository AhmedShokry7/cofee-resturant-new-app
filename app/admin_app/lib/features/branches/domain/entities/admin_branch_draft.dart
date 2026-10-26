import 'package:admin_app/core/models/admin_branch.dart';

/// The editable fields of a branch, sent to `admin_save_branch`.
class AdminBranchDraft {
  const AdminBranchDraft({
    this.id,
    required this.code,
    required this.nameAr,
    required this.nameEn,
    required this.address,
    this.latitude,
    this.longitude,
    this.phone,
    this.legalName,
    this.vatNumber,
    this.opensAt,
    this.closesAt,
  });

  final String? id;
  final String code;
  final String nameAr;
  final String nameEn;
  final String address;
  final double? latitude;
  final double? longitude;
  final String? phone;

  /// Seller identity for the ZATCA simplified tax invoice.
  final String? legalName;
  final String? vatNumber;
  final String? opensAt;
  final String? closesAt;

  factory AdminBranchDraft.fromBranch(AdminBranch branch) {
    return AdminBranchDraft(
      id: branch.id,
      code: branch.code,
      nameAr: branch.nameAr,
      nameEn: branch.nameEn,
      address: branch.address,
      latitude: branch.latitude,
      longitude: branch.longitude,
      phone: branch.phone,
      legalName: branch.legalName,
      vatNumber: branch.vatNumber,
      opensAt: branch.opensAt,
      closesAt: branch.closesAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    if (id != null) 'id': id,
    'code': code,
    'name_ar': nameAr,
    'name_en': nameEn,
    'address': address,
    'latitude': latitude,
    'longitude': longitude,
    'phone': phone,
    'legal_name': legalName,
    'vat_number': vatNumber,
    'opens_at': opensAt,
    'closes_at': closesAt,
  };
}
