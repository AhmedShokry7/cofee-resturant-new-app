import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/branches/data/repositories/admin_branch_repository.dart';

/// The message the save dialog shows for a rejected save.
String branchSaveErrorMessage(BranchSaveOutcome outcome) => switch (outcome) {
  BranchSaveOutcome.saved => '',
  BranchSaveOutcome.duplicateCode => S.branchSaveDuplicateCode,
  BranchSaveOutcome.invalidCode => S.branchSaveInvalidCode,
  BranchSaveOutcome.invalidName => S.branchNeedsName,
  BranchSaveOutcome.invalidAddress => S.branchNeedsAddress,
  BranchSaveOutcome.invalidHours => S.branchInvalidHours,
  BranchSaveOutcome.invalidLocation => S.branchInvalidLocation,
  BranchSaveOutcome.invalidVatNumber => S.branchInvalidVatNumber,
  BranchSaveOutcome.invalidLegalName => S.branchInvalidLegalName,
  BranchSaveOutcome.noBrand => S.branchNoBrand,
  BranchSaveOutcome.notFound => S.branchNotFound,
  BranchSaveOutcome.permissionDenied => S.branchPermissionDenied,
  BranchSaveOutcome.failed => S.branchSaveFailed,
};

/// The message shown when a branch action is rejected.
String branchMutationErrorMessage(BranchMutationOutcome outcome) =>
    switch (outcome) {
      BranchMutationOutcome.success => '',
      BranchMutationOutcome.notFound => S.branchNotFound,
      BranchMutationOutcome.hasOrders => S.branchHasOrders,
      BranchMutationOutcome.hasUsage => S.branchHasUsage,
      BranchMutationOutcome.hasStaff => S.branchHasStaff,
      BranchMutationOutcome.lastActive => S.branchLastActive,
      BranchMutationOutcome.inUse => S.branchInUse,
      BranchMutationOutcome.invalidUrl => S.branchInvalidImageUrl,
      BranchMutationOutcome.permissionDenied => S.branchPermissionDenied,
      BranchMutationOutcome.failed => S.branchMutationFailed,
    };
