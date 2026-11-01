import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/payment/presentation/views/add_card_page.dart';
import 'package:new_coffee/features/payment/presentation/manager/saved_cards/saved_cards_cubit.dart';
import 'package:new_coffee/features/payment/presentation/views/widgets/saved_card_tile.dart';
import 'package:new_coffee/shared/widgets/auth_guard.dart';
import 'package:new_coffee/core/theme/tokens.dart';

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
              padding: AppLayout.pageBody,
              children: [
                if (state.cards.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
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
                    onSetDefault: () =>
                        context.read<SavedCardsCubit>().setDefaultCard(card.id),
                  ),
                ),
                SizedBox(height: AppSpacing.md),
                GestureDetector(
                  onTap: () =>
                      Navigator.of(context).pushNamed(AddCardPage.routeName),
                  child: Container(
                    height: AppDimensions.buttonHeight,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColor.primaryColor),
                      borderRadius: BorderRadius.circular(AppRadius.r8),
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
