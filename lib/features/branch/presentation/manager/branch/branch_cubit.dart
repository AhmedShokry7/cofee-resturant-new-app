import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/services/shared_pref.dart';
import 'package:new_coffee/features/branch/data/model/branch_model.dart';
import 'package:new_coffee/features/branch/data/repositories/branch_repository.dart';

part 'branch_state.dart';

/// Remembers the customer's selected branch and reloads it on startup.
///
/// Nothing is auto-selected: D1 requires the customer to choose. Prices shown
/// without a branch are base prices, and branch-specific data stays unloaded
/// until a choice exists.
class BranchCubit extends Cubit<BranchState> {
  BranchCubit({required this._repository}) : super(const BranchState()) {
    load();
  }

  final BranchRepository _repository;

  static const _storageKey = 'selected_branch_v1';

  Future<void> load() async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final branches = await _repository.activeBranches();
      final storedId = await SharedPref.getValue(key: _storageKey);
      Branch? selected;
      if (storedId != null && storedId.isNotEmpty) {
        for (final branch in branches) {
          if (branch.id == storedId) selected = branch;
        }
      }
      if (isClosed) return;
      emit(
        state.copyWith(
          branches: branches,
          selected: selected,
          isLoading: false,
        ),
      );
    } catch (error, stackTrace) {
      if (isClosed) return;
      emit(state.copyWith(isLoading: false, error: error.toString()));
      addError(error, stackTrace);
    }
  }

  Future<void> select(Branch? branch) async {
    emit(state.copyWith(selected: branch, clearError: true));
    try {
      await SharedPref.setValue(key: _storageKey, value: branch?.id ?? '');
    } catch (_) {
      // Selection still applies for this session if storage fails.
    }
  }
}
