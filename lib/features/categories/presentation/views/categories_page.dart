import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/design/data/model/published_design.dart';
import 'package:new_coffee/features/categories/presentation/manager/categories/categories_cubit.dart';
import 'package:new_coffee/features/categories/presentation/views/widgets/categories_document_sections.dart';
import 'package:new_coffee/features/categories/presentation/views/widgets/category_body.dart';
import 'package:new_coffee/features/categories/presentation/views/widgets/category_tabs.dart';
import 'package:new_coffee/features/design/presentation/manager/design/design_cubit.dart';
import 'package:new_coffee/shared/widgets/page_title.dart';

/// The catalogue: every category and the products under the one being looked at.
///
/// [initialCategoryId] is the other shape of this screen - the page a banner
/// opens - and it belongs to [CategoryBody], which names that category where the
/// row of tabs would otherwise sit.
///
/// محتوى مستند التصميم المنشور لصفحة التصنيفات يُرسم فوق المتصفّح (عناوين،
/// نصوص، بانيرات حرّة...) بالترتيب الذي نشره الموظف، والمتصفّح التفاعلي نفسه
/// يملأ ما بقي من الشاشة. مستند بلا صفحة تصنيفات يرسم الشاشة كما هي بلا زيادة.
class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key, this.initialCategoryId});

  /// The category this page answers for alone. Null on the catalogue tab, where
  /// moving between categories is the point of the screen.
  final String? initialCategoryId;

  @override
  Widget build(BuildContext context) {
    // The page asks for the data and never waits for it: the body reads the
    // cubit's current state, so a page opened for a category that is already
    // loaded shows it in the first frame.
    context.read<CategoriesCubit>().ensureLoaded();
    final isOneCategory = initialCategoryId != null;
    final document = isOneCategory
        ? const <PublishedSection>[]
        : context.watch<DesignCubit>().state.categoriesSections;
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!isOneCategory) ...[
              PageTitle(title: S.categories, page: 'categories', label: 'categories'),
              const CategoryTabs(),
              ...buildCategoriesDocumentSections(document),
            ],
            Expanded(child: CategoryBody(categoryId: initialCategoryId)),
          ],
        ),
      ),
    );
  }
}
