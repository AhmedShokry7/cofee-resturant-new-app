import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:admin_app/core/services/supabase_service.dart';
import 'package:admin_app/features/marketing/domain/entities/marketing_entities.dart';
import 'package:admin_app/features/marketing/domain/repositories/marketing_repository.dart';
import 'package:admin_app/features/notifications/domain/entities/notification_json.dart';

/// Real RPC-backed repository for the Marketing Hub. Every call maps to a
/// `marketing.*` / `public.admin_marketing_consents` RPC from the approved
/// proposal set; nothing is mocked and nothing is sent from the client.
class SupabaseMarketingRepository implements MarketingRepository {
  SupabaseMarketingRepository([this._client]);

  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? SupabaseService.client;

  @override
  Future<List<MarketingCampaign>> loadCampaigns() async {
    final response = await _supabase.schema('marketing').rpc('list_campaigns');
    if (response is List) {
      return response
          .map(
            (e) => MarketingCampaign.fromJson(notificationMap(e) ?? const {}),
          )
          .toList();
    }
    return const <MarketingCampaign>[];
  }

  @override
  Future<MarketingCampaign> loadCampaign(String campaignId) async {
    final response = await _supabase
        .schema('marketing')
        .rpc('get_campaign', params: {'p_campaign_id': campaignId});
    final map = notificationMap(response);
    if (map == null) throw StateError('campaign not found');
    return MarketingCampaign.fromJson(map);
  }

  @override
  Future<String> createCampaign({
    required String name,
    required String channel,
    required String purpose,
    String? segmentId,
  }) async {
    final id = await _supabase
        .schema('marketing')
        .rpc(
          'create_campaign',
          params: {
            'p_name': name,
            'p_channel': channel,
            'p_purpose': purpose,
            'p_segment_id': segmentId,
          },
        );
    return id.toString();
  }

  @override
  Future<String> createVersion({
    required String campaignId,
    required String titleAr,
    required String titleEn,
    required String bodyAr,
    required String bodyEn,
    String? imageUrl,
    String? destination,
  }) async {
    final id = await _supabase
        .schema('marketing')
        .rpc(
          'create_campaign_version',
          params: {
            'p_campaign_id': campaignId,
            'p_title_ar': titleAr,
            'p_title_en': titleEn,
            'p_body_ar': bodyAr,
            'p_body_en': bodyEn,
            'p_payload': const <String, dynamic>{},
            'p_image_url': imageUrl,
            'p_destination': destination,
          },
        );
    return id.toString();
  }

  @override
  Future<void> submitForReview(String campaignId) async {
    await _supabase
        .schema('marketing')
        .rpc(
          'submit_campaign_for_review',
          params: {'p_campaign_id': campaignId},
        );
  }

  @override
  Future<void> approve(String campaignId) async {
    await _supabase
        .schema('marketing')
        .rpc('approve_campaign', params: {'p_campaign_id': campaignId});
  }

  @override
  Future<void> returnToDraft(String campaignId, {String? reason}) async {
    await _supabase
        .schema('marketing')
        .rpc(
          'return_campaign_to_draft',
          params: {'p_campaign_id': campaignId, 'p_reason': reason},
        );
  }

  @override
  Future<String> schedule(String campaignId, DateTime scheduledFor) async {
    final id = await _supabase
        .schema('marketing')
        .rpc(
          'schedule_campaign',
          params: {
            'p_campaign_id': campaignId,
            'p_scheduled_for': scheduledFor.toUtc().toIso8601String(),
          },
        );
    return id.toString();
  }

  @override
  Future<void> cancel(String campaignId) async {
    await _supabase
        .schema('marketing')
        .rpc('cancel_campaign', params: {'p_campaign_id': campaignId});
  }

  @override
  Future<void> pauseExecution(String executionId) async {
    await _supabase
        .schema('marketing')
        .rpc('pause_execution', params: {'p_execution_id': executionId});
  }

  @override
  Future<void> resumeExecution(String executionId) async {
    await _supabase
        .schema('marketing')
        .rpc('resume_execution', params: {'p_execution_id': executionId});
  }

  @override
  Future<List<MarketingRecipient>> loadRecipients(String executionId) async {
    final response = await _supabase
        .schema('marketing')
        .rpc(
          'list_campaign_recipients',
          params: {'p_execution_id': executionId, 'p_limit': 200},
        );
    if (response is List) {
      return response
          .map(
            (e) => MarketingRecipient.fromJson(notificationMap(e) ?? const {}),
          )
          .toList();
    }
    return const <MarketingRecipient>[];
  }

  @override
  Future<List<MarketingAttempt>> loadAttempts(String executionId) async {
    final response = await _supabase
        .schema('marketing')
        .rpc('list_campaign_attempts', params: {'p_execution_id': executionId});
    if (response is List) {
      return response
          .map((e) => MarketingAttempt.fromJson(notificationMap(e) ?? const {}))
          .toList();
    }
    return const <MarketingAttempt>[];
  }

  @override
  Future<List<ConsentState>> loadConsents(String userId) async {
    final response = await _supabase.rpc(
      'admin_marketing_consents',
      params: {'p_user_id': userId},
    );
    if (response is List) {
      return response
          .map((e) => ConsentState.fromJson(notificationMap(e) ?? const {}))
          .toList();
    }
    return const <ConsentState>[];
  }
}
