import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:new_coffee/features/bundles/presentation/views/bundle_details_page.dart';
import 'package:new_coffee/features/categories/presentation/views/categories_page.dart';
import 'package:new_coffee/features/home/data/model/banner_model.dart';
import 'package:new_coffee/features/home/presentation/manager/home/home_cubit.dart';
import 'package:new_coffee/features/menu/presentation/views/product_details_page.dart';

/// What pressing a banner does: it opens the thing the banner is about.
///
/// Three places need the same answer - the carousel on home, the promo slot
/// under it, and the button on the banner page - so the meaning of
/// `banners.target_type` is written once here. A new target is one case in this
/// switch, not three files that can disagree about what a banner opens.
///
/// [fallback] runs for a banner that points at nothing the app can open: a row
/// the customer pressed but that has since been unpublished, a banner whose
/// target type is unknown, a web address that is not one. A caller that has
/// somewhere to show the banner passes it; a caller already standing on that
/// screen passes nothing, because a button that opens another copy of the page
/// it is on is not a button.
Future<void> openBanner(
  BuildContext context,
  BannerModel banner, {
  void Function()? fallback,
}) async {
  // Taken before the lookup below. A banner whose target has to be read can
  // finish that read after the screen it was pressed on is gone, and pushing
  // onto a dead navigator is a crash rather than a tap that did nothing.
  final nav = Navigator.of(context);
  final home = context.read<HomeCubit>();
  final target = await home.resolveTarget(banner);
  if (!nav.mounted) return;
  final opened = switch (target.target) {
    BannerTarget.category => _openCategory(nav, target),
    BannerTarget.product => _openProduct(nav, target),
    BannerTarget.bundle => _openBundle(nav, target),
    BannerTarget.url => await _openWebAddress(target),
    BannerTarget.none => false,
  };
  if (!opened) fallback?.call();
}

/// The category the banner points at, with its products already on screen.
bool _openCategory(NavigatorState nav, BannerModel banner) {
  final id = banner.targetId;
  if (id == null) return false;
  nav.push(
    MaterialPageRoute(builder: (_) => CategoriesPage(initialCategoryId: id)),
  );
  return true;
}

bool _openProduct(NavigatorState nav, BannerModel banner) {
  final product = banner.targetProduct;
  if (product == null) return false;
  nav.pushNamed(ProductDetailsPage.routeName, arguments: product);
  return true;
}

bool _openBundle(NavigatorState nav, BannerModel banner) {
  final bundle = banner.targetBundle;
  if (bundle == null) return false;
  nav.pushNamed(BundleDetailsPage.routeName, arguments: bundle);
  return true;
}

/// The web address a banner may open, or null when it must open nothing.
///
/// [Uri.parse] throws on a malformed value and the dashboard's url field is not
/// validated on the way in, so one bad row would crash the page on a tap. Only
/// a real http(s) address reaches the browser: a banner is not a way to make the
/// customer's phone open something else.
Uri? _webAddress(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final uri = Uri.tryParse(raw);
  if (uri == null) return null;
  return uri.scheme == 'http' || uri.scheme == 'https' ? uri : null;
}

/// Opens the banner's address in the browser, reporting whether it got there.
Future<bool> _openWebAddress(BannerModel banner) async {
  final uri = _webAddress(banner.targetUrl);
  if (uri == null) return false;
  try {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return true;
    }
  } catch (_) {
    // Nothing on screen depends on the browser having opened.
  }
  return false;
}
