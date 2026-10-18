import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/payment/presentation/views/add_card_page.dart';
import 'package:new_coffee/features/payment/presentation/manager/saved_cards/saved_cards_cubit.dart';
import 'package:new_coffee/features/payment/presentation/views/widgets/saved_card_tile.dart';
import 'package:new_coffee/shared/widgets/auth_guard.dart';

class SavedCardsPage extends StatelessWidget {
  const SavedCardsPage({super.key});

  static const routeName = "savedCardsRoute";

  @override
  Widget build(BuildContext context) {
    return AuthGuard(
      child: Scaffold(
        appBar: AppBar(title: Text(S.paymentMethod)),
        body: BlocBuilder<SavedCardsCubit, SavedCardsState>(
        builder: (context, state) {
          return ListView(
            padding: EdgeInsets.fromLTRB(
              SpacingTokens.lg.w,
              SpacingTokens.md.h,
              SpacingTokens.lg.w,
              SpacingTokens.lg.w,
            ),
            children: [
              if (state.cards.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: SpacingTokens.xl.h),
                  child: Text(
                    S.noSavedCards,
                    textAlign: TextAlign.center,
                    style: AppFonts.regular14(context)
                        .copyWith(color: AppColor.greyColor),
                  ),
                ),
              ...state.cards.map(
                (card) => SavedCardTile(
                  card: card,
                  onDelete: () =>
                      context.read<SavedCardsCubit>().removeCard(card.id),
                  onSetDefault: () => context
                      .read<SavedCardsCubit>()
                      .setDefaultCard(card.id),
                ),
              ),
              SizedBox(height: SpacingTokens.md.h),
              GestureDetector(
                onTap: () =>
                    Navigator.of(context).pushNamed(AddCardPage.routeName),
                child: Container(
                  height: 52.h,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColor.primaryColor),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    S.addNewCard,
                    style: AppFonts.medium14(context)
                        .copyWith(color: AppColor.primaryColor),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
    );
  }
}
