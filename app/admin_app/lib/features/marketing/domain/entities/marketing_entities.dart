import 'package:admin_app/features/notifications/domain/entities/notification_json.dart';

/// Marketing Hub entities mirrored from the `marketing.*` RPC responses
/// (list_campaigns / get_campaign / list_campaign_recipients / list_campaign_attempts
/// and public.admin_marketing_consents). Parsing is defensive: any missing field
/// falls back to a safe default so a partial payload never crashes the panel.

enum MarketingCampaignStatus {
  draft,
  pendingReview,
  approved,
  scheduled,
  processing,
  completed,
  failed,
  cancelled,
  unknown,
}

MarketingCampaignStatus campaignStatusOf(String? raw) {
  switch (raw) {
    case 'draft':
      return MarketingCampaignStatus.draft;
    case 'pending_review':
      return MarketingCampaignStatus.pendingReview;
    case 'approved':
      return MarketingCampaignStatus.approved;
    case 'scheduled':
      return MarketingCampaignStatus.scheduled;
    case 'processing':
      return MarketingCampaignStatus.processing;
    case 'completed':
      return MarketingCampaignStatus.completed;
    case 'failed':
      return MarketingCampaignStatus.failed;
    case 'cancelled':
      return MarketingCampaignStatus.cancelled;
    default:
      return MarketingCampaignStatus.unknown;
  }
}

class MarketingCampaign {
  const MarketingCampaign({
    required this.id,
    required this.name,
    required this.channel,
    required this.purpose,
    required this.status,
    this.currentVersionId,
    this.approvedVersionId,
    this.segmentId,
    this.scheduledFor,
    this.createdAt,
    this.recipientTotal = 0,
    this.sentTotal = 0,
  });

  final String id;
  final String name;
  final String channel;
  final String purpose;
  final MarketingCampaignStatus status;
  final String? currentVersionId;
  final String? approvedVersionId;
  final String? segmentId;
  final DateTime? scheduledFor;
  final DateTime? createdAt;
  final int recipientTotal;
  final int sentTotal;

  factory MarketingCampaign.fromJson(Map<String, dynamic> json) {
    return MarketingCampaign(
      id: notificationText(json['id']) ?? '',
      name: notificationText(json['name']) ?? '',
      channel: notificationText(json['channel']) ?? 'push',
      purpose: notificationText(json['purpose']) ?? 'promotions',
      status: campaignStatusOf(notificationText(json['status'])),
      currentVersionId: notificationText(json['current_version_id']),
      approvedVersionId: notificationText(json['approved_version_id']),
      segmentId: notificationText(json['segment_id']),
      scheduledFor: notificationDate(json['scheduled_for']),
      createdAt: notificationDate(json['created_at']),
      recipientTotal: notificationInt(json['recipient_total']),
      sentTotal: notificationInt(json['sent_total']),
    );
  }
}

class MarketingCampaignVersion {
  const MarketingCampaignVersion({
    this.id,
    this.titleAr,
    this.titleEn,
    this.bodyAr,
    this.bodyEn,
    this.imageUrl,
    this.destination,
    this.versionStatus,
  });

  final String? id;
  final String? titleAr;
  final String? titleEn;
  final String? bodyAr;
  final String? bodyEn;
  final String? imageUrl;
  final String? destination;
  final String? versionStatus;

  factory MarketingCampaignVersion.fromJson(Map<String, dynamic> json) {
    return MarketingCampaignVersion(
      id: notificationText(json['id']),
      titleAr: notificationText(json['title_ar']),
      titleEn: notificationText(json['title_en']),
      bodyAr: notificationText(json['body_ar']),
      bodyEn: notificationText(json['body_en']),
      imageUrl: notificationText(json['image_url']),
      destination: notificationText(json['destination']),
      versionStatus: notificationText(json['version_status']),
    );
  }
}

class MarketingExecution {
  const MarketingExecution({
    required this.id,
    required this.status,
    this.scheduledFor,
    this.totalRecipients = 0,
    this.processedCount = 0,
    this.sentCount = 0,
    this.skippedCount = 0,
    this.failedCount = 0,
    this.unknownCount = 0,
  });

  final String id;
  final String status;
  final DateTime? scheduledFor;
  final int totalRecipients;
  final int processedCount;
  final int sentCount;
  final int skippedCount;
  final int failedCount;
  final int unknownCount;

