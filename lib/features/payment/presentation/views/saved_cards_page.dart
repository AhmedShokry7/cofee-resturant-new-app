import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/payment/presentation/views/add_card_page.dart';
import 'package:new_coffee/features/payment/presentation/manager/saved_cards/saved_cards_cubit.dart';
import 'package:new_coffee/features/payment/presentation/views/widgets/saved_card_tile.dart';
import 'package:new_coffee/shared/widgets/auth_guard.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';
import 'package:new_coffee/shared/widgets/empty_state.dart';
import 'package:new_coffee/core/theme/tokens.dart';

class SavedCardsPage extends StatefulWidget {
  const SavedCardsPage({super.key});

  static const routeName = "savedCardsRoute";

  @override
  State<SavedCardsPage> createState() => _SavedCardsPageState();
}

class _SavedCardsPageState extends State<SavedCardsPage> {
  @override
  void initState() {
    super.initState();
    // The app reads the cards once, for whoever is signed in when it starts.
    // Opening this screen is usually the first chance to notice that the
    // account, or the server, has changed since — so it re-reads on entry
    // instead of showing a list that may be minutes or hours old.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // AuthGuard sits inside this widget, so the state is created for a guest
      // too and reaches here. Their cards belong to an account this device does
      // not have, so the screen that shows "sign in first" must not ask.
      if (mounted && SupabaseService.isSignedIn) {
        context.read<SavedCardsCubit>().load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AuthGuard(
      child: Scaffold(
        appBar: AppBar(title: Text(S.paymentMethod)),
        body: const _SavedCardsView(),
      ),
    );
  }
}

class _SavedCardsView extends StatelessWidget {
  const _SavedCardsView();

  Future<void> _confirmDelete(
    BuildContext context, {
    required String cardId,
  }) async {
    final cubit = context.read<SavedCardsCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(S.deleteCard),
        content: Text(S.deleteCardConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(S.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(S.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    // The cubit owns the answer: a delete the server refused leaves the row on
    // screen, which is the truth, and the listener below says why.
    await cubit.removeCard(cardId);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SavedCardsCubit, SavedCardsState>(
      // Only a write needs a message over the list. A failed read has its own
      // inline state with its own retry, and a snackbar would say the same
      // thing twice.
      listenWhen: (previous, current) => current.actionError != null,
      listener: (context, state) {
        final message = state.actionErrorCopy;
        if (message == null) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
        context.read<SavedCardsCubit>().clearActionError();
      },
      child: BlocBuilder<SavedCardsCubit, SavedCardsState>(
        builder: (context, state) {
          if (state.isLoading && state.cards.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: AppLayout.pageBody,
            children: [
              if (state.loadError != null)
                _ReadFailedBanner(
                  message: state.loadErrorCopy!,
                  onRetry: () => context.read<SavedCardsCubit>().load(),
                ),
              if (state.cards.isEmpty && state.loadError == null)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  child: EmptyState(
                    icon: AppIcons.creditCard,
                    title: S.noSavedCards,
                  ),
                ),
              ...state.cards.map(
                (card) => SavedCardTile(
                  card: card,
                  onDelete: () => _confirmDelete(context, cardId: card.id),
                  onSetDefault: () =>
                      context.read<SavedCardsCubit>().setDefaultCard(card.id),
                ),
              ),
              SizedBox(height: AppSpacing.md),
              CustomBtn(
                text: S.addNewCard,
                variant: BtnVariant.outlined,
                onPressed: () =>
                    Navigator.of(context).pushNamed(AddCardPage.routeName),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The list could not be re-read, above whatever the screen still holds.
///
/// Shown whether or not there are rows: "your cards could not be loaded" next
/// to a card that may already be deleted elsewhere is closer to the truth than
/// a silent list, and the retry is one tap away.
class _ReadFailedBanner extends StatelessWidget {
  const _ReadFailedBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.md),
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColor.whiteColor,
        borderRadius: BorderRadius.circular(AppRadius.r16),
        border: Border.all(color: AppColor.borderColor),
      ),
      child: Row(
        children: [
          const Icon(
            AppIcons.information,
            size: AppIconSize.lg,
            color: AppColor.greyColor,
          ),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppFonts.regular14(context)
                  .copyWith(color: AppColor.greyColor),
            ),
          ),
          // A named control, not a bare glyph: the tap re-reads the list.
          Semantics(
            button: true,
            label: S.retry,
            child: TextButton(onPressed: onRetry, child: Text(S.retry)),
          ),
        ],
      ),
    );
  }
}
