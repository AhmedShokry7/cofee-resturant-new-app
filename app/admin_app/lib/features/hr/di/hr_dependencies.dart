import 'package:admin_app/features/hr/data/repositories/admin_hr_leave_repository.dart';
import 'package:admin_app/features/hr/data/repositories/admin_hr_money_repository.dart';
import 'package:admin_app/features/hr/data/repositories/admin_hr_payroll_repository.dart';
import 'package:admin_app/features/hr/data/repositories/admin_hr_people_repository.dart';
import 'package:admin_app/features/hr/data/repositories/admin_hr_time_repository.dart';
import 'package:admin_app/features/hr/domain/repositories/hr_leave_repository.dart';
import 'package:admin_app/features/hr/domain/repositories/hr_money_repository.dart';
import 'package:admin_app/features/hr/domain/repositories/hr_payroll_repository.dart';
import 'package:admin_app/features/hr/domain/repositories/hr_people_repository.dart';
import 'package:admin_app/features/hr/domain/repositories/hr_time_repository.dart';

/// نقطة تركيب اعتمادات فيتشر HR داخل الفيتشر نفسه، فلا تستورد طبقة العرض
/// `data/repositories` مباشرة ولا تعرف أي عقد يخدمها.
abstract final class HrDependencies {
  HrDependencies._();

  static HrPeopleRepository? _people;
  static HrTimeRepository? _time;
  static HrLeaveRepository? _leave;
  static HrPayrollRepository? _payroll;
  static HrMoneyRepository? _money;

  /// الأدلة والملفات ولوحة HR وسياسة `hr.settings`.
  static HrPeopleRepository get people => _people ??= AdminHrPeopleRepository();

  /// البصمة والحضور والتصحيحات والجداول.
  static HrTimeRepository get time => _time ??= AdminHrTimeRepository();

  /// طلبات الإجازة وأرصدة السنة.
  static HrLeaveRepository get leave => _leave ??= AdminHrLeaveRepository();

  /// تركيبة الأجر ودورات الرواتب وقسيماتها.
  static HrPayrollRepository get payroll =>
      _payroll ??= AdminHrPayrollRepository();

  /// السلف والتسويات وفروق صناديق الكاشير.
  static HrMoneyRepository get money => _money ??= AdminHrMoneyRepository();
}
