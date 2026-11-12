import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/payment/presentation/manager/saved_cards/saved_cards_cubit.dart';
import 'package:new_coffee/features/payment/presentation/views/widgets/card_preview.dart';
import 'package:new_coffee/features/payment/data/model/card_brand.dart';
import 'package:new_coffee/features/payment/presentation/formatters/card_input_formatters.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';
import 'package:new_coffee/shared/widgets/auth_guard.dart';
import 'package:new_coffee/shared/widgets/custom_text_form_field.dart';
import 'package:new_coffee/core/theme/tokens.dart';

/// Adds one card to the saved list.
///
/// Saving is real: the backend tokenizes the card and stores it for reuse, and
/// the page only closes once that succeeded. The earlier version popped
/// immediately and told the customer the card would be saved during checkout,
/// which made this a dead end from anywhere outside payment.
class AddCardPage extends StatefulWidget {
  const AddCardPage({super.key});

  static const routeName = "addCardRoute";

  @override
  State<AddCardPage> createState() => _AddCardPageState();
}

class _AddCardPageState extends State<AddCardPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _numberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();

  /// CVV digit count required by the detected card brand (3, or 4 for Amex).
  int _cvvLength = 3;

  String get _digits => _numberController.text.replaceAll(RegExp(r'\D'), '');

  /// The `MM/YY` field holds two numbers the provider wants separately.
  String get _month {
    final parts = _expiryController.text.split('/');
    return parts.isNotEmpty ? parts.first : '';
  }

  String get _year {
    final parts = _expiryController.text.split('/');
    return parts.length > 1 ? parts[1] : '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _numberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  /// Exact CVV digit count for the brand currently typed in the number
  /// field: 4 for American Express, 3 for every other brand.
  /// Mutates state, so the caller wraps it in a setState.
  void _syncCvvLength() {
    final digits = _digits;
    _cvvLength = digits.isNotEmpty && detectCardBrand(digits) == CardBrand.amex
        ? 4
        : 3;
  }

  /// Digits the brand typed so far expects: Amex prints 15, every other brand
  /// in this app 16. Read in the validator, so a complete Amex is not rejected
  /// for being three digits shorter than a Visa.
  int get _expectedNumberLength =>
      detectCardBrand(_digits) == CardBrand.amex ? 15 : 16;

  bool _hasExpired() {
    final month = int.tryParse(_month);
    final year = int.tryParse(_year);
    if (month == null || year == null) return false;
    // A pasted four-digit year is a year already. Adding 2000 to it would date
    // the card to the 4000s and let it never expire.
    final fullYear = year < 100 ? 2000 + year : year;
    final now = DateTime.now();
    // A card is good through the last day of its expiry month.
    return fullYear < now.year || (fullYear == now.year && month < now.month);
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    // The form was never validated before; an empty card "saved" happily.
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final message = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final card = await context.read<SavedCardsCubit>().addCard(
      number: _digits,
      expiryMonth: _month,
      expiryYear: _year,
      cvv: _cvvController.text,
      holderName: _nameController.text.trim(),
    );
    if (!mounted) return;

    if (card == null) {
      // The cubit already produced a message in the app's language.
      message.showSnackBar(
        SnackBar(
          content: Text(
            context.read<SavedCardsCubit>().state.saveErrorCopy ??
                S.saveCardFailed,
          ),
        ),
      );
      return;
    }
    navigator.pop();
    message.showSnackBar(SnackBar(content: Text(S.cardAdded)));
  }

  @override
  Widget build(BuildContext context) {
    return AuthGuard(
      child: BlocBuilder<SavedCardsCubit, SavedCardsState>(
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(title: Text(S.addCard)),
            // Once we know the provider cannot be reached, there is nothing to
            // collect: asking for a full card number that cannot be saved is how
            // the customer ends up typing a real PAN into a form that fails.
            body: state.isSavingUnavailable
                ? _UnavailableNotice(message: state.saveErrorCopy)
                : AbsorbPointer(
                    absorbing: state.isSaving,
                    child: Form(key: _formKey, child: _formBody()),
                  ),
            bottomNavigationBar: state.isSavingUnavailable
                ? null
                : Container(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: AppColor.cardSurface,
                      border: Border(
                        top: BorderSide(color: AppColor.borderColor),
                      ),
                    ),
                    child: CustomBtn(
                      text: state.isSaving ? S.savingCard : S.addCard,
                      onPressed: state.isSaving ? null : _save,
                    ),
                  ),
          );
        },
      ),
    );
  }

  Widget _formBody() => ListView(
    padding: AppLayout.pageBody,
    children: [
      CardPreview(
        number: _numberController.text,
        name: _nameController.text,
        expiry: _expiryController.text,
      ),
      SizedBox(height: AppSpacing.xl),
      CustomTextFormField(
        controller: _nameController,
        hint: S.cardHolderName,
        icon: AppIcons.user,
        keyboardType: TextInputType.name,
        textInputAction: TextInputAction.next,
        onChanged: (_) => setState(() {}),
        validator: (value) => (value == null || value.trim().isEmpty)
            ? S.cardHolderRequired
            : null,
      ),
      CustomTextFormField(
        controller: _numberController,
        hint: S.cardNumber,
        icon: AppIcons.creditCard,
        keyboardType: TextInputType.number,
        inputFormatters: [CardNumberInputFormatter()],
        textInputAction: TextInputAction.next,
        onChanged: (_) => setState(_syncCvvLength),
        validator: (value) =>
            (value == null ||
                value.replaceAll(' ', '').length != _expectedNumberLength)
            ? S.validCardNumber
            : null,
      ),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: CustomTextFormField(
              controller: _expiryController,
              hint: S.expiryFormatHint,
              icon: AppIcons.calendar,
              keyboardType: TextInputType.number,
              inputFormatters: [ExpiryDateInputFormatter()],
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() {}),
              validator: (value) {
                if (value == null || value.length < 5) {
                  return S.invalidDate;
                }
                // A month outside 1-12 never expires and never arrives, so it
                // has to be refused here: the expiry check below compares it
                // against this month and would read 13 as "still valid".
                final month = int.tryParse(_month);
                if (month == null || month < 1 || month > 12) {
                  return S.invalidDate;
                }
                if (_hasExpired()) return S.cardExpired;
                return null;
              },
            ),
          ),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: CustomTextFormField(
              controller: _cvvController,
              hint: S.cvvHint(_cvvLength),
              icon: AppIcons.password,
              keyboardType: TextInputType.number,
              obscureText: true,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(_cvvLength),
              ],
              textInputAction: TextInputAction.done,
              validator: (value) =>
                  (value == null || value.length != _cvvLength)
                  ? S.invalidCvvLength(_cvvLength)
                  : null,
            ),
          ),
        ],
      ),
    ],
  );
}

/// Shown instead of the form when saving is impossible.
class _UnavailableNotice extends StatelessWidget {
  const _UnavailableNotice({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              AppIcons.cardNotAccepted,
              size: AppIconSize.xxxl,
              color: AppColor.greyColor,
            ),
            SizedBox(height: AppSpacing.md),
            Text(
              message ?? S.cardSavingNotConfigured,
              textAlign: TextAlign.center,
              style: AppFonts.regular14(context)
                  .copyWith(color: AppColor.greyColor),
            ),
            SizedBox(height: AppSpacing.lg),
            CustomBtn(
              text: S.back,
              variant: BtnVariant.outlined,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
