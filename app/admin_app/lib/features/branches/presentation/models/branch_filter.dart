import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/models/admin_branch.dart';

enum BranchFilter {
  all,
  active,
  inactive,
  needsSetup;

  bool matches(AdminBranch branch) => switch (this) {
    BranchFilter.all => true,
    BranchFilter.active => branch.isActive,
    BranchFilter.inactive => !branch.isActive,
    BranchFilter.needsSetup => branch.needsSetup,
  };

  String get label => switch (this) {
    BranchFilter.all => S.branchesFilterAll,
    BranchFilter.active => S.active,
    BranchFilter.inactive => S.inactive,
    BranchFilter.needsSetup => S.branchesFilterNeedsSetup,
  };
}

/// The branches whose name, code, address or phone holds [search] and that
/// pass [filter].
List<AdminBranch> filterBranches(
  List<AdminBranch> branches, {
  required String search,
  required BranchFilter filter,
}) {
  final query = search.trim().toLowerCase();
  return branches
      .where((branch) {
        if (!filter.matches(branch)) return false;
        if (query.isEmpty) return true;
        return branch.nameAr.toLowerCase().contains(query) ||
            branch.nameEn.toLowerCase().contains(query) ||
            branch.code.toLowerCase().contains(query) ||
            branch.address.toLowerCase().contains(query) ||
            (branch.phone ?? '').toLowerCase().contains(query);
      })
      .toList(growable: false);
}
