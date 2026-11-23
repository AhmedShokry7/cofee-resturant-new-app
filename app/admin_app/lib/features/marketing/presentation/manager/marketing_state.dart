import 'package:admin_app/features/marketing/domain/entities/marketing_entities.dart';

enum MarketingLoadStatus { initial, loading, loaded, failure }

class MarketingState {
  const MarketingState({
    this.status = MarketingLoadStatus.initial,
    this.campaigns = const <MarketingCampaign>[],
    this.overview = const MarketingOverview(),
    this.selectedCampaign,
    this.recipients = const <MarketingRecipient>[],
    this.attempts = const <MarketingAttempt>[],
    this.consents = const <ConsentState>[],
    this.error,
    this.actionError,
    this.isActing = false,
  });

  final MarketingLoadStatus status;
  final List<MarketingCampaign> campaigns;
  final MarketingOverview overview;
  final MarketingCampaign? selectedCampaign;
  final List<MarketingRecipient> recipients;
  final List<MarketingAttempt> attempts;
  final List<ConsentState> consents;
  final String? error;
  final String? actionError;
  final bool isActing;

  bool get isLoading => status == MarketingLoadStatus.loading;

  MarketingState copyWith({
    MarketingLoadStatus? status,
    List<MarketingCampaign>? campaigns,
    MarketingOverview? overview,
    MarketingCampaign? selectedCampaign,
    List<MarketingRecipient>? recipients,
    List<MarketingAttempt>? attempts,
    List<ConsentState>? consents,
    String? error,
    String? actionError,
    bool? isActing,
    bool clearActionError = false,
  }) {
    return MarketingState(
      status: status ?? this.status,
      campaigns: campaigns ?? this.campaigns,
      overview: overview ?? this.overview,
      selectedCampaign: selectedCampaign ?? this.selectedCampaign,
      recipients: recipients ?? this.recipients,
      attempts: attempts ?? this.attempts,
      consents: consents ?? this.consents,
      error: error ?? this.error,
      actionError: clearActionError ? null : (actionError ?? this.actionError),
      isActing: isActing ?? this.isActing,
    );
  }
}
