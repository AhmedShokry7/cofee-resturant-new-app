import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/branch/data/model/branch_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Customer-facing branch list.
///
/// The database is authoritative. There is deliberately no seeded fallback:
/// fake branches would drive real pricing, availability and fulfilment.
abstract class BranchRepository {
  Future<List<Branch>> activeBranches();
}

class BranchRepositoryImpl implements BranchRepository {
  const BranchRepositoryImpl({SupabaseClient? client})
    : _clientOverride = client;

  final SupabaseClient? _clientOverride;

  SupabaseClient? get _client =>
      _clientOverride ??
      (SupabaseService.isReady ? SupabaseService.client : null);

  @override
  Future<List<Branch>> activeBranches() async {
    final client = _client;
    if (client == null) {
      throw StateError('Branches need a configured Supabase backend.');
    }

    final rows = await client.rpc('active_branches') as List;
    final branches = [
      for (final row in rows)
        if (row is Map<String, dynamic>) Branch.fromDatabase(row),
    ]..sort((a, b) => a.name.compareTo(b.name));
    return branches.where((branch) => branch.isActive).toList();
  }
}
