import 'package:new_coffee/core/data/db_values.dart';

class CustomerEventRequest {
  const CustomerEventRequest({
    required this.id,
    required this.occasionType,
    this.occasionName,
    required this.occasionDate,
    required this.preferredStartAt,
    required this.preferredEndAt,
    required this.guestCount,
    required this.requestedSpaceType,
    required this.status,
    required this.branchName,
    this.requestedServices,
    this.customerNote,
    this.quoteAmount,
    this.quoteNote,
    this.quotedSpaceName,
    this.quotedSpaceId,
    this.quotedSpaceOptions = const [],
    this.quotedSpaceImageUrl,
    this.quotedStartAt,
    this.quotedEndAt,
    this.quoteExpiresAt,
    this.createdAt,
    this.reminderMinutes = 1440,
    this.reminderAt,
  });

  final String id;
  final String occasionType;
  final String? occasionName;
  final DateTime occasionDate;
  final DateTime preferredStartAt;
  final DateTime preferredEndAt;
  final int guestCount;
  final String requestedSpaceType;
  final String status;
  final String branchName;
  final String? requestedServices;
  final String? customerNote;
  final double? quoteAmount;
  final String? quoteNote;
  final String? quotedSpaceName;
  final String? quotedSpaceId;
  final List<Map<String, dynamic>> quotedSpaceOptions;
  final String? quotedSpaceImageUrl;
  final DateTime? quotedStartAt;
  final DateTime? quotedEndAt;
  final DateTime? quoteExpiresAt;
  final DateTime? createdAt;
  final int reminderMinutes;
  final DateTime? reminderAt;

  factory CustomerEventRequest.fromJson(Map<String, dynamic> json) =>
      CustomerEventRequest(
        id: Db.text(json['id']),
        occasionType: Db.text(json['occasion_type'], 'other'),
        occasionName: Db.textOrNull(json['occasion_name']),
        occasionDate: Db.asDateTime(json['occasion_date']),
        preferredStartAt: Db.asDateTime(json['preferred_start_at']),
        preferredEndAt: Db.asDateTime(json['preferred_end_at']),
        guestCount: Db.asInt(json['guest_count']),
        requestedSpaceType: Db.text(json['requested_space_type'], 'any'),
        status: Db.text(json['status'], 'pending'),
        branchName: Db.text(json['branch_name_ar'] ?? json['branch_name_en']),
        requestedServices: Db.textOrNull(json['requested_services']),
        customerNote: Db.textOrNull(json['customer_note']),
        quoteAmount: json['quote_amount'] == null
            ? null
            : (json['quote_amount'] as num).toDouble(),
        quoteNote: Db.textOrNull(json['quote_note']),
        quotedSpaceName: Db.textOrNull(json['quoted_space_name']),
        quotedSpaceId: Db.textOrNull(json['quoted_space_id']),
        quotedSpaceOptions: (json['quoted_space_options'] as List? ?? const [])
            .whereType<Map>()
            .map((option) => Map<String, dynamic>.from(option))
            .toList(growable: false),
        quotedSpaceImageUrl: Db.textOrNull(
          json['quoted_space_image_url'],
        ),
        quotedStartAt: Db.asDateTimeOrNull(json['quoted_start_at']),
        quotedEndAt: Db.asDateTimeOrNull(json['quoted_end_at']),
        quoteExpiresAt: Db.asDateTimeOrNull(json['quote_expires_at']),
        createdAt: Db.asDateTimeOrNull(json['created_at']),
        reminderMinutes: Db.asInt(json['reminder_minutes'], fallback: 1440),
        reminderAt: Db.asDateTimeOrNull(json['reminder_at']),
      );
}
