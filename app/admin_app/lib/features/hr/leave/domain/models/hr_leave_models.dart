class HrLeaveType {
  const HrLeaveType({
    required this.id,
    required this.code,
    required this.nameAr,
    required this.nameEn,
    this.requiresDocument = false,
    this.isPaid = true,
    this.tracksBalance = false,
    this.defaultAnnualDays,
    this.isActive = true,
  });

  final String id;
  final String code;
  final String nameAr;
  final String nameEn;
  final bool requiresDocument;
  final bool isPaid;
  final bool tracksBalance;
  final double? defaultAnnualDays;
  final bool isActive;

  String label(bool arabic) => arabic ? nameAr : nameEn;

  factory HrLeaveType.fromJson(Map<String, dynamic> json) => HrLeaveType(
    id: '${json['id'] ?? ''}',
    code: '${json['code'] ?? ''}',
    nameAr: '${json['name_ar'] ?? ''}',
    nameEn: '${json['name_en'] ?? ''}',
    requiresDocument: json['requires_document'] == true,
    isPaid: json['is_paid'] != false,
    tracksBalance: json['tracks_balance'] == true,
    defaultAnnualDays: _number(json['default_annual_days'])?.toDouble(),
    isActive: json['is_active'] != false,
  );
}

class HrLeaveRequest {
  const HrLeaveRequest({
    required this.id,
    required this.staffId,
    required this.staffName,
    required this.leaveTypeId,
    required this.typeNameAr,
    required this.typeNameEn,
    required this.startsOn,
    required this.endsOn,
    required this.days,
    required this.status,
    this.reason = '',
    this.supportingDocument,
    this.reviewNote,
    this.requestedByName,
    this.reviewedByName,
    this.createdAtLocal,
    this.reviewedAtLocal,
    this.isPaid = true,
    this.tracksBalance = false,
    this.balance,
  });

  final String id;
  final String staffId;
  final String staffName;
  final String leaveTypeId;
  final String typeNameAr;
  final String typeNameEn;
  final DateTime startsOn;
  final DateTime endsOn;
  final int days;
  final String status;
  final String reason;
  final String? supportingDocument;
  final String? reviewNote;
  final String? requestedByName;
  final String? reviewedByName;
  final String? createdAtLocal;
  final String? reviewedAtLocal;
  final bool isPaid;
  final bool tracksBalance;
  final Map<String, dynamic>? balance;

  String typeName(bool arabic) => arabic ? typeNameAr : typeNameEn;

  factory HrLeaveRequest.fromJson(Map<String, dynamic> json) {
    final balance = json['balance'];
    return HrLeaveRequest(
      id: '${json['id'] ?? ''}',
      staffId: '${json['staff_id'] ?? ''}',
      staffName: '${json['staff_name'] ?? ''}',
      leaveTypeId: '${json['leave_type_id'] ?? ''}',
      typeNameAr: '${json['type_name_ar'] ?? ''}',
      typeNameEn: '${json['type_name_en'] ?? ''}',
      startsOn: _date(json['starts_on']),
      endsOn: _date(json['ends_on']),
      days: _number(json['days'])?.toInt() ?? 0,
      status: '${json['status'] ?? 'pending'}',
      reason: '${json['reason'] ?? ''}',
      supportingDocument: _optionalText(json['supporting_document']),
      reviewNote: _optionalText(json['review_note']),
      requestedByName: _optionalText(json['requested_by_name']),
      reviewedByName: _optionalText(json['reviewed_by_name']),
      createdAtLocal: _optionalText(json['created_at_local']),
      reviewedAtLocal: _optionalText(json['reviewed_at_local']),
      isPaid: json['is_paid'] != false,
      tracksBalance: json['tracks_balance'] == true,
      balance: balance is Map ? Map<String, dynamic>.from(balance) : null,
    );
  }
}

DateTime _date(Object? value) =>
    DateTime.tryParse('${value ?? ''}') ?? DateTime(2000);
num? _number(Object? value) => value is num ? value : num.tryParse('$value');
String? _optionalText(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}
