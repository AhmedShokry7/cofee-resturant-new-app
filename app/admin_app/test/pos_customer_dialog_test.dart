import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/theme_class.dart';
import 'package:admin_app/features/pos/domain/entities/pos_customer.dart';
import 'package:admin_app/features/pos/data/repositories/admin_pos_repository.dart';
import 'package:admin_app/features/pos/domain/repositories/pos_repository.dart';
import 'package:admin_app/features/pos/presentation/manager/pos_cubit.dart';
import 'package:admin_app/features/pos/presentation/widgets/pos_customer_dialog.dart';

const _registered = PosCustomer(
  id: 'c-reg',
  source: PosCustomerSource.registered,
  fullName: 'أحمد محمد',
  phone: '01000000001',
  isVip: true,
  ordersCount: 4,
);

const _walkIn = PosCustomer(
  id: 'c-walk',
  fullName: 'منى علي',
  phone: '01000000000',
  ordersCount: 2,
);

class _FakePosRepository extends AdminPosRepository {
  List<PosCustomer> results = const <PosCustomer>[_registered, _walkIn];
  PosCustomerException? searchError;
  PosCustomer? createResult;
  PosCustomerException? createError;
  int searchCalls = 0;
  String? lastQuery;
  int createCalls = 0;
  String? lastName;
  String? lastPhone;

  @override
  Future<List<PosCustomer>> searchCustomers({String? query}) async {
    searchCalls += 1;
    lastQuery = query;
    final error = searchError;
    if (error != null) throw error;
    return results;
  }

  @override
  Future<PosCustomer> createCustomer({
    required String fullName,
    String? phone,
    String? email,
    String? note,
  }) async {
    createCalls += 1;
    lastName = fullName;
    lastPhone = phone;
    final error = createError;
    if (error != null) throw error;
    return createResult ??
        PosCustomer(id: 'c-new', fullName: fullName, phone: phone);
  }
}

void _setViewport(WidgetTester tester, double width, double height) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<PosCustomer?> _open(
  WidgetTester tester,
  PosCubit cubit, {
  bool dark = false,
  TextDirection direction = TextDirection.ltr,
}) async {
  PosCustomer? selected;
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? ThemeClass.dark() : ThemeClass.light(),
      builder: (context, child) =>
          Directionality(textDirection: direction, child: child!),
      home: BlocProvider<PosCubit>.value(
        value: cubit,
        child: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  selected = await showPosCustomerDialog(context, cubit: cubit);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return selected;
}

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  testWidgets('the directory lists registered and counter customers', (
    tester,
  ) async {
    _setViewport(tester, 900, 900);
    final repository = _FakePosRepository();
    final cubit = PosCubit(repository: repository);
    addTearDown(cubit.close);

    await _open(tester, cubit);

    expect(tester.takeException(), isNull);
    expect(repository.searchCalls, 1);
    expect(repository.lastQuery, isEmpty);
    expect(find.text(S.posCustomerTitle), findsOneWidget);
    expect(find.text(S.posCustomerSubtitle), findsOneWidget);
    expect(find.text('أحمد محمد'), findsOneWidget);
    expect(find.text('منى علي'), findsOneWidget);
    expect(find.text(S.posCustomerRegistered), findsOneWidget);
    expect(find.text(S.posCustomerWalkIn), findsOneWidget);
    expect(find.text(S.posCustomerVip), findsOneWidget);
    expect(find.text(S.posCustomerOrders(4)), findsOneWidget);

    await tester.tap(find.text('منى علي'));
    await tester.pumpAndSettle();

    expect(cubit.state.customer!.id, 'c-walk');
    expect(find.text(S.posCustomerTitle), findsNothing);
  });

  testWidgets('a created counter customer is selected and returned', (
    tester,
  ) async {
    _setViewport(tester, 900, 900);
    final repository = _FakePosRepository();
    final cubit = PosCubit(repository: repository);
    addTearDown(cubit.close);

    await _open(tester, cubit);

    await tester.tap(find.text(S.posCustomerAddTab));
    await tester.pumpAndSettle();

    expect(find.text(S.posCustomerWalkInHint), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'سارة أحمد');
    await tester.enterText(find.byType(TextFormField).at(1), '01122233344');
    await tester.tap(find.byKey(const Key('pos-customer-save')));
    await tester.pumpAndSettle();

    expect(repository.createCalls, 1);
    expect(repository.lastName, 'سارة أحمد');
    expect(repository.lastPhone, '01122233344');
    expect(cubit.state.customer!.id, 'c-new');
    expect(cubit.state.customer!.fullName, 'سارة أحمد');
    expect(find.text(S.posCustomerTitle), findsNothing);
  });

  testWidgets('an empty name keeps the add form open with an error', (
    tester,
  ) async {
    _setViewport(tester, 900, 900);
    final repository = _FakePosRepository();
    final cubit = PosCubit(repository: repository);
    addTearDown(cubit.close);

    await _open(tester, cubit);

    await tester.tap(find.text(S.posCustomerAddTab));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pos-customer-save')));
    await tester.pumpAndSettle();

    expect(repository.createCalls, 0);
    expect(cubit.state.customer, isNull);
    expect(find.text(S.posCustomerNameRequired), findsOneWidget);
    expect(find.text(S.posCustomerTitle), findsOneWidget);
  });

  testWidgets('a failed search offers to retry or add the customer', (
    tester,
  ) async {
    _setViewport(tester, 900, 900);
    final repository = _FakePosRepository()
      ..searchError = const PosCustomerException(
        PosCustomerFailure.permissionDenied,
        'denied',
      );
    final cubit = PosCubit(repository: repository);
    addTearDown(cubit.close);

    await _open(tester, cubit);

    expect(find.text(S.posCustomerPermissionDenied), findsOneWidget);
    expect(find.text(S.retry), findsOneWidget);

    repository.searchError = null;
    await tester.tap(find.text(S.retry));
    await tester.pumpAndSettle();

    expect(repository.searchCalls, 2);
    expect(find.text('أحمد محمد'), findsOneWidget);
    expect(find.text(S.posCustomerPermissionDenied), findsNothing);
  });

  testWidgets('the dialog fits a narrow Arabic dark screen', (tester) async {
    AppLocale.instance.debugSet(AppLanguage.arabic);
    _setViewport(tester, 390, 844);
    final repository = _FakePosRepository();
    final cubit = PosCubit(repository: repository);
    addTearDown(cubit.close);

    await _open(tester, cubit, dark: true, direction: TextDirection.rtl);

    expect(tester.takeException(), isNull);
    expect(find.text(S.posCustomerTitle), findsOneWidget);
    expect(find.text(S.posCustomerSearchTab), findsOneWidget);
    expect(find.text(S.posCustomerAddTab), findsOneWidget);
    expect(find.text('أحمد محمد'), findsOneWidget);

    await tester.tap(find.text(S.posCustomerAddTab));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text(S.posCustomerWalkInHint), findsOneWidget);
    expect(find.byKey(const Key('pos-customer-save')), findsOneWidget);
  });
}
