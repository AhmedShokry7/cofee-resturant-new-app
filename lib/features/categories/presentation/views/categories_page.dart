import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/categories/data/model/category_model.dart';
import 'package:new_coffee/features/design/data/model/published_design.dart';
import 'package:new_coffee/features/categories/presentation/manager/categories/categories_cubit.dart';
import 'package:new_coffee/features/categories/presentation/views/widgets/all_categories_view.dart';
import 'package:new_coffee/features/categories/presentation/views/widgets/categories_document_sections.dart';
import 'package:new_coffee/features/categories/presentation/views/widgets/category_body.dart';
import 'package:new_coffee/features/categories/presentation/views/widgets/category_scoped_header.dart';
import 'package:new_coffee/features/categories/presentation/views/widgets/category_tabs.dart';
import 'package:new_coffee/features/design/presentation/manager/design/design_cubit.dart';
import 'package:new_coffee/shared/widgets/page_title.dart';

/// The catalogue: every category and the products under the one being looked at.
///
/// [initialCategoryId] is the shape a banner opens - one category's products
/// and nothing else - and it belongs to [CategoryBody], which names that
/// category where the row of tabs would otherwise sit. [CategoriesPage.all] is
/// the shape "See all" opens: the root of the tree, with no category selected.
///
/// محتوى مستند التصميم المنشور لصفحة التصنيفات يُرسم فوق المتصفّح (عناوين،
/// نصوص، بانيرات حرّة...) بالترتيب الذي نشره الموظف، والمتصفّح التفاعلي نفسه
/// يملأ ما بقي من الشاشة. مستند بلا صفحة تصنيفات يرسم الشاشة كما هي بلا زيادة.
class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key, this.initialCategoryId})
    : showAllCategories = false;

  /// The page "See all" opens: every main category, from the top of the tree.
  ///
  /// It deliberately carries no category id. The page is not about one
  /// category, and a selection left over from an earlier visit must not travel
  /// into it, so there is no field here for that selection to reach.
  const CategoriesPage.all({super.key})
    : initialCategoryId = null,
      showAllCategories = true;

  /// The category this page answers for alone. Null on the catalogue tab, where
  /// moving between categories is the point of the screen.
  final String? initialCategoryId;

  /// True on the page "See all" opens. It suppresses the catalogue browser
  /// (tabs plus products) and draws the root of the tree instead.
  final bool showAllCategories;

  @override
  Widget build(BuildContext context) {
    // The page asks for the data and never waits for it: the body reads the
    // cubit's current state, so a page opened for a category that is already
    // loaded shows it in the first frame.
    context.read<CategoriesCubit>().ensureLoaded();
    final isAllCategories = showAllCategories;
    final isOneCategory = !isAllCategories && initialCategoryId != null;
    final document = isAllCategories || isOneCategory
        ? const <PublishedSection>[]
        : context.watch<DesignCubit>().state.categoriesSections;
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isAllCategories)
              CategoryScopedHeader(
                title: S.allCategories,
                onBack: () => Navigator.of(context).maybePop(),
              )
            else if (!isOneCategory) ...[
              PageTitle(
                title: S.categories,
                page: 'categories',
                label: 'categories',
              ),
              const CategoryTabs(),
              ...buildCategoriesDocumentSections(document),
            ],
            Expanded(
              child: isAllCategories
                  ? AllCategoriesView(
                      onCategoryTap: (category) =>
                          _openCategory(context, category),
                    )
                  : CategoryBody(categoryId: initialCategoryId),
            ),
          ],
        ),
      ),
    );
  }

  /// Opens the products of [category] in the shape a banner already uses: the
  /// id is carried by the page, never written to the shared tab index, so the
  /// page cannot land on a category the customer picked earlier.
  void _openCategory(BuildContext context, CategoryModel category) {
    final id = category.id;
    if (id == null || id.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CategoriesPage(initialCategoryId: id)),
    );
  }
}
