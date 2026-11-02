import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/theme/tokens.dart';
import 'package:new_coffee/features/auth/data/repositories/auth_repository.dart';
import 'package:new_coffee/features/auth/presentation/manager/auth/auth_cubit.dart';
import 'package:new_coffee/features/auth/presentation/views/widgets/login_page_body.dart';
import 'package:new_coffee/features/auth/presentation/views/widgets/sign_up_page_body.dart';
import 'package:new_coffee/shared/widgets/custom_text_form_field.dart';

import 'support/pump_harness.dart';

/// The screens are looked at, never submitted to.
class _UnusedAuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName} was called');
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpScreen(WidgetTester tester, Widget body) async {
    tester.view.physicalSize = phoneViewport;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      BlocProvider<AuthCubit>(
        create: (context) => AuthCubit(_UnusedAuthRepository()),
        child: MaterialApp(
          locale: const Locale('ar'),
          home: Scaffold(body: body),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The theme the field wrapped its own glyph in - the proof of what the
  /// widget decided, not what the screen asked for.
  IconThemeData glyphTheme(WidgetTester tester, IconData icon) {
    final found = find.ancestor(
      of: find.byIcon(icon),
      matching: find.byType(IconTheme),
    );
    expect(found, findsWidgets, reason: 'no $icon is drawn inside a field');
    return tester.widget<IconTheme>(found.first).data;
  }

  group('one glyph, one rule', () {
    testWidgets('the sign-in fields each say what they hold', (tester) async {
      await pumpScreen(tester, const LoginPageBody());

      expect(find.byIcon(AppIcons.mail), findsOneWidget);
      expect(find.byIcon(AppIcons.lock), findsOneWidget);
    });

    testWidgets('the field, not the screen, sets the size', (tester) async {
      await pumpScreen(tester, const LoginPageBody());

      expect(glyphTheme(tester, AppIcons.mail).size, AppIconSize.field);
      expect(glyphTheme(tester, AppIcons.lock).size, AppIconSize.field);
    });

    testWidgets('and the resting glyph is the resting grey', (tester) async {
      await pumpScreen(tester, const LoginPageBody());

      expect(glyphTheme(tester, AppIcons.mail).color, AppColor.greyColor);
    });

    testWidgets('a focused field colours its own glyph', (tester) async {
      await pumpScreen(tester, const LoginPageBody());

      await tester.tap(find.byType(TextField).first);
      await tester.pumpAndSettle();

      expect(glyphTheme(tester, AppIcons.mail).color, AppColor.secondryColor);
      expect(
        glyphTheme(tester, AppIcons.lock).color,
        AppColor.greyColor,
        reason: 'only the field under the finger lights up',
      );
    });
  });

  group('the forms agree with each other', () {
    testWidgets('sign-up carries the same four glyphs at the same size', (
      tester,
    ) async {
      await pumpScreen(tester, const SignUpPageBody());

      expect(find.byIcon(AppIcons.user), findsOneWidget);
      expect(find.byIcon(AppIcons.mail), findsOneWidget);
      expect(find.byIcon(AppIcons.lock), findsNWidgets(2));
      for (final icon in [AppIcons.user, AppIcons.mail, AppIcons.lock]) {
        expect(glyphTheme(tester, icon).size, AppIconSize.field);
      }
    });

    testWidgets('a glyph costs the box no height', (tester) async {
      await pumpScreen(tester, const LoginPageBody());
      final signInField = tester.getSize(
        find.byType(CustomTextFormField).first,
      );

      await pumpScreen(tester, const SignUpPageBody());
      final signUpField = tester.getSize(
        find.byType(CustomTextFormField).first,
      );

      expect(
        signUpField.height,
        signInField.height,
        reason:
            'every field on every screen has to be the same box, with or '
            'without a glyph in front of the text',
      );
    });

    testWidgets('the hint still sits after the glyph, not under it', (
      tester,
    ) async {
      await pumpScreen(tester, const LoginPageBody());

      final glyph = tester.getRect(find.byIcon(AppIcons.mail));
      final hint = tester.getRect(find.text(S.emailHint));

      final clear = hint.left >= glyph.right || glyph.left >= hint.right;
      expect(
        clear,
        isTrue,
        reason:
            'the glyph keeps its own slot in front of the text - whichever '
            'way the line reads, the two must not sit on top of each other',
      );
    });
  });
}
