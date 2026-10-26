import 'package:admin_app/features/loyalty/domain/entities/admin_loyalty_transaction.dart';
import 'package:admin_app/features/loyalty/domain/repositories/loyalty_repository.dart';

/// قراءة صفحة من حركات الولاء.
class LoadTransactionsUseCase {
  const LoadTransactionsUseCase(this._repository);

  final LoyaltyRepository _repository;

  Future<AdminLoyaltyTransactionFeed> call({int limit = 300}) =>
      _repository.loadTransactions(limit: limit);
}
