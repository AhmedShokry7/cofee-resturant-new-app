import 'package:admin_app/features/marketing/domain/entities/marketing_entities.dart';

/// Marketing Hub contract. The Supabase implementation lives in
/// data/repositories; the presentation layer never talks to the network
/// directly, and a missing backend surfaces as an error the UI renders
/// as an explicit "unavailable" state instead of fake data.
abstract interface class MarketingRepository {
  Future<List<MarketingCampaign>> loadCampaigns();

  Future<MarketingCampaign> loadCampaign(String campaignId);

  Future<String> createCampaign({
    required String name,
    required String channel,
    required String purpose,
    String? segmentId,
  });

  Future<String> createVersion({
    required String campaignId,
    required String titleAr,
    required String titleEn,
    required String bodyAr,
    required String bodyEn,
    String? imageUrl,
    String? destination,
  });

  Future<void> submitForReview(String campaignId);

  Future<void> approve(String campaignId);

  Future<void> returnToDraft(String campaignId, {String? reason});

  Future<String> schedule(String campaignId, DateTime scheduledFor);

  Future<void> cancel(String campaignId);

  Future<void> pauseExecution(String executionId);

  Future<void> resumeExecution(String executionId);

  Future<List<MarketingRecipient>> loadRecipients(String executionId);

  Future<List<MarketingAttempt>> loadAttempts(String executionId);

  Future<List<ConsentState>> loadConsents(String userId);
}
