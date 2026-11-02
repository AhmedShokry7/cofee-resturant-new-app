import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/shared/widgets/search_pill.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/search/presentation/manager/search/search_cubit.dart';
import 'package:new_coffee/features/search/presentation/views/search_page.dart';
import 'package:new_coffee/core/theme/tokens.dart';

class HomeSearchBar extends StatelessWidget {
  const HomeSearchBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: S.searchHint,
      child: Material(
        color: SearchPill.fill(),
        shape: SearchPill.shape(),
        child: InkWell(
          onTap: () {
            context.read<SearchCubit>().search('');
            Navigator.of(context).pushNamed(SearchPage.routeName);
          },
          customBorder: SearchPill.shape(),
          child: Padding(
            padding: SearchPill.padding(),
            child: Row(
              children: [
                SearchPill.icon(),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    S.searchHint,
                    style: AppFonts.regular14(context)
                        .copyWith(color: AppColor.greyColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
