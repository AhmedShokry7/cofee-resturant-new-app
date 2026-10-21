import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:admin_app/core/constants/app_images.dart';
import 'package:admin_app/core/theme/app_theme.dart';
import 'package:admin_app/features/shell/presentation/models/admin_search_controller.dart';
import 'package:admin_app/features/shell/presentation/widgets/admin_app_bar.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AppTheme.instance.debugSet(AppThemeMode.system);
  });

  testWidgets('admin app bar shows the page title and per-page search hint', (
    tester,
  ) async {
    final searchController = AdminSearchController();
    final textController = TextEditingController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AdminAppBar(
            title: 'Dashboard',
            searchHint: 'Search orders and customers...',
            searchController: searchController,
            searchTextController: textController,
            isCompact: false,
          ),
        ),
      ),
    );

    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Search orders and customers...'), findsOneWidget);
    expect(find.byIcon(HugeIcons.strokeRoundedTranslate), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName == AppImages.sun,
      ),
      findsOneWidget,
    );

    searchController.dispose();
    textController.dispose();
  });

  testWidgets('compact app bar keeps the search field on its own row', (
    tester,
  ) async {
    final searchController = AdminSearchController();
    final textController = TextEditingController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AdminAppBar(
            title: 'Customers',
            searchHint: 'Search customers',
            searchController: searchController,
            searchTextController: textController,
            isCompact: true,
            leading: IconButton(icon: const Icon(Icons.menu), onPressed: () {}),
          ),
        ),
      ),
    );

    expect(find.text('Customers'), findsOneWidget);
    expect(find.text('Search customers'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    searchController.dispose();
    textController.dispose();
  });

  testWidgets('typing in the app bar search updates the controller', (
    tester,
  ) async {
    final searchController = AdminSearchController();
    final textController = TextEditingController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AdminAppBar(
            title: 'Orders',
            searchHint: 'Search orders',
            searchController: searchController,
            searchTextController: textController,
            isCompact: false,
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'order-1024');
    await tester.pump();

    expect(searchController.query, 'order-1024');
    expect(find.byIcon(HugeIcons.strokeRoundedCancel01), findsOneWidget);

    searchController.dispose();
    textController.dispose();
  });

  testWidgets('tapping the theme button switches between sun and moon', (
    tester,
  ) async {
    final searchController = AdminSearchController();
    final textController = TextEditingController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AdminAppBar(
            title: 'Settings',
            searchHint: 'Search settings',
            searchController: searchController,
            searchTextController: textController,
            isCompact: false,
          ),
        ),
      ),
    );

    Finder imageAsset(String asset) => find.byWidgetPredicate(
      (widget) =>
          widget is Image &&
          widget.image is AssetImage &&
          (widget.image as AssetImage).assetName == asset,
    );

    expect(imageAsset(AppImages.sun), findsOneWidget);
    await tester.tap(imageAsset(AppImages.sun));
    await tester.pumpAndSettle();
    expect(imageAsset(AppImages.moon), findsOneWidget);

    searchController.dispose();
    textController.dispose();
  });
}
