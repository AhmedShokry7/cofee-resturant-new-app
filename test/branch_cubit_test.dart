import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:new_coffee/features/branch/data/repositories/branch_repository.dart';
import 'package:new_coffee/features/branch/presentation/manager/branch/branch_cubit.dart';

void main() {
  test('offline branches match the seeded branches in name order', () async {
    const repository = BranchRepositoryImpl();
    final branches = await repository.activeBranches();

    expect(branches.map((branch) => branch.code), ['MAIN', 'JEDDAH']);
    expect(
      branches.map((branch) => branch.nameEn),
      ['Main Branch', 'Jeddah Branch'],
    );
  });

  test('a stored branch is restored, but none is invented', () async {
    SharedPreferences.setMockInitialValues({
      'selected_branch_v1': '00000000-0000-4000-8000-000000000101',
    });

    final cubit = BranchCubit(repository: const BranchRepositoryImpl());
    await cubit.stream.firstWhere((state) => !state.isLoading);
    expect(cubit.state.selected?.code, 'MAIN');

    await cubit.select(cubit.state.branches.last);
    expect(cubit.state.selected?.code, 'JEDDAH');
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString('selected_branch_v1'),
      '00000000-0000-4000-8000-000000000102',
    );
    await cubit.close();
  });
}