  factory MarketingExecution.fromJson(Map<String, dynamic> json) {
    return MarketingExecution(
      id: notificationText(json['id']) ?? '',
      status: notificationText(json['status']) ?? 'queued',
      scheduledFor: notificationDate(json['scheduled_for']),
      totalRecipients: notificationInt(json['total_recipients']),
      processedCount: notificationInt(json['processed_count']),
      sentCount: notificationInt(json['sent_count']),
      skippedCount: notificationInt(json['skipped_count']),
      failedCount: notificationInt(json['failed_count']),
      unknownCount: notificationInt(json['unknown_count']),
    );
  }
}

class MarketingRecipient {
  const MarketingRecipient({
    required this.userId,
    required this.channel,
    required this.purpose,
    required this.dispatchStatus,
    this.eligibilityStatus,
    this.notificationId,
  });

  final String userId;
  final String channel;
  final String purpose;
  final String dispatchStatus;
  final String? eligibilityStatus;
  final String? notificationId;

  factory MarketingRecipient.fromJson(Map<String, dynamic> json) {
    return MarketingRecipient(
      userId: notificationText(json['user_id']) ?? '',
      channel: notificationText(json['channel']) ?? '',
      purpose: notificationText(json['purpose']) ?? '',
      dispatchStatus: notificationText(json['dispatch_status']) ?? 'pending',
      eligibilityStatus: notificationText(json['eligibility_status']),
      notificationId: notificationText(json['notification_id']),
    );
  }
}

class MarketingAttempt {
  const MarketingAttempt({
    required this.channel,
    required this.status,
    this.attemptNumber = 0,
    this.errorCode,
    this.providerStatus,
    this.startedAt,
  });

  final String channel;
  final String status;
  final int attemptNumber;
  final String? errorCode;
  final String? providerStatus;
  final DateTime? startedAt;

  factory MarketingAttempt.fromJson(Map<String, dynamic> json) {
    return MarketingAttempt(
      channel: notificationText(json['channel']) ?? '',
      status: notificationText(json['status']) ?? 'queued',
      attemptNumber: notificationInt(json['attempt_number']),
      errorCode: notificationText(json['error_code']),
      providerStatus: notificationText(json['provider_status']),
      startedAt: notificationDate(json['started_at']),
    );
  }
}

class ConsentState {
  const ConsentState({
    required this.channel,
    required this.purpose,
    required this.status,
    this.updatedAt,
    this.lastEventSeq,
  });

  final String channel;
  final String purpose;
  final String status;
  final DateTime? updatedAt;
  final int? lastEventSeq;

  bool get isGranted => status == 'granted';

  factory ConsentState.fromJson(Map<String, dynamic> json) {
    return ConsentState(
      channel: notificationText(json['channel']) ?? '',
      purpose: notificationText(json['purpose']) ?? '',
      status: notificationText(json['status']) ?? 'revoked',
      updatedAt: notificationDate(json['updated_at']),
      lastEventSeq: notificationInt(json['last_event_seq']),
    );
  }
}

class MarketingOverview {
  const MarketingOverview({
    this.totalCampaigns = 0,
    this.activeCampaigns = 0,
    this.scheduledCampaigns = 0,
    this.completedCampaigns = 0,
    this.totalRecipients = 0,
    this.totalSent = 0,
    this.recent = const <MarketingCampaign>[],
  });

  final int totalCampaigns;
  final int activeCampaigns;
  final int scheduledCampaigns;
  final int completedCampaigns;
  final int totalRecipients;
  final int totalSent;
  final List<MarketingCampaign> recent;

  factory MarketingOverview.fromCampaigns(List<MarketingCampaign> campaigns) {
    int active = 0;
    int scheduled = 0;
    int completed = 0;
    int recipients = 0;
    int sent = 0;
    for (final c in campaigns) {
      recipients += c.recipientTotal;
      sent += c.sentTotal;
      switch (c.status) {
        case MarketingCampaignStatus.scheduled:
        case MarketingCampaignStatus.processing:
          active += 1;
          scheduled += 1;
        case MarketingCampaignStatus.approved:
        case MarketingCampaignStatus.pendingReview:
          active += 1;
        case MarketingCampaignStatus.completed:
          completed += 1;
        default:
      }
    }
    return MarketingOverview(
      totalCampaigns: campaigns.length,
      activeCampaigns: active,
      scheduledCampaigns: scheduled,
      completedCampaigns: completed,
      totalRecipients: recipients,
      totalSent: sent,
      recent: campaigns.take(5).toList(),
    );
  }
}
