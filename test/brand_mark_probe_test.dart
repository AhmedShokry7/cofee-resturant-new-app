import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:new_coffee/features/design/presentation/manager/design/design_cubit.dart';
import 'package:new_coffee/features/design/presentation/manager/design/design_state.dart';
import 'package:new_coffee/features/design/data/model/published_design.dart';
import 'package:new_coffee/features/splash/presentation/views/widgets/splash_brand_mark.dart';
import 'package:new_coffee/shared/widgets/db_image.dart';
import 'support/fake_design_repository.dart';

void main() {
  testWidgets('shows DbImage when brand has logoUrl', (tester) async {
    const design = PublishedDesign(
      schemaVersion: 2,
      theme: PublishedTheme(logoUrl: 'https://example.com/logo.png'),
      homeSections: <PublishedSection>[],
      categoriesSections: <PublishedSection>[],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<DesignCubit>(
              create: (_) => DesignCubit(repository: FakeDesignRepository(design)),
            ),
          ],
          child: const Scaffold(body: Center(child: SplashBrandMark())),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(DbImage), findsOneWidget);
    print('PASS-DBIMAGE');
  });

  testWidgets('falls back to asset when no logoUrl', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<DesignCubit>(
              create: (_) => DesignCubit(repository: FakeDesignRepository(null)),
            ),
          ],
          child: const Scaffold(body: Center(child: SplashBrandMark())),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(DbImage), findsNothing);
    print('PASS-FALLBACK');
  });
}
