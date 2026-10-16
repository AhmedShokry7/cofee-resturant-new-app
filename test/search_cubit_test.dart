import 'package:flutter_test/flutter_test.dart';
import 'package:new_coffee/features/menu/data/repositories/mock_product_repository.dart';
import 'package:new_coffee/features/search/presentation/manager/search/search_cubit.dart';

/// Search page states: idle prompt before searching, results after a hit,
/// "no results" after a miss, and back to idle when the field is cleared.
void main() {
  SearchCubit create() =>
      SearchCubit(catalogRepository: MockProductRepository(), branchId: null);

  Future<SearchState> searched(SearchCubit cubit) =>
      cubit.stream.firstWhere((s) => s.hasSearched && !s.isLoading);

  test('opening search shows the idle prompt, not "no results"', () {
    final cubit = create();
    expect(cubit.state.hasSearched, isFalse);
    expect(cubit.state.isEmptyResult, isFalse);
    expect(cubit.state.results, isEmpty);
    cubit.close();
  });

  test('searching finds matches and marks the page searched', () async {
    final cubit = create();
    cubit.search('latte');
    final state = await searched(cubit);
    expect(state.hasSearched, isTrue);
    expect(state.results, isNotEmpty);
    expect(state.isEmptyResult, isFalse);
    await cubit.close();
  });

  test('a miss reports an empty result, not an idle page', () async {
    final cubit = create();
    cubit.search('zzz-no-such-drink');
    final state = await searched(cubit);
    expect(state.hasSearched, isTrue);
    expect(state.results, isEmpty);
    expect(state.isEmptyResult, isTrue);
    expect(state.error, isNull);
    await cubit.close();
  });

  test('clearing the field returns to the idle prompt', () async {
    final cubit = create();
    cubit.search('latte');
    await searched(cubit);

    cubit.search('');
    // The reset is synchronous: no round trip, no stale results.
    expect(cubit.state.hasSearched, isFalse);
    expect(cubit.state.results, isEmpty);
    expect(cubit.state.isEmptyResult, isFalse);
    await cubit.close();
  });
}
