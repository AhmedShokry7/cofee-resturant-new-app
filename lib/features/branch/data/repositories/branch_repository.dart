import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/branch/data/model/branch_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Customer-facing branch list.
///
/// The database is authoritative when configured. Offline builds fall back to
/// the seeded branches so branch-dependent screens keep working.
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
    if (client == null) return [..._localBranches]..sort(_byName);

    try {
      final rows = await client.rpc('active_branches') as List;
      final branches = [
        for (final row in rows)
          if (row is Map<String, dynamic>) Branch.fromDatabase(row),
      ]..sort((a, b) => a.name.compareTo(b.name));
      return branches.where((branch) => branch.isActive).toList();
    } catch (_) {
      return [..._localBranches]..sort(_byName);
    }
  }

  static int _byName(Branch a, Branch b) => a.name.compareTo(b.name);

  static const List<Branch> _localBranches = [
    Branch(
      id: '00000000-0000-4000-8000-000000000101',
      code: 'MAIN',
      nameAr: 'الفرع الرئيسي',
      nameEn: 'Main Branch',
      address: 'شارع الملك فهد، العليا، الرياض',
      addressAr: 'شارع الملك فهد، العليا، الرياض',
      addressEn: 'King Fahd Road, Olaya, Riyadh',
      phone: '+966500000001',
    ),
    Branch(
      id: '00000000-0000-4000-8000-000000000102',
      code: 'JEDDAH',
      nameAr: 'فرع جدة',
      nameEn: 'Jeddah Branch',
      address: 'شارع التحلية، حي الروضة، جدة',
      addressAr: 'شارع التحلية، حي الروضة، جدة',
      addressEn: 'Tahlia Street, Al Rawdah, Jeddah',
      phone: '+966500000002',
    ),
  ];
}
