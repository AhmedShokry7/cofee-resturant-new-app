/// The standard size choices every product can use.
abstract final class AdminDefaultSizes {
  static const groupCode = 'size';
  static const values = <({String code, String nameAr, String nameEn})>[
    (code: 'small', nameAr: 'صغير', nameEn: 'Small'),
    (code: 'medium', nameAr: 'وسط', nameEn: 'Medium'),
    (code: 'large', nameAr: 'كبير', nameEn: 'Large'),
  ];

  static bool isSizeGroup({
    required String code,
    required String nameAr,
    required String nameEn,
  }) {
    if (code == groupCode || code == 'sizes' || code == 'system_sizes') {
      return true;
    }
    final arabic = nameAr.trim();
    final english = nameEn.trim().toLowerCase();
    return const {'الحجم', 'الأحجام', 'المقاس', 'المقاسات'}.contains(arabic) ||
        const {
          'size',
          'sizes',
          'product size',
          'product sizes',
        }.contains(english);
  }
}
