/// مرشَّح موظف في قوائم الترشيح وحواراتها: معرّفه ولفظه كما قرأتهما الشاشة.
///
/// يقيم في presentation/models لأنه اختيار على شاشة لا صفّ في القاعدة: الاسم
/// يأتي من السطر المقروء، فمن لم تُقرأ سطورُه لا مرشَّح له ولا صفرًا يُختَر.
class HrPersonOption {
  const HrPersonOption(this.id, this.name);

  final String id;
  final String name;
}
