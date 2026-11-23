import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/features/marketing/domain/entities/marketing_entities.dart';
import 'package:admin_app/features/marketing/domain/repositories/marketing_repository.dart';
import 'package:admin_app/features/marketing/presentation/manager/marketing_cubit.dart';
import 'package:admin_app/features/marketing/presentation/manager/marketing_state.dart';

class _FakeMarketingRepository implements MarketingRepository {
  List<MarketingCampaign> campaigns = const <MarketingCampaign>[];
  bool shouldFail = false;
  int loadCalls = 0;
  String? createdName;
  String? approvedId;
  bool approved = false;

  @override
  Future<List<MarketingCampaign>> loadCampaigns() async {
    loadCalls += 1;
    if (shouldFail) throw StateError('backend missing');
    return campaigns;
  }

  @override
  Future<MarketingCampaign> loadCampaign(String campaignId) async {
    return campaigns.firstWhere((c) => c.id == campaignId);
  }

  @override
  Future<String> createCampaign({
    required String name,
    required String channel,
    required String purpose,
    String? segmentId,
  }) async {
    createdName = name;
    return 'new-id';
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
  }) async => 'v-id';

  @override
  Future<void> submitForReview(String campaignId) async {}

  @override
  Future<void> approve(String campaignId) async {
    approvedId = campaignId;
    approved = true;
  }

  @override
  Future<void> returnToDraft(String campaignId, {String? reason}) async {}

  @override
  Future<String> schedule(String campaignId, DateTime scheduledFor) async =>
      'exec-id';

  @override
  Future<void> cancel(String campaignId) async {}

  @override
  Future<void> pauseExecution(String executionId) async {}

  @override
  Future<void> resumeExecution(String executionId) async {}

  @override
  Future<List<MarketingRecipient>> loadRecipients(String executionId) async =>
      const <MarketingRecipient>[];

  @override
  Future<List<MarketingAttempt>> loadAttempts(String executionId) async =>
      const <MarketingAttempt>[];

  @override
  Future<List<ConsentState>> loadConsents(String userId) async =>
      const <ConsentState>[];
}

MarketingCampaign _campaign(String id, MarketingCampaignStatus status) =>
    MarketingCampaign(
      id: id,
      name: 'Campaign $id',
      channel: 'push',
      purpose: 'promotions',
      status: status,
      recipientTotal: 10,
      sentTotal: 7,
    );

void main() {
  test('load populates campaigns and overview on success', () async {
    final repo = _FakeMarketingRepository()
      ..campaigns = [
        _campaign('a', MarketingCampaignStatus.scheduled),
        _campaign('b', MarketingCampaignStatus.completed),
      ];
    final cubit = MarketingCubit(repository: repo);
    addTearDown(cubit.close);

    await cubit.load();

    expect(cubit.state.status, MarketingLoadStatus.loaded);
    expect(cubit.state.campaigns, hasLength(2));
    expect(cubit.state.overview.totalCampaigns, 2);
    expect(cubit.state.overview.scheduledCampaigns, 1);
    expect(cubit.state.overview.completedCampaigns, 1);
    expect(cubit.state.overview.totalRecipients, 20);
    expect(cubit.state.overview.totalSent, 14);
  });

  test('load surfaces failure without fabricating data', () async {
    final repo = _FakeMarketingRepository()..shouldFail = true;
    final cubit = MarketingCubit(repository: repo);
    addTearDown(cubit.close);

    await cubit.load();

    expect(cubit.state.status, MarketingLoadStatus.failure);
    expect(cubit.state.error, contains('backend missing'));
    expect(cubit.state.campaigns, isEmpty);
  });

  test('approve delegates to repository and reloads', () async {
    final repo = _FakeMarketingRepository()
      ..campaigns = [_campaign('a', MarketingCampaignStatus.approved)];
    final cubit = MarketingCubit(repository: repo);
    addTearDown(cubit.close);

    await cubit.approve('a');

    expect(repo.approved, isTrue);
    expect(repo.approvedId, 'a');
    expect(repo.loadCalls, 1);
    expect(cubit.state.isActing, isFalse);
  });

  test('overview aggregation counts draft as not active', () {
    final overview = MarketingOverview.fromCampaigns([
      _campaign('a', MarketingCampaignStatus.draft),
      _campaign('b', MarketingCampaignStatus.processing),
      _campaign('c', MarketingCampaignStatus.pendingReview),
    ]);
    expect(overview.totalCampaigns, 3);
    expect(overview.activeCampaigns, 2);
    expect(overview.scheduledCampaigns, 1);
  });
}
