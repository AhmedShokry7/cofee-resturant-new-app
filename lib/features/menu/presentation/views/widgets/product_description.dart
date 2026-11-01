import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/menu/presentation/manager/product_details/product_details_cubit.dart';
import 'package:new_coffee/core/theme/tokens.dart';

class ProductDescription extends StatelessWidget {
  const ProductDescription({super.key, required this.description});

  static const int _collapsedLines = 3;

  final String description;

  @override
  Widget build(BuildContext context) {
    final isExpanded = context
        .watch<ProductDetailsCubit>()
        .state
        .showFullDescription;
    final style = AppFonts.regular14(context)
        .copyWith(color: AppColor.greyColor, height: AppTextHeights.body);

    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: description, style: style),
          maxLines: _collapsedLines,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: constraints.maxWidth);
        final overflows = painter.didExceedMaxLines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              description,
              style: style,
              maxLines: isExpanded ? null : _collapsedLines,
              overflow: isExpanded
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
            ),
            if (overflows)
              GestureDetector(
                onTap: () =>
                    context.read<ProductDetailsCubit>().toggleDescription(),
                child: Padding(
                  padding: EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    isExpanded ? S.readLess : S.readMore,
                    style: AppFonts.medium14(context).copyWith(
                      color: AppColor.primaryColor,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
