import '../data/repositories/supabase_hr_leave_repository.dart';
import '../domain/repositories/hr_leave_repository.dart';

class HrLeaveDependencies {
  HrLeaveDependencies._();
  static HrLeaveRepository repository = SupabaseHrLeaveRepository();
}
