import 'package:material_ui/material_ui.dart' show TextField;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/services/supabase_service.dart';
import 'package:admin_app/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AppLocale.instance.debugSet(AppLanguage.arabic);
    SupabaseService.debugReset();
  });

  tearDown(() {
    AppLocale.instance.debugSet(AppLanguage.english);
    SupabaseService.debugReset();
  });

  testWidgets('Arabic login screen has matching Material localizations', (
    tester,
  ) async {
    await tester.pumpWidget(const AdminApp());
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
