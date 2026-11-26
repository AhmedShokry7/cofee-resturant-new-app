import 'package:admin_app/features/marketing/domain/repositories/marketing_repository.dart';

/// A deterministic, PII-free campaign preview for the admin assistant.
///
/// A preview has no side effects. [saveDraft] is a separate explicit step and
/// only uses the existing permission-checked draft RPCs. It deliberately has
/// no submit, approve, schedule, or send operation.
class AdminAssistantCampaignDraftService {
  AdminAssistantCampaignDraftService(this._repository);

  final MarketingRepository _repository;

  AdminAssistantCampaignPreview prepare({
    required String name,
    required String channel,
    required String purpose,
    required String titleAr,
    required String titleEn,
    required String bodyAr,
    required String bodyEn,
    String? segmentId,
    DateTime? proposedSendTime,
  }) {
    final cleanName = name.trim();
    final cleanChannel = channel.trim().toLowerCase();
    final cleanPurpose = purpose.trim().toLowerCase();
    final cleanSegmentId = _emptyToNull(segmentId);
    if (cleanName.isEmpty) throw ArgumentError('اسم الحملة مطلوب');
    if (!_channels.contains(cleanChannel)) {
      throw ArgumentError('قناة الحملة غير مدعومة');
    }
    if (!_purposes.contains(cleanPurpose)) {
      throw ArgumentError('غرض الحملة غير مدعوم');
    }
    if (cleanSegmentId != null && !_looksLikeUuid(cleanSegmentId)) {
      throw ArgumentError('معرّف الشريحة غير صالح');
    }
    final fields = <String, String>{
      'العنوان العربي': titleAr,
      'العنوان الإنجليزي': titleEn,
      'النص العربي': bodyAr,
      'النص الإنجليزي': bodyEn,
    };
    for (final entry in fields.entries) {
      if (entry.value.trim().isEmpty) {
        throw ArgumentError('${entry.key} مطلوب لحفظ الحملة');
      }
    }
    if (proposedSendTime != null && !proposedSendTime.isAfter(DateTime.now())) {
      throw ArgumentError('موعد الإرسال المقترح يجب أن يكون في المستقبل');
    }

    return AdminAssistantCampaignPreview._(
      name: cleanName,
      channel: cleanChannel,
      purpose: cleanPurpose,
      titleAr: titleAr.trim(),
      titleEn: titleEn.trim(),
      bodyAr: bodyAr.trim(),
      bodyEn: bodyEn.trim(),
      segmentId: cleanSegmentId,
      proposedSendTime: proposedSendTime?.toUtc(),
      audienceEstimate: null,
      audienceNote:
          'عدد المستلمين غير متاح قبل الجدولة؛ لا يتم تخمينه. '
          'سيُعاد التحقق من الموافقة والأهلية عند الجدولة.',
    );
  }

  /// Saves a draft campaign and its first draft version after explicit
  /// confirmation. This never schedules or sends a campaign.
  Future<AdminAssistantSavedCampaignDraft> saveDraft(
    AdminAssistantCampaignPreview preview,
  ) async {
    final campaignId = await _repository.createCampaign(
      name: preview.name,
      channel: preview.channel,
      purpose: preview.purpose,
      segmentId: preview.segmentId,
    );
    try {
      final versionId = await _repository.createVersion(
        campaignId: campaignId,
        titleAr: preview.titleAr,
        titleEn: preview.titleEn,
        bodyAr: preview.bodyAr,
        bodyEn: preview.bodyEn,
      );
      return AdminAssistantSavedCampaignDraft(
        campaignId: campaignId,
        versionId: versionId,
      );
    } catch (error) {
      // Existing RPCs are separate transactions. Surface the created draft ID
      // so the caller can recover it instead of silently creating duplicates.
      throw AdminAssistantCampaignDraftSaveException(
        campaignId: campaignId,
        cause: error,
      );
    }
  }

  static const _channels = {'push', 'email', 'sms', 'whatsapp'};
  static const _purposes = {'promotions', 'offers', 'loyalty_marketing'};

  static String? _emptyToNull(String? value) {
    final clean = value?.trim();
    return clean == null || clean.isEmpty ? null : clean;
  }

  static bool _looksLikeUuid(String value) => RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  ).hasMatch(value);
}

class AdminAssistantCampaignPreview {
  const AdminAssistantCampaignPreview._({
    required this.name,
    required this.channel,
    required this.purpose,
    required this.titleAr,
    required this.titleEn,
    required this.bodyAr,
    required this.bodyEn,
    required this.segmentId,
    required this.proposedSendTime,
    required this.audienceEstimate,
    required this.audienceNote,
  });

  final String name;
  final String channel;
  final String purpose;
  final String titleAr;
  final String titleEn;
  final String bodyAr;
  final String bodyEn;
  final String? segmentId;
  final DateTime? proposedSendTime;

  /// Null because current campaign APIs have no side-effect-free count RPC.
  final int? audienceEstimate;
  final String audienceNote;
}

class AdminAssistantSavedCampaignDraft {
  const AdminAssistantSavedCampaignDraft({
    required this.campaignId,
    required this.versionId,
  });

  final String campaignId;
  final String versionId;
}

class AdminAssistantCampaignDraftSaveException implements Exception {
  const AdminAssistantCampaignDraftSaveException({
    required this.campaignId,
    required this.cause,
  });

  /// Campaign row was created, but creation of its first version failed.
  final String campaignId;
  final Object cause;

  @override
  String toString() =>
      'Campaign $campaignId exists as an empty draft; version creation failed: $cause';
}
