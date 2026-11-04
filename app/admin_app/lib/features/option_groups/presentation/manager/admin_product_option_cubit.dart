import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/core/error/admin_error_message.dart';
import 'package:admin_app/features/option_groups/di/option_groups_dependencies.dart';
import 'package:admin_app/features/option_groups/domain/repositories/product_option_repository.dart';
import 'package:admin_app/features/option_groups/domain/usecases/load_product_options.dart';
import 'package:admin_app/features/option_groups/domain/usecases/save_product_option_price.dart';
import 'package:admin_app/features/option_groups/domain/usecases/set_product_option_group.dart';
import 'package:admin_app/features/option_groups/presentation/manager/admin_product_option_state.dart';

/// منطق حوار «الأحجام والإضافات» داخل شاشة المنتج.
///
/// كل كتابة تنتهي بقراءة صامتة: الذي يقرر الزيادة النافذة هو
/// `catalog.option_value_delta` في 229، والذي يقرر رؤية المجموعة هو دالة 224،
/// فلا تُصدّق اللوحة حسابها بل تعرض ما ردّت به القاعدة بعد كتابتها.
class AdminProductOptionCubit extends Cubit<AdminProductOptionState> {
  AdminProductOptionCubit({ProductOptionRepository? repository})
    : this._withUseCases(
        repository ?? OptionGroupsDependencies.productRepository,
      );

  AdminProductOptionCubit._withUseCases(ProductOptionRepository repository)
    : _load = LoadProductOptionsUseCase(repository),
      _savePrice = SaveProductOptionPriceUseCase(repository),
      _setAttached = SetProductOptionGroupUseCase(repository),
      super(const AdminProductOptionState());

  final LoadProductOptionsUseCase _load;
  final SaveProductOptionPriceUseCase _savePrice;
  final SetProductOptionGroupUseCase _setAttached;

  String _productId = '';

  Future<void> load({
    required String productId,
    required double basePrice,
  }) async {
    _productId = productId;
    emit(
      state.copyWith(
        status: AdminProductOptionStatus.loading,
        basePrice: basePrice,
        clearError: true,
      ),
    );
    await _read();
  }

  /// `null` في الخريطة يعني رجوع الخيار إلى زيادة المجموعة، لا صفرًا.
  Future<bool> savePrices(Map<String, double?> deltas) => _write(() async {
    for (final entry in deltas.entries) {
      await _savePrice(_productId, entry.key, entry.value);
    }
  });

  Future<bool> toggleAttached(String groupId, bool attached) =>
      _write(() => _setAttached(_productId, groupId, attached));

  /// الكتابة الواحدة تُبقي الزرّ دوّارًا، وبعدها تُقرأ القاعدة من جديد فيُعرض
  /// جوابها لا طلب اللوحة — فقد ترفض السياسة الكتابة بصمت النجاح.
  Future<bool> _write(Future<void> Function() action) async {
    if (_productId.isEmpty) return false;
    emit(state.copyWith(saving: true, clearError: true));
    try {
      await action();
      await _read();
      emit(state.copyWith(saving: false));
      return true;
    } catch (error) {
      emit(
        state.copyWith(saving: false, errorMessage: adminErrorMessage(error)),
      );
      return false;
    }
  }

  Future<void> _read() async {
    try {
      emit(
        state.copyWith(
          status: AdminProductOptionStatus.ready,
          groups: await _load(_productId),
          clearError: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: AdminProductOptionStatus.failure,
          errorMessage: adminErrorMessage(error),
        ),
      );
    }
  }
}
