import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/categories/data/model/category_model.dart';
import 'support/mock_product_repository.dart';
import 'package:new_coffee/features/search/presentation/manager/search/search_cubit.dart';
import 'package:new_coffee/features/search/presentation/views/widgets/search_filter_sheet.dart';

/// The offline catalogue with its category read held open, so a test can show
/// what the sheet renders while the categories are still on their way.
class _GatedCatalog extends MockProductRepository {
  _GatedCatalog();

  final _gate = Completer<List<CategoryModel>>();

  @override
  Future<List<CategoryModel>> getCategories({bool includeInactive = false}) =>
      _gate.future;

  void release(List<CategoryModel> rows) {
    if (!_gate.isCompleted) _gate.complete(rows);
  }
}

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.arabic));

  testWidgets('the filter sheet takes categories that arrive late', (
    tester,
  ) async {
    final catalog = _GatedCatalog();
    final cubit = SearchCubit(catalogRepository: catalog, branchId: null);
    addTearDown(cubit.close);

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(360, 800),
        builder: (context, _) => MaterialApp(
          home: BlocProvider<SearchCubit>.value(
            value: cubit,
            child: const Scaffold(body: SearchFilterSheet()),
          ),
        ),
      ),
    );
    await tester.pump();

    // The categories are still in flight, so the sheet offers only "All".
    expect(find.text(S.all), findsOneWidget);
    expect(find.text('عصائر'), findsNothing);

    catalog.release(const [
      CategoryModel(
        label: 'عصائر',
        icon: Icons.local_drink_outlined,
        id: 'c-1',
      ),
    ]);
    await tester.pump();
    await tester.pump();

    // Reading the cubit once in build used to freeze this row at whatever the
    // first frame held — an empty list — so the chip never appeared.
    expect(find.text('عصائر'), findsOneWidget);
    expect(find.text(S.all), findsOneWidget);
  });
}
