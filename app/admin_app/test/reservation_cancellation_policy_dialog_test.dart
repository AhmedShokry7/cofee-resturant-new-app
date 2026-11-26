import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:admin_app/core/models/admin_branch.dart';
import 'package:admin_app/features/branches/data/repositories/reservation_cancellation_policy_repository.dart';
import 'package:admin_app/features/branches/presentation/widgets/reservation_cancellation_policy_dialog.dart';

class FakePolicyRepository extends ReservationCancellationPolicyRepository {
  bool failLoad = false;
  List<Object>? saved;
  @override
  Future<Map<String, dynamic>> load(String branchId) async {
    if (failLoad) throw StateError('offline');
    return {
      'ok': true,
      'table_cutoff_minutes': 120,
      'event_cutoff_minutes': 2880,
    };
  }

  @override
  Future<void> save(String branchId, int tableMinutes, int eventMinutes) async {
    saved = [branchId, tableMinutes, eventMinutes];
  }
}

void main() {
  Future<void> open(
    WidgetTester tester,
    FakePolicyRepository repository,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => ReservationCancellationPolicyDialog(
                  branch: const AdminBranch(
                    id: 'branch',
                    code: 'B',
                    nameAr: 'فرع',
                    nameEn: 'Branch',
                    address: 'Address',
                  ),
                  repository: repository,
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('loads hours and saves Arabic hour/day values as minutes', (
    tester,
  ) async {
    final repository = FakePolicyRepository();
    await open(tester, repository);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      '2.0',
    );
    expect(
      tester.widget<TextField>(find.byType(TextField).last).controller!.text,
      '48.0',
    );
    await tester.enterText(find.byType(TextField).first, '١');
    await tester.enterText(find.byType(TextField).last, '٢٤');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(repository.saved, ['branch', 60, 1440]);
    expect(find.byType(ReservationCancellationPolicyDialog), findsNothing);
  });

  testWidgets('load failure cannot overwrite policy with defaults', (
    tester,
  ) async {
    final repository = FakePolicyRepository()..failLoad = true;
    await open(tester, repository);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(repository.saved, isNull);
  });

  testWidgets('nonfinite input is rejected before save', (tester) async {
    final repository = FakePolicyRepository();
    await open(tester, repository);
    await tester.enterText(find.byType(TextField).first, 'NaN');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(repository.saved, isNull);
    expect(tester.takeException(), isNull);
  });
}
