import 'package:new_coffee/shared/widgets/refresh_on_return.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/theme/tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/loyalty/data/model/loyalty_transaction.dart';
import 'package:new_coffee/features/loyalty/presentation/manager/loyalty/loyalty_cubit.dart';
import 'package:new_coffee/shared/widgets/empty_state.dart';
import 'package:new_coffee/shared/widgets/app_back_button.dart';

class LoyaltyHistoryPage extends StatelessWidget {
  const LoyaltyHistoryPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(leading: const AppBackButton(), title: Text(S.history)),
    body: BlocBuilder<LoyaltyCubit, LoyaltyState>(
      builder: (context, state) {
        if (state.isLoading && state.transactions.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.error != null && state.transactions.isEmpty) {
          return EmptyState(
            icon: AppIcons.gift,
            title: S.couldNotLoadLoyalty,
            actionLabel: S.retry,
            onAction: () => context.read<LoyaltyCubit>().load(),
          );
        }
        if (state.transactions.isEmpty) {
          return Center(child: Text(S.loyaltyNoHistory));
        }
        return RefreshOnReturn(
          onRefresh: context.read<LoyaltyCubit>().load,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: AppLayout.pageBody,
            itemCount:
                state.transactions.length + (state.hasMoreTransactions ? 1 : 0),
            separatorBuilder: (_, _) => SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              if (index == state.transactions.length) {
                return Padding(
                  padding: EdgeInsets.only(top: AppSpacing.sm),
                  child: CustomOutlinedButton.icon(
                    onPressed: state.isLoadingMoreTransactions
                        ? null
                        : () => context
                              .read<LoyaltyCubit>()
                              .loadMoreTransactions(),
                    icon: state.isLoadingMoreTransactions
                        ? SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: AppSizes.px2,
                            ),
                          )
                        : const Icon(AppIcons.arrowDown),
                    label: Text(S.loyaltyLoadMoreHistory),
                  ),
                );
              }
              return _HistoryEntry(transaction: state.transactions[index]);
            },
          ),
        );
      },
    ),
  );
}

/// Local date and time as `yyyy/MM/dd hh:mm`, matching the rest of the app.
String _formatWhen(DateTime date) {
  final d = date.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${d.year}/${two(d.month)}/${two(d.day)}  ${two(d.hour)}:${two(d.minute)}';
}

class _HistoryEntry extends StatelessWidget {
  const _HistoryEntry({required this.transaction});

  final LoyaltyTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final earned = transaction.points >= 0;
    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColor.cardSurface,
        borderRadius: BorderRadius.circular(AppRadius.r16),
        border: Border.all(color: AppColor.borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: AppSizes.px44,
            height: AppSizes.px44,
            decoration: BoxDecoration(
              color: (earned ? AppColor.greenColor : AppColor.primaryColor)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.r12),
            ),
            child: Icon(
              earned ? AppIcons.arrowUp : AppIcons.arrowDown,
              color: earned ? AppColor.greenColor : AppColor.primaryColor,
            ),
          ),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(transaction.title, style: AppFonts.medium14(context)),
                SizedBox(height: AppSpacing.xs),
                Text(
                  _formatWhen(transaction.date),
                  style: AppFonts.regular12(context)
                      .copyWith(color: AppColor.greyColor),
                ),
              ],
            ),
          ),
          SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${earned ? '+' : '-'}${S.points(transaction.points.abs())}',
                style: AppFonts.semiBold16(context).copyWith(
                  color: earned ? AppColor.greenColor : AppColor.primaryColor,
                ),
              ),
              if (transaction.balanceAfter != null) ...[
                SizedBox(height: AppSpacing.xs),
                Text(
                  '${S.yourBalance}: ${S.points(transaction.balanceAfter!)}',
                  style: AppFonts.regular12(context)
                      .copyWith(color: AppColor.greyColor),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
