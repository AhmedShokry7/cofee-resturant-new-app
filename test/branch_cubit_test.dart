import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:new_coffee/features/branch/data/model/branch_model.dart';
import 'package:new_coffee/features/branch/data/repositories/branch_repository.dart';
import 'package:new_coffee/features/branch/presentation/manager/branch/branch_cubit.dart';

/// Branches come from the database only. The old repository invented a seeded
/// MAIN/JEDDAH list offline; that fallback was removed on purpose so a fake
/// branch can never drive real pricing and fulfilment.
const _main = Branch(
  id: '00000000-0000-4000-8000-000000000101',
  code: 'MAIN',
  nameAr: 'الفرع الرئيسي',
  nameEn: 'Main Branch',
);
const _jeddah = Branch(
  id: '00000000-0000-4000-8000-000000000102',
  code: 'JEDDAH',
  nameAr: 'فرع جدة',
  nameEn: 'Jeddah Branch',
);

class _FakeBranchRepository implements BranchRepository {
  const _FakeBranchRepository(this._branches);

  final List<Branch> _branches;

  @override
  Future<List<Branch>> activeBranches() async => _branches;
}

void main() {
  test('customer branch keeps the admin-saved address and map coordinates', () {
    final branch = Branch.fromDatabase({
      'id': 'branch-id',
      'code': 'MAIN',
      'name_ar': 'الفرع الرئيسي',
      'name_en': 'Main Branch',
      'address': 'شارع الملك فهد، الرياض',
      'address_ar': 'شارع الملك فهد، الرياض',
      'address_en': 'King Fahd Road, Riyadh',
      'latitude': '24.7136',
      'longitude': 46.6753,
    });

    expect(branch.latitude, 24.7136);
    expect(branch.longitude, 46.6753);
    expect(branch.addressAr, 'شارع الملك فهد، الرياض');
    expect(branch.addressEn, 'King Fahd Road, Riyadh');
  });

  test('without a backend the branch list is not invented', () async {
    const repository = BranchRepositoryImpl();
    await expectLater(repository.activeBranches(), throwsA(isA<StateError>()));
  });

  test('a stored branch is restored, but none is invented', () async {
    SharedPreferences.setMockInitialValues({'selected_branch_v1': _main.id});

    final cubit = BranchCubit(
      repository: const _FakeBranchRepository([_main, _jeddah]),
    );
    await cubit.stream.firstWhere((state) => !state.isLoading);
    expect(cubit.state.selected?.code, 'MAIN');

    await cubit.select(cubit.state.branches.last);
    expect(cubit.state.selected?.code, 'JEDDAH');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('selected_branch_v1'), _jeddah.id);
    await cubit.close();
  });

  test('no stored branch selects nothing rather than a default', () async {
    SharedPreferences.setMockInitialValues({});

    final cubit = BranchCubit(
      repository: const _FakeBranchRepository([_main, _jeddah]),
    );
    await cubit.stream.firstWhere((state) => !state.isLoading);
    expect(cubit.state.branches.length, 2);
    expect(cubit.state.selected, isNull);
    await cubit.close();
  });
}
