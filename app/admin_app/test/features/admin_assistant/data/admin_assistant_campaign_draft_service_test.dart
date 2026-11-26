import 'package:admin_app/features/admin_assistant/data/admin_assistant_campaign_draft_service.dart';
import 'package:admin_app/features/marketing/domain/repositories/marketing_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AdminAssistantCampaignDraftService', () {
    test(
      'prepares without side effects and does not invent audience counts',
      () {
        final repository = _FakeMarketingRepository();
        final service = AdminAssistantCampaignDraftService(repository);

        final preview = service.prepare(
          name: '  عرض نهاية الأسبوع ',
          channel: 'PUSH',
          purpose: 'promotions',
          titleAr: 'خصم اليوم',
          titleEn: 'Today discount',
          bodyAr: 'استمتع بالعرض',
          bodyEn: 'Enjoy the offer',
          proposedSendTime: DateTime.now().add(const Duration(days: 1)),
        );

        expect(preview.name, 'عرض نهاية الأسبوع');
        expect(preview.channel, 'push');
        expect(preview.audienceEstimate, isNull);
        expect(repository.calls, isEmpty);
      },
    );

    test('explicit save creates draft and first version only', () async {
      final repository = _FakeMarketingRepository();
      final service = AdminAssistantCampaignDraftService(repository);
      final preview = service.prepare(
        name: 'Campaign',
        channel: 'email',
        purpose: 'offers',
        titleAr: 'عرض',
        titleEn: 'Offer',
        bodyAr: 'النص',
        bodyEn: 'Body',
      );

      final saved = await service.saveDraft(preview);

      expect(saved.campaignId, 'campaign-id');
      expect(saved.versionId, 'version-id');
      expect(repository.calls, ['createCampaign', 'createVersion']);
    });

    test('rejects invalid fields before touching repository', () {
      final repository = _FakeMarketingRepository();
      final service = AdminAssistantCampaignDraftService(repository);

      expect(
        () => service.prepare(
          name: 'Campaign',
          channel: 'push',
          purpose: 'promotions',
          titleAr: '',
          titleEn: 'Title',
          bodyAr: 'نص',
          bodyEn: 'Body',
        ),
        throwsArgumentError,
      );
      expect(repository.calls, isEmpty);
    });
  });
}

class _FakeMarketingRepository implements MarketingRepository {
  final calls = <String>[];

  @override
  Future<String> createCampaign({
    required String name,
    required String channel,
    required String purpose,
    String? segmentId,
  }) async {
    calls.add('createCampaign');
    return 'campaign-id';
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
    calls.add('createVersion');
    return 'version-id';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
