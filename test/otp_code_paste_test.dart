import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:new_coffee/features/auth/data/repositories/auth_repository.dart';
import 'package:new_coffee/features/auth/presentation/manager/phone_auth/phone_auth_cubit.dart';
import 'package:new_coffee/features/auth/presentation/views/widgets/otp_page_body.dart';

/// An SMS code arrives as one string, into whichever box is focused.
///
/// Clipping every box to a single character used to discard the rest of it, so
/// the code the customer pasted correctly could never be verified.
class _UnusedAuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('The code boxes are tested without a backend.');
}

Finder _cell(int index) => find.byType(TextFormField).at(index);

List<String> _cells(WidgetTester tester) => tester
    .widgetList<TextFormField>(find.byType(TextFormField))
    .map((field) => field.controller!.text)
    .toList();

void main() {
  Future<void> pumpCodeScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 690);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider(
            create: (context) => PhoneAuthCubit(_UnusedAuthRepository()),
            child: const OtpPageBody(phone: '+20123456789'),
          ),
        ),
      ),
    );
  }

  testWidgets('a whole code pasted into the first box fills every box', (
    tester,
  ) async {
    await pumpCodeScreen(tester);

    await tester.enterText(_cell(0), '481926');
    await tester.pump();

    expect(_cells(tester), ['4', '8', '1', '9', '2', '6']);
  });

  testWidgets('a code pasted mid-way fills forward, not nowhere', (
    tester,
  ) async {
    await pumpCodeScreen(tester);

    await tester.enterText(_cell(0), '12');
    await tester.pump();
    await tester.enterText(_cell(3), '3456');
    await tester.pump();

    expect(_cells(tester), ['1', '2', '', '3', '4', '5']);
  });

  testWidgets('a short paste does not spill past the last box', (tester) async {
    await pumpCodeScreen(tester);

    await tester.enterText(_cell(4), '789');
    await tester.pump();

    expect(_cells(tester), ['', '', '', '', '7', '8']);
  });

  testWidgets('typing one digit still walks forward a box at a time', (
    tester,
  ) async {
    await pumpCodeScreen(tester);

    await tester.enterText(_cell(0), '4');
    await tester.pump();

    await tester.enterText(_cell(1), '8');
    await tester.pump();

    expect(_cells(tester)[0], '4');
    expect(_cells(tester)[1], '8');
  });
}
