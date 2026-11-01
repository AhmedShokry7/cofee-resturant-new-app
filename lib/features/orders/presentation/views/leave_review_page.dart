import 'package:flutter/material.dart';

import 'package:new_coffee/core/locale/app_strings.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/checkout/presentation/views/widgets/order_item_card.dart';
import 'package:new_coffee/features/orders/data/model/order_item_model.dart';
import 'package:new_coffee/features/orders/presentation/views/widgets/order_action_bottom_bar.dart';
import 'package:new_coffee/features/orders/presentation/views/widgets/star_rating.dart';
import 'package:new_coffee/core/theme/tokens.dart';

class LeaveReviewPage extends StatefulWidget {
  const LeaveReviewPage({super.key, required this.order});

  static const routeName = "leaveReviewRoute";

  final OrderItemModel order;

  @override
  State<LeaveReviewPage> createState() => _LeaveReviewPageState();
}

class _LeaveReviewPageState extends State<LeaveReviewPage> {
  int _rating = 0;
  final _reviewController = TextEditingController();

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    if (_rating == 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(S.selectRating)));
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(SnackBar(content: Text(S.reviewSubmitted)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
      bottomNavigationBar: OrderActionBottomBar(
        onCancel: () => Navigator.of(context).pop(),
        onSubmit: _submit,
      ),
    );
  }
}
