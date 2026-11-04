import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/option_groups/domain/entities/admin_product_option_group.dart';
import 'package:admin_app/features/option_groups/domain/entities/admin_product_option_value.dart';
import 'package:admin_app/features/option_groups/presentation/manager/admin_product_option_cubit.dart';
import 'package:admin_app/features/option_groups/presentation/manager/product_option_draft.dart';

/// ربط مجموعة بالمشروب أو فصلها عنه.
///
/// لا تُحدَّث اللوحة من نفسها: الـ cubit يكتب ثم يعيد قراءة جواب
/// `effective_product_option_groups` في 224، فيُعرض موضع المفتاح كما قررته
/// القاعدة لا كما طُلب منها.
void attachProductOptionGroup(
  BuildContext context,
  AdminProductOptionGroup group,
  bool attached,
) {
  context.read<AdminProductOptionCubit>().toggleAttached(group.id, attached);
}

/// محو تجاوز خيار: كتابة فورية لا انتظار زرّ الحفظ، لأن الحقل بعدها يُملى من
/// جواب القاعدة وإلا بقي يعرض رقمًا لم يعد له وجود.
Future<void> resetProductOptionPrice(
  BuildContext context,
  ProductOptionDraft draft,
  AdminProductOptionValue value,
) async {
  final cubit = context.read<AdminProductOptionCubit>();
  final done = await cubit.savePrices(<String, double?>{value.id: null});
  if (!done || !context.mounted) return;
  draft.fill(cubit.state.groups);
}

/// كتابة ما تغيّر في الحقول فقط، ثم إعادة ملءِها من القاعدة.
Future<void> saveProductOptionPrices(
  BuildContext context,
  ProductOptionDraft draft,
) async {
  final cubit = context.read<AdminProductOptionCubit>();
  final changes = draft.changes(cubit.state.groups);
  if (changes.isEmpty) {
    Navigator.of(context).pop();
    return;
  }
  final done = await cubit.savePrices(changes);
  if (!done || !context.mounted) return;
  // الرفض يعرضه الجسم في الأعلى والكتابة تبقى في الحقل ينتظرها الأدمن.
  draft.fill(cubit.state.groups);
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(S.productOptionsSavedMessage)));
}
