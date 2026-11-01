part of 'branch_cubit.dart';

@immutable
class BranchState {
  const BranchState({
    this.branches = const [],
    this.selected,
    this.isLoading = true,
    this.error,
  });

  final List<Branch> branches;
  final Branch? selected;
  final bool isLoading;
  final String? error;

  BranchState copyWith({
    List<Branch>? branches,
    Branch? selected,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) => BranchState(
    branches: branches ?? this.branches,
    selected: selected ?? this.selected,
    isLoading: isLoading ?? this.isLoading,
    error: clearError ? null : (error ?? this.error),
  );
}
