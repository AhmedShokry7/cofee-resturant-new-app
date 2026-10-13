import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/theme/spacing_toxens.dart';
import 'package:new_coffee/features/categories/data/categories_list.dart';
import 'package:new_coffee/features/categories/presentation/views/widgets/category_card.dart';
import 'package:new_coffee/features/search/presentation/manager/search/search_cubit.dart';
import 'package:new_coffee/features/search/presentation/views/search_page.dart';

class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final categories = getCategoriesList();
    return Scaffold(
      appBar: AppBar(title: const Text("Categories")),
      body: GridView.builder(
        padding: EdgeInsets.all(SpacingTokens.lg.w),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: SpacingTokens.md.w,
          mainAxisSpacing: SpacingTokens.md.h,
          childAspectRatio: 1.35,
        ),
        itemCount: categories.length,
        itemBuilder: (context, index) => CategoryCard(
          category: categories[index],
          onTap: () {
            context.read<SearchCubit>().search(categories[index].label);
            Navigator.of(context).pushNamed(SearchPage.routeName);
          },
        ),
      ),
    );
  }
}
