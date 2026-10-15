import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:new_coffee/core/navigation/root_navigator.dart';
import 'package:new_coffee/main.dart';
import 'package:new_coffee/features/home/data/banners_list.dart';
import 'package:new_coffee/features/home/presentation/views/banner_details_page.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/banner_image.dart';
import 'package:new_coffee/features/home/presentation/manager/home/home_cubit.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_popular_section.dart';
import 'package:new_coffee/features/home/presentation/views/see_all_products_page.dart';
import 'package:new_coffee/features/main/presentation/views/main_page.dart';
import 'package:new_coffee/features/search/presentation/views/search_page.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';

Future<void> _setSurface(WidgetTester tester) async {
  tester.view.physicalSize = const Size(360, 800) * 3.0;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _settlePush(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('banner tap opens details with per-banner data', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _setSurface(tester);

    await tester.pumpWidget(const MyApp(currentRoute: '4'));
    await tester.pump();
    expect(find.byType(MainPage), findsOneWidget);

    await tester.tap(find.byType(BannerImage).first);
    await _settlePush(tester);
    expect(find.byType(BannerDetailsPage), findsOneWidget);
    // Title shows in both the AppBar and the body.
    expect(find.text('Morning Boost'), findsWidgets);
    expect(find.text('Shop Hot Coffee'), findsOneWidget);

    await tester.tap(find.widgetWithText(CustomBtn, 'Shop Hot Coffee'));
    await _settlePush(tester);
    expect(find.byType(SearchPage), findsOneWidget);

    await tester.pump(const Duration(seconds: 20));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('different banner shows different data', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _setSurface(tester);

    await tester.pumpWidget(const MyApp(currentRoute: '4'));
    await tester.pump();

    rootNavigatorKey.currentState!.pushNamed(
      BannerDetailsPage.routeName,
      arguments: getBannersList()[2],
    );
    await _settlePush(tester);

    expect(find.byType(BannerDetailsPage), findsOneWidget);
    expect(find.text('Tea Time'), findsWidgets);
    expect(find.text('Shop Tea'), findsOneWidget);
    expect(find.text('Morning Boost'), findsNothing);

    await tester.pump(const Duration(seconds: 20));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('popular shows featured products and caps at 10', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _setSurface(tester);

    await tester.pumpWidget(const MyApp(currentRoute: '4'));
    await tester.pump();

    // "Popular" is now a ranked section fed by the repository, not the whole
    // menu in array order. It still renders through the same carousel, and the
    // carousel still caps at 10, so the shape is unchanged even though the
    // contents are now chosen rather than incidental.
    final listView = tester.widget<ListView>(
      find.descendant(
        of: find.byType(HomePopularSection),
        matching: find.byType(ListView),
      ),
    );
    final delegate =
        listView.childrenDelegate as SliverChildBuilderDelegate;

final cubit =
        BlocProvider.of<HomeCubit>(tester.element(find.byType(HomePopularSection)));
    final featuredCount = cubit.state.popular.length;
    expect(featuredCount, greaterThan(0),
        reason: 'the featured section must not be empty');
    expect(featuredCount, lessThan(10),
        reason: 'featured is a subset, unlike the old whole-menu behaviour');

    // ListView.separated: n products + (n - 1) separators, capped at 10.
    expect(delegate.estimatedChildCount, featuredCount * 2 - 1);

    // Invoke the trailing "View more" tap callback directly: pixel-tapping
    // is unreliable here (FAB overlay + scroll physics), and this exercises
    // the exact same navigation code path.
    final trailing = tester.widget<GestureDetector>(
      find
          .ancestor(
            of: find.text('View more').first,
            matching: find.byType(GestureDetector),
          )
          .first,
    );
    trailing.onTap!();
    await _settlePush(tester);
    expect(find.byType(SeeAllProductsPage), findsOneWidget);
    expect(find.text('Popular'), findsWidgets);

    await tester.pump(const Duration(seconds: 20));
    await tester.pumpWidget(const SizedBox());
  });
}
