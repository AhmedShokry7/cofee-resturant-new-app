import 'package:new_coffee/features/design/data/model/published_design.dart';
import 'package:new_coffee/features/design/data/repositories/design_repository.dart';

/// مستودع تصميم لا يسأل شبكة.
///
/// الشاشات التي تُضخّ في الاختبار بلا إقلاع كامل تحتاج `DesignCubit` واحدًا على
/// الأقل؛ هذا يعطيها إياه بغير طبقة شكل، فترسم ما ترسمه اليوم. وحين يريد اختبار
/// أن نشرًا معيّنًا حرّك الأقسام أو الألوان، يمرّر المستند هنا بدل الشبكة.
class FakeDesignRepository implements DesignRepository {
  FakeDesignRepository([this.design]);

  /// المستند الذي يجيب به القارئ، وnull تعني «لم تصل قراءة» فتبقى الشاشة على
  /// شكلها.
  final PublishedDesign? design;

  /// كم مرة سُئلت الشاشة المنشور — لاختبار أن التحديث القسري لم يقرأ مرتين.
  int publishedCalls = 0;

  @override
  Future<PublishedDesign?> published({bool forceRefresh = false}) async {
    publishedCalls++;
    return design;
  }

  @override
  Future<PublishedDesign?> lastKnown() async => design;
}
