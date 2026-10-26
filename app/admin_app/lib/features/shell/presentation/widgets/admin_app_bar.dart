import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/shell/presentation/models/admin_search_controller.dart';
import 'package:admin_app/shared/widgets/admin_language_button.dart';
import 'package:admin_app/shared/widgets/admin_theme_button.dart';

/// The one app bar used by every admin page.
///
/// The title, search hint and search behaviour change per page; the language
/// and theme controls, the search affordance and the overall layout stay the
/// same everywhere. The shell owns the [AdminSearchController] and hands it to
/// both this bar and the active page.
class AdminAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AdminAppBar({
    super.key,
    required this.title,
    required this.searchHint,
    required this.searchController,
    required this.searchTextController,
    required this.isCompact,
    this.leading,
  });

  final String title;
  final String searchHint;
  final AdminSearchController searchController;
  final TextEditingController searchTextController;
  final bool isCompact;
  final Widget? leading;

  static const double _toolbarHeight = 64;
  static const double _compactSearchHeight = 52;

  @override
  Size get preferredSize => Size.fromHeight(
    isCompact ? _toolbarHeight + _compactSearchHeight : _toolbarHeight,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background =
        theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface;

    return Material(
      color: background,
      shape: Border(bottom: BorderSide(color: theme.dividerColor)),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: _toolbarHeight,
              child: Row(
                children: [
                  ?leading,
                  Expanded(
                    child: Padding(
                      padding: EdgeInsetsDirectional.only(
                        start: leading == null
                            ? AppDimensions.lg
                            : AppDimensions.sm,
                      ),
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: AppFontWeights.bold,
                        ),
                      ),
                    ),
                  ),
                  if (!isCompact) ...[
                    const SizedBox(width: AppDimensions.lg),
                    SizedBox(
                      width: AppDimensions.searchFieldWidth,
                      child: _AdminSearchField(
                        hint: searchHint,
                        searchController: searchController,
                        textController: searchTextController,
                      ),
                    ),
                    const SizedBox(width: AppDimensions.md),
                  ],
                  const AdminLanguageButton(),
                  const SizedBox(width: AppDimensions.sm),
                  const AdminThemeButton(),
                  const SizedBox(width: AppDimensions.lg),
                ],
              ),
            ),
            if (isCompact)
              PreferredSize(
                preferredSize: const Size.fromHeight(_compactSearchHeight),
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: AppDimensions.md,
                    end: AppDimensions.md,
                    bottom: AppDimensions.sm,
                  ),
                  child: _AdminSearchField(
                    hint: searchHint,
                    searchController: searchController,
                    textController: searchTextController,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AdminSearchField extends StatefulWidget {
  const _AdminSearchField({
    required this.hint,
    required this.searchController,
    required this.textController,
  });

  final String hint;
  final AdminSearchController searchController;
  final TextEditingController textController;

  @override
  State<_AdminSearchField> createState() => _AdminSearchFieldState();
}

class _AdminSearchFieldState extends State<_AdminSearchField> {
  @override
  void initState() {
    super.initState();
    widget.searchController.addListener(_syncQuery);
  }

  @override
  void didUpdateWidget(_AdminSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchController != widget.searchController) {
      oldWidget.searchController.removeListener(_syncQuery);
      widget.searchController.addListener(_syncQuery);
    }
  }

  @override
  void dispose() {
    widget.searchController.removeListener(_syncQuery);
    super.dispose();
  }

  /// Mirrors a query that a page wrote (for example its own search field).
  void _syncQuery() {
    final query = widget.searchController.query;
    if (widget.textController.text.trim() == query) return;
    widget.textController.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: widget.searchController,
      builder: (context, _) {
        final hasQuery = widget.searchController.hasQuery;
        return TextField(
          controller: widget.textController,
          onChanged: widget.searchController.update,
          textInputAction: TextInputAction.search,
          style: theme.textTheme.bodyMedium,
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: theme.textTheme.bodyMedium?.copyWith(
              color: theme.hintColor,
            ),
            prefixIcon: Icon(
              HugeIcons.strokeRoundedSearch01,
              size: 18,
              color: theme.iconTheme.color,
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: AppDimensions.fieldIconBox,
              minHeight: AppDimensions.fieldIconBox,
            ),
            suffixIcon: hasQuery
                ? IconButton(
                    tooltip: S.clearSearch,
                    icon: Icon(
                      HugeIcons.strokeRoundedCancel01,
                      size: 18,
                      color: theme.iconTheme.color,
                    ),
                    onPressed: () {
                      widget.textController.clear();
                      widget.searchController.clear();
                    },
                  )
                : null,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.md,
              vertical: AppDimensions.md,
            ),
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerHighest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.dividerColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.dividerColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.colorScheme.primary),
            ),
          ),
        );
      },
    );
  }
}
