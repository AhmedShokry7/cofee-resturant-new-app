import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/services/shared_pref.dart';
import 'package:new_coffee/features/branch/data/model/branch_model.dart';
import 'package:new_coffee/features/branch/data/repositories/branch_repository.dart';

part 'branch_state.dart';

/// Remembers the customer's selected branch and reloads it on startup.
///
/// A saved choice is restored when it is still active. When exactly one active
/// branch exists, it is selected and persisted automatically; multiple
/// branches still require an explicit customer choice.
class BranchCubit extends Cubit<BranchState> {
  BranchCubit({required this._repository}) : super(const BranchState()) {
    load();
  }

  final BranchRepository _repository;

  static const _storageKey = 'selected_branch_v1';

  Future<void> load() async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      // The remembered choice and the list of branches are independent reads,
      // so both are asked for before either is waited on: the start-up wait is
      // the longer of the two instead of their sum.
      final branchesFuture = _repository.activeBranches();
      final storedFuture = SharedPref.getValue(key: _storageKey);
      final branches = await branchesFuture;
      final storedId = await storedFuture;
      Branch? selected;
      if (storedId != null && storedId.isNotEmpty) {
        for (final branch in branches) {
          if (branch.id == storedId) selected = branch;
        }
      }
      selected ??= branches.length == 1 ? branches.single : null;
      if (isClosed) return;
      emit(
        state.copyWith(
          branches: branches,
          selected: selected,
          clearSelected: selected == null,
          isLoading: false,
        ),
      );
      if (selected != null && selected.id != storedId) {
        try {
          await SharedPref.setValue(key: _storageKey, value: selected.id);
        } catch (_) {
          // The one-branch choice still applies for this session if storage fails.
        }
      }
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
