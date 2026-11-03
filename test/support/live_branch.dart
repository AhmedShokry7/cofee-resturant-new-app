import 'package:new_coffee/features/branch/data/repositories/branch_repository.dart';

/// The branch a real customer of this project would be browsing.
///
/// Integration tests used to hardcode the demo seed's branch uuid
/// (`00000000-0000-4000-8000-000000000101`), which no live project has: every
/// branch-scoped read then resolved against a branch that does not exist, so it
/// proved nothing about pricing or availability. Resolving through
/// [BranchRepositoryImpl] is the same read the branch picker performs, and
/// `null` means the project genuinely has no active branch - a fact the test
/// reports rather than papers over.
Future<String?> liveBranchId() async {
  final branches = await const BranchRepositoryImpl().activeBranches();
  return branches.isEmpty ? null : branches.first.id;
}
