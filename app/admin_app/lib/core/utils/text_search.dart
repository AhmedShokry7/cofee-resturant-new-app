/// مطابقة البحث النصّي التي تستعملها قوائم الأدمن على حقول اللغتين.
///
/// الفئات والباندلز كانتا تنسخان الشرط نفسه سطرًا بسطر: تجفيف المسافة،
/// وتحويل الحروف، وأربعة `contains` على الاسم والوصف بالعربية والإنجليزية.
/// النسخة الواحدة هنا تعني أن من يصحّح بحثًا يصحّحهما جميعًا، وأن الحقل
/// الخامس إن أُضيف يُضاف في مكان واحد.
bool matchesSearchText({
  required String query,
  required String nameAr,
  required String nameEn,
  String? descriptionAr,
  String? descriptionEn,
}) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return true;
  bool holds(String? value) =>
      value != null && value.toLowerCase().contains(needle);
  return holds(nameAr) ||
      holds(nameEn) ||
      holds(descriptionAr) ||
      holds(descriptionEn);
}
