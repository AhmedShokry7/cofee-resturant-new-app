import 'package:admin_app/features/marketing/data/repositories/supabase_marketing_repository.dart';
import 'package:admin_app/features/marketing/domain/repositories/marketing_repository.dart';

/// Composition point for the Marketing Hub, mirroring the notifications
/// feature: presentation gets the repository from here, never from data/.
abstract final class MarketingDependencies {
  MarketingDependencies._();

  static MarketingRepository? _repository;

  static MarketingRepository get repository =>
      _repository ??= SupabaseMarketingRepository();
}
