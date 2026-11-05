import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/checkout/presentation/views/widgets/order_item_card.dart';
import 'package:new_coffee/features/orders/data/model/order_item_model.dart';
import 'package:new_coffee/features/orders/presentation/manager/review/review_cubit.dart';
import 'package:new_coffee/features/orders/presentation/views/widgets/order_action_bottom_bar.dart';
import 'package:new_coffee/features/orders/presentation/views/widgets/star_rating.dart';

/// The rating draft for one purchased product, and the write that stores it.
///
/// Leaving with `true` tells whoever opened this screen that the review reached
/// the server, so a list can show it without re-reading the whole history.
class LeaveReviewView extends StatefulWidget {
  const LeaveReviewView({super.key, required this.order});

  final OrderItemModel order;

  @override
  State<LeaveReviewView> createState() => _LeaveReviewViewState();
}

class _LeaveReviewViewState extends State<LeaveReviewView> {
  int _rating = 0;
  final _reviewController = TextEditingController();

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_rating == 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(S.selectRating)));
      return;
    }
    final cubit = context.read<ReviewCubit>();
    final orderId = widget.order.orderId.isNotEmpty
        ? widget.order.orderId
        : widget.order.id;
    // A review belongs to the product the customer actually bought, so the row
    // that carries no product is not submittable.
    final productId = widget.order.product.id;
    await cubit.submit(
      productId: productId,
      orderId: orderId,
      rating: _rating,
      body: _reviewController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ReviewCubit, ReviewState>(
      listenWhen: (previous, current) =>
          current.submitted ||
          (current.error != null && current.error != previous.error),
      listener: (context, state) {
        final messenger = ScaffoldMessenger.of(context);
        final navigator = Navigator.of(context);
        if (state.submitted) {
          navigator.pop(true);
          messenger.showSnackBar(SnackBar(content: Text(S.reviewSubmitted)));
          return;
        }
        messenger.showSnackBar(SnackBar(content: Text(state.errorCopy!)));
      },
      child: Scaffold(
        appBar: AppBar(title: Text(S.leaveReview)),
        body: ListView(
          padding: AppLayout.pageBody,
          children: [
            OrderItemCard(
              product: widget.order.product,
              quantity: widget.order.quantity,
            ),
            SizedBox(height: AppSpacing.xl),
            Text(
              S.howIsOrder,
              textAlign: TextAlign.center,
              style: AppFonts.semiBold24(context),
            ),
            SizedBox(height: AppSpacing.lg),
            Text(
              S.overallRating,
              textAlign: TextAlign.center,
              style: AppFonts.regular16(context)
                  .copyWith(color: AppColor.greyColor),
            ),
            SizedBox(height: AppSpacing.md),
            StarRating(
              rating: _rating,
              onChanged: (value) => setState(() => _rating = value),
            ),
            SizedBox(height: AppSpacing.xl),
            const Divider(),
            SizedBox(height: AppSpacing.lg),
            Text(S.addReview, style: AppFonts.semiBold16(context)),
            SizedBox(height: AppSpacing.md),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColor.borderColor),
                borderRadius: BorderRadius.circular(AppRadius.r8),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: TextField(
                controller: _reviewController,
                minLines: 4,
                maxLines: 6,
                style: AppFonts.regular14(context),
                cursorColor: AppColor.primaryColor,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  hintText: S.reviewHint,
                  hintStyle: AppFonts.regular14(context)
                      .copyWith(color: AppColor.greyColor),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: BlocBuilder<ReviewCubit, ReviewState>(
          builder: (context, state) => OrderActionBottomBar(
            onCancel: state.isSubmitting
                ? null
                : () => Navigator.of(context).pop(),
            onSubmit: state.isSubmitting ? null : _submit,
          ),
        ),
      ),
    );
  }
}
