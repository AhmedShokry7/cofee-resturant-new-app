import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/branch/data/model/branch_model.dart';
import 'package:new_coffee/features/branch/presentation/manager/branch/branch_cubit.dart';
import 'package:new_coffee/core/theme/tokens.dart';

/// Branch picker shown in the home header.
///
/// D1 makes the branch an explicit customer choice, so this never silently
/// defaults to the first branch. Until one is chosen, branch-specific prices
/// and availability stay on their base values.
class BranchSelector extends StatelessWidget {
  const BranchSelector({super.key});

  @override
  Widget build(BuildContext context) {
    try {
      context.read<BranchCubit>();
    } catch (_) {
      // Isolated widget tests and previews may render the header without the
      // global branch provider. The selector is optional chrome there.
      return const SizedBox.shrink();
    }
    return BlocBuilder<BranchCubit, BranchState>(
      builder: (context, state) {
        final selected = state.selected;
        return GestureDetector(
          onTap: state.branches.isEmpty ? null : () => _choose(context, state),
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: AppColor.lightGreyColor,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  AppIcons.store,
                  size: AppSpacing.lg,
                  color: AppColor.primaryColor,
                ),
                SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    state.isLoading ? '…' : selected?.name ?? S.chooseBranch,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.medium12(context).copyWith(
                      color: selected == null
                          ? AppColor.greyColor
                          : AppColor.blackColor,
                    ),
                  ),
                ),
                Icon(
                  AppIcons.arrowDown,
                  size: AppSpacing.lg,
                  color: AppColor.greyColor,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _choose(BuildContext context, BranchState state) async {
    final cubit = context.read<BranchCubit>();
    final chosen = await showModalBottomSheet<Branch?>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final branch in state.branches)
              ListTile(
                title: Text(branch.name),
                subtitle: branch.address == null ? null : Text(branch.address!),
                trailing: branch.id == state.selected?.id
                    ? Icon(AppIcons.checkmark, color: AppColor.primaryColor)
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(branch),
              ),
          ],
        ),
      ),
    );
    if (chosen != null) await cubit.select(chosen);
  }
}
