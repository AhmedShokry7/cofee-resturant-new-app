import 'package:flutter_test/flutter_test.dart';
import 'package:admin_app/features/hr/settings/hr_settings_cubit.dart';
import 'package:admin_app/features/hr/settings/hr_settings_repository.dart';

class _SettingsRepository implements HrSettingsRepository {
  Map<String, dynamic> values = {
    'business_time_zone': 'Asia/Riyadh',
    'late_grace_minutes': 5,
    'late_minute_rate': null,
    'cashier_deduction_allowed': false,
  };
  double? savedLateRate;
  int? savedGrace;

  @override
  Future<Map<String, dynamic>> load() async => values;

  @override
  Future<void> save({
    required String timeZone,
    required int graceMinutes,
    double? lateRate,
    double? earlyRate,
    double? absenceRate,
    required bool cashierDeductions,
    double? deductionCap,
    double? unpaidLeaveRate,
  }) async {
    savedLateRate = lateRate;
    savedGrace = graceMinutes;
    values = {
      ...values,
      'business_time_zone': timeZone,
      'late_grace_minutes': graceMinutes,
      'cashier_deduction_allowed': cashierDeductions,
    };
  }
}

void main() {
  test(
    'loads current settings and keeps withheld policy fields nullable',
    () async {
      final repository = _SettingsRepository();
      final cubit = HrSettingsCubit(repository: repository);
      await cubit.load();

      expect(cubit.state.status, HrSettingsStatus.ready);
      expect(cubit.state.values['business_time_zone'], 'Asia/Riyadh');
      expect(cubit.state.values['late_minute_rate'], isNull);
      await cubit.close();
    },
  );

  test(
    'saves editable values while blank protected rates remain unchanged',
    () async {
      final repository = _SettingsRepository();
      final cubit = HrSettingsCubit(repository: repository);
      await cubit.load();
      final saved = await cubit.save(
        timeZone: 'Asia/Riyadh',
        graceMinutes: 10,
        cashierDeductions: false,
      );

      expect(saved, isTrue);
      expect(repository.savedGrace, 10);
      expect(repository.savedLateRate, isNull);
      expect(cubit.state.values['late_minute_rate'], isNull);
      await cubit.close();
    },
  );
}
