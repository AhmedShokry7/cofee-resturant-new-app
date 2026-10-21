import 'package:flutter/material.dart';

import 'package:admin_app/features/catalog/data/models/admin_product.dart';
import 'package:admin_app/features/catalog/presentation/pages/product_page_body.dart';
import 'package:admin_app/features/shell/presentation/models/admin_search_controller.dart';

/// The products page.
///
/// The page owns the page level state: it binds the search query of the shell
/// and hands the data to the page body, which composes the sections.
class ProductPage extends StatefulWidget {
  const ProductPage({super.key, required this.searchController});

  static const String routeName = '/products';

  final AdminSearchController searchController;

  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  String _query = '';

  @override
  void initState() {
    super.initState();
    widget.searchController.bind((query) {
      if (mounted) setState(() => _query = query);
    });
  }

  @override
  void dispose() {
    widget.searchController.bind(null);
    super.dispose();
  }

  List<AdminProduct> get _products => _sampleProducts
      .where(
        (product) =>
            _query.trim().isEmpty ||
            product.name.contains(_query.trim()) ||
            product.sku.toLowerCase().contains(_query.trim().toLowerCase()),
      )
      .toList();

  @override
  Widget build(BuildContext context) {
    return ProductPageBody(products: _products, onAdd: () {});
  }
}

/// The products shown until the data layer is connected.
const List<AdminProduct> _sampleProducts = <AdminProduct>[
  AdminProduct(
    id: 'p1',
    nameAr: 'هوت توتي لوشن تسمير البشرة الداكن برو تان - 250 مل',
    nameEn: 'Hot Tooty Lotion',
    sku: 'SKU-1024',
    slug: 'hot-tooty-lotion',
    basePrice: 97.39,
    categoryNameAr: 'العناية بالبشرة',
    categoryNameEn: 'Skin care',
    prepMinutes: 12,
    isFeatured: true,
  ),
  AdminProduct(
    id: 'p2',
    nameAr: 'مستر تومي مكمل غذائي متعددة الفيتامينات - 60 حبة',
    nameEn: 'Mr Tummy Complete',
    sku: 'SKU-1025',
    slug: 'mr-tummy-complete',
    basePrice: 124,
    categoryNameAr: 'المكملات الغذائية',
    categoryNameEn: 'Supplements',
    prepMinutes: 21,
  ),
  AdminProduct(
    id: 'p3',
    nameAr: 'كوزمو جل الحلاقة المنعش آرتيك راش - 480 مل',
    nameEn: 'Cosmo Shaving Gel',
    sku: 'SKU-1026',
    slug: 'cosmo-shaving-gel',
    basePrice: 7.48,
    categoryNameAr: 'العناية المنزلية',
    categoryNameEn: 'Home care',
    prepMinutes: 17,
  ),
  AdminProduct(
    id: 'p4',
    nameAr: 'كوزمو مقشر السكر بزبدة الشيا وفيتامين سي - 450 جرام',
    nameEn: 'Cosmo Sugar Scrub',
    sku: 'SKU-1027',
    slug: 'cosmo-sugar-scrub',
    basePrice: 15.04,
    categoryNameAr: 'العناية بالبشرة',
    categoryNameEn: 'Skin care',
    prepMinutes: 11,
  ),
  AdminProduct(
    id: 'p5',
    nameAr: 'قناع شمع مغربي بالطين الأحمر - 200 جرام',
    nameEn: 'Moroccan Clay Mask',
    sku: 'SKU-1028',
    slug: 'moroccan-clay-mask',
    basePrice: 42.5,
    categoryNameAr: 'العناية بالبشرة',
    categoryNameEn: 'Skin care',
    prepMinutes: 8,
  ),
];
