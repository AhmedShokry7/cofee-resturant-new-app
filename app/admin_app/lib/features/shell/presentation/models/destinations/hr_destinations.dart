import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/navigation/admin_destination.dart';
import 'package:admin_app/core/theme/app_icons.dart';

/// قسم الموارد البشرية: الدليل والحضور والجدول والإجازة والرواتب والتسويات.
///
/// الأذونات هنا هي رموز 212 نفسها، حرفيًا كما مُنحت لأدوار `manager` و
/// `branch_manager`: من لا يرمز له الرمز لا يرى الوجهة أصلًا، ومن يراها تسأله
/// القاعدة مرة أخرى عند كل كتابة. و«يوبي» مقفول بـ `hr.employee.read` مثل بقية
/// الوجوه: الشاشة تعرض ملف الموظف نفسه، والغطاء هنا غطاء واجهة لا إبدال لحق
/// الملكية الذي تمنحه الدوال على أي حال.
List<AdminDestination> get hrDestinations => <AdminDestination>[
  AdminDestination(
    id: 'hrMyDay',
    label: S.hrMyDay,
    icon: AppIcons.clock01,
    searchHint: S.searchHrMyDayHint,
    permission: 'hr.employee.read',
    section: S.sectionHr,
    tables: <String>[
      'hr.attendance_sessions',
      'hr.leave_requests',
      'hr.payroll_statements',
    ],
  ),
  AdminDestination(
    id: 'hrDashboard',
    label: S.hrDashboard,
    icon: AppIcons.dashboardSquare01,
    searchHint: S.searchHrDashboardHint,
    permission: 'hr.employee.read',
    section: S.sectionHr,
    tables: <String>[
      'hr.employment_records',
      'hr.attendance_sessions',
      'hr.leave_requests',
    ],
  ),
  AdminDestination(
    id: 'hrEmployees',
    label: S.hrEmployees,
    icon: AppIcons.userMultiple,
    searchHint: S.searchHrEmployeesHint,
    permission: 'hr.employee.read',
    section: S.sectionHr,
    tables: <String>[
      'hr.employment_records',
      'identity.staff_members',
      'hr.compensations',
    ],
  ),
  AdminDestination(
    id: 'hrAttendance',
    label: S.hrAttendance,
    icon: AppIcons.timer01,
    searchHint: S.searchHrAttendanceHint,
    permission: 'hr.attendance.read',
    section: S.sectionHr,
    tables: <String>['hr.attendance_sessions', 'hr.attendance_corrections'],
  ),
  AdminDestination(
    id: 'hrSchedules',
    label: S.hrSchedules,
    icon: AppIcons.calendar01,
    searchHint: S.searchHrSchedulesHint,
    permission: 'hr.schedule.read',
    section: S.sectionHr,
    tables: <String>['hr.work_schedules', 'hr.settings'],
  ),
  AdminDestination(
    id: 'hrLeave',
    label: S.hrLeave,
    icon: AppIcons.calendarAdd01,
    searchHint: S.searchHrLeaveHint,
    permission: 'hr.leave.review',
    section: S.sectionHr,
    tables: <String>[
      'hr.leave_requests',
      'hr.leave_types',
      'hr.leave_balances',
    ],
  ),
  AdminDestination(
    id: 'hrPayroll',
    label: S.hrPayroll,
    icon: AppIcons.receiptDollar,
    searchHint: S.searchHrPayrollHint,
    permission: 'hr.payroll.read',
    section: S.sectionHr,
    tables: <String>[
      'hr.payroll_runs',
      'hr.payroll_statements',
      'hr.payroll_line_items',
    ],
  ),
  AdminDestination(
    id: 'hrAdvances',
    label: S.hrAdvances,
    icon: AppIcons.coins01,
    searchHint: S.searchHrAdvancesHint,
    permission: 'hr.finance.adjust',
    section: S.sectionHr,
    tables: <String>['hr.salary_advances', 'hr.adjustments'],
  ),
  AdminDestination(
    id: 'hrDiscrepancies',
    label: S.hrDiscrepancies,
    icon: AppIcons.alert01,
    searchHint: S.searchHrDiscrepanciesHint,
    permission: 'hr.finance.adjust',
    section: S.sectionHr,
    tables: <String>['hr.cashier_discrepancies', 'payments.pos_shifts'],
  ),
  AdminDestination(
    id: 'hrSettings',
    label: S.hrSettings,
    icon: AppIcons.settings01,
    searchHint: S.searchHrSettingsHint,
    permission: 'hr.settings.manage',
    section: S.sectionHr,
    tables: <String>['hr.settings', 'hr.leave_types'],
  ),
];
