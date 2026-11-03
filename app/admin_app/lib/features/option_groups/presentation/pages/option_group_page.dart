import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/core/search/admin_search_controller.dart';
import 'package:admin_app/features/option_groups/presentation/manager/admin_option_group_cubit.dart';
import 'package:admin_app/features/option_groups/presentation/manager/admin_option_group_state.dart';
import 'package:admin_app/features/option_groups/presentation/widgets/option_group_data_dialog.dart';
import 'package:admin_app/features/option_groups/presentation/widgets/option_group_page_actions.dart';
import 'package:admin_app/features/option_groups/presentation/widgets/option_group_page_body.dart';
import 'package:admin_app/shared/widgets/admin_state_view.dart';

/// شاشة الأحجام والإضافات: يقرؤها كل موظف يفتح اللوحة، أما كتابتها فتطلب
/// `catalog.product.write` (020)، فتُفتح الصفحة للقراءة وأدوات الكتابة تُحجب
/// عمن ترفض قاعدته الكتابة.
class OptionGroupPage extends StatefulWidget {
  const OptionGroupPage({
    super.key,
    required this.searchController,
    this.cubit,
    this.canManage = false,
  });

  static const String routeName = '/option-groups';

  final AdminSearchController searchController;
  final AdminOptionGroupCubit? cubit;
  final bool canManage;

  @override
  State<OptionGroupPage> createState() => _OptionGroupPageState();
}

class _OptionGroupPageState extends State<OptionGroupPage> {
  late final AdminOptionGroupCubit _cubit;
  late final bool _ownsCubit;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _ownsCubit = widget.cubit == null;
    _cubit = widget.cubit ?? AdminOptionGroupCubit();
    if (_ownsCubit) _cubit.load();
    widget.searchController.bind(_onSearch);
  }

  @override
  void dispose() {
    widget.searchController.bind(null);
    if (_ownsCubit) _cubit.close();
    super.dispose();
  }

  void _onSearch(String query) {
    setState(() => _searchQuery = query.trim());
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AdminOptionGroupCubit>.value(
      value: _cubit,
      child: BlocBuilder<AdminOptionGroupCubit, AdminOptionGroupState>(
        builder: (context, state) {
          if (state.isLoading && !state.hasGroups) {
            return const AdminLoadingView();
          }
          if (state.status == AdminOptionGroupStatus.failure &&
              !state.hasGroups) {
            return AdminFailureView(
              message: state.errorMessage,
              onRetry: _cubit.load,
            );
          }
          return OptionGroupPageBody(
            groups: state.groups,
            search: _searchQuery,
            onAdd: widget.canManage
                ? () => showOptionGroupCreateDialog(
                    context: context,
                    cubit: _cubit,
                    products: state.products,
                    categories: state.categories,
                  )
                : null,
            onEdit: widget.canManage
                ? (group) => showOptionGroupEditDialog(
                    context: context,
                    cubit: _cubit,
                    group: group,
                    products: state.products,
                    categories: state.categories,
                  )
                : null,
            onDelete: widget.canManage
                ? (group) => confirmDeleteOptionGroup(context, _cubit, group)
                : null,
            onToggleActive: widget.canManage
                ? (group) => toggleOptionGroupActive(context, _cubit, group)
                : null,
          );
        },
      ),
    );
  }
}
