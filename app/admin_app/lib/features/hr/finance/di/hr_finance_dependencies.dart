import '../data/repositories/supabase_hr_finance_repository.dart';
import '../domain/repositories/hr_finance_repository.dart';

class HrFinanceDependencies {
  HrFinanceDependencies._();
  static HrFinanceRepository repository = SupabaseHrFinanceRepository();
}
