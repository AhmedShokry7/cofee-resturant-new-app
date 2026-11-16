import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/constant/app_images.dart';
import 'package:new_coffee/features/design/data/model/native_section.dart';
import 'package:new_coffee/features/design/data/model/published_design.dart';
import 'package:new_coffee/features/design/presentation/manager/design/design_cubit.dart';
import 'package:new_coffee/features/design/presentation/manager/design/design_state.dart';
import 'package:new_coffee/shared/widgets/db_image.dart';

/// The photograph behind the welcome copy.
///
/// The visible subject sits in the top of the file, so the crop keeps it in
/// frame when the panel covers the bottom of a tall screen.
///
/// الصورة المنشورة تعلو على المرفقة: عقدة `welcome.hero` برابط صالح تعني
/// الصورة الجديدة، بأسلوب العرض الذي اختاره الموظف (`fit`)، وعقدة مخفية
/// تعني بلا صورة أصلًا. غياب العقدة يعني الصورة المرفقة كما كانت.
class WelcomeHeroImage extends StatelessWidget {
  const WelcomeHeroImage({super.key});

  @override
  Widget build(BuildContext context) {
    final node = context.select(
      (DesignCubit cubit) => nativeSection(
        cubit.state.pageSections('welcome'),
        DesignWidgetTypes.welcomeHero,
      ),
    );
    if (nativeHidden(node)) return const SizedBox.shrink();
    final imageUrl = node?.property('imageUrl')?.trim() ?? '';
    if (imageUrl.isNotEmpty) {
      return DbImage(
        image: imageUrl,
        fit: DbImage.fitFromName(node?.property('fit')),
        // الموضوع يظهر في أعلى الصورة المرفقة، فالإحلال يبدأ من هناك
        // ما لم يختر الموظف محاذاة غيره.
        alignment: DbImage.alignmentFromName(
          node?.property('alignment') ?? 'topCenter',
        ),
      );
    }
    return Image(
      image: const AssetImage(AppImages.welcomeImage),
      fit: BoxFit.cover,
      alignment: Alignment.topCenter,
    );
  }
}
