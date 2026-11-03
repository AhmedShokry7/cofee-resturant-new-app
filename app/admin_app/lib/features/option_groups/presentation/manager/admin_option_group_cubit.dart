import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/app_dependencies.dart';
import 'package:admin_app/core/catalog/catalog_data.dart';
import 'package:admin_app/core/error/admin_error_message.dart';
import 'package:admin_app/features/option_groups/di/option_groups_dependencies.dart';
import 'package:admin_app/features/option_groups/domain/entities/admin_option_group.dart';
import 'package:admin_app/features/option_groups/domain/repositories/option_group_repository.dart';
import 'package:admin_app/features/option_groups/domain/usecases/create_option_group.dart';
import 'package:admin_app/features/option_groups/domain/usecases/delete_option_group.dart';
import 'package:admin_app/features/option_groups/domain/usecases/load_option_groups.dart';
import 'package:admin_app/features/option_groups/domain/usecases/set_option_group_active.dart';
import 'package:admin_app/features/option_groups/domain/usecases/update_option_group.dart';
import 'package:admin_app/features/option_groups/presentation/manager/admin_option_group_state.dart';

/// يدير شاشة الأحجام والإضافات: ما تعرضه، وما يُكتب بعد أن تقرر اللوحة.
///
/// القرار هنا لا في الـ widgets: المجموعة المضافة تُدرج في القائمة كما أعادتْها
/// القاعدة بمعرفها الجديد، والتعطيل يُطبق على الصفّ نفسه لا على نسخة منه، فلا
/// تُعرض مجموعة «معطّلة» وهي ما زالت نشطة في القاعدة.
class AdminOptionGroupCubit extends Cubit<AdminOptionGroupState> {
  AdminOptionGroupCubit({
    OptionGroupRepository? repository,
    CatalogData? catalog,
  }) : this._withUseCases(
         repository ?? OptionGroupsDependencies.repository,
         catalog ?? AppDependencies.catalog,
       );

  AdminOptionGroupCubit._withUseCases(
    OptionGroupRepository repository,
    CatalogData catalog,
  ) : _loadGroups = LoadOptionGroupsUseCase(repository),
      _createGroup = CreateOptionGroupUseCase(repository),
      _updateGroup = UpdateOptionGroupUseCase(repository),
      _deleteGroup = DeleteOptionGroupUseCase(repository),
      _setGroupActive = SetOptionGroupActiveUseCase(repository),
      _catalog = catalog,
      super(const AdminOptionGroupState());

  final LoadOptionGroupsUseCase _loadGroups;
  final CreateOptionGroupUseCase _createGroup;
  final UpdateOptionGroupUseCase _updateGroup;
  final DeleteOptionGroupUseCase _deleteGroup;
  final SetOptionGroupActiveUseCase _setGroupActive;
  final CatalogData _catalog;

  Future<void> load() async {
    emit(
      state.copyWith(status: AdminOptionGroupStatus.loading, clearError: true),
    );
    try {
      // الكتالوج الذي يُنتقى منه النطاق لا يُنتظر قبل المجموعة: قراءتان تُفتحان
      // معًا ويُنتظر كلٌّ بحسابها حتى تبقى أنواعها معروفة.
      final groupsFuture = _loadGroups();
      final catalogFuture = _catalog.loadCatalog();
      final groups = await groupsFuture;
      final snapshot = await catalogFuture;
      emit(
        state.copyWith(
          status: AdminOptionGroupStatus.ready,
          groups: groups,
          products: snapshot.products,
          categories: snapshot.categories,
          clearError: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: AdminOptionGroupStatus.failure,
          errorMessage: adminErrorMessage(error),
        ),
      );
    }
  }

  Future<AdminOptionGroup> createGroup(AdminOptionGroup group) async {
    final created = await _createGroup(group);
    emit(
      state.copyWith(
        groups: <AdminOptionGroup>[...state.groups, created],
        clearError: true,
      ),
    );
    return created;
  }

  Future<void> updateGroup(AdminOptionGroup group) async {
    final updated = await _updateGroup(group);
    emit(
      state.copyWith(
        groups: state.groups
            .map((g) => g.id == updated.id ? updated : g)
            .toList(growable: false),
        clearError: true,
      ),
    );
  }

  Future<void> deleteGroup(String groupId) async {
    await _deleteGroup(groupId);
    emit(
      state.copyWith(
        groups: state.groups
            .where((g) => g.id != groupId)
            .toList(growable: false),
        clearError: true,
      ),
    );
  }

  Future<void> toggleActive(AdminOptionGroup group) async {
    final next = !group.isActive;
    await _setGroupActive(group.id, next);
    emit(
      state.copyWith(
        groups: state.groups
            .map((g) => g.id == group.id ? g.copyWith(isActive: next) : g)
            .toList(growable: false),
        clearError: true,
      ),
    );
  }
}
