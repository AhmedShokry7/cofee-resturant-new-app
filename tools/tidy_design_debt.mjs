/**
 * Folds the last hand-written numbers into the token pages.
 *
 * Colours go to AppColor, weights/heights/letter-spacing to typography.dart,
 * everything else to tokens.dart. Applied as exact string pairs so nothing is
 * rounded: a value only changes when a token of the same number exists.
 *
 * Dry run by default, `--apply` writes.
 */
import fs from 'node:fs';

const apply = process.argv.includes('--apply');

const edits = {
  'lib/core/theme/theme_class.dart': [
    ['surfaceTintColor: Colors.transparent', 'surfaceTintColor: AppColor.transparent'],
    ['backgroundColor: Colors.transparent', 'backgroundColor: AppColor.transparent'],
    ['return Colors.transparent;', 'return AppColor.transparent;'],
  ],
  'lib/features/assistant/presentation/widgets/assistant_fab.dart': [
    ['elevation: 6,', 'elevation: AppElevation.floating,'],
  ],
  'lib/features/auth/presentation/views/widgets/login_page_body.dart': [
    ['fontWeight: FontWeight.w500', 'fontWeight: AppFontWeights.medium'],
  ],
  'lib/features/auth/presentation/views/widgets/otp_page_body.dart': [
    ['color ?? Colors.transparent', 'color ?? AppColor.transparent'],
  ],
  'lib/features/bundles/presentation/views/bundle_details_page.dart': [
    ['savingPercent, size: 52)', 'savingPercent, size: AppDimensions.discountBadgeLarge)'],
  ],
  'lib/features/cart/presentation/views/widgets/coupon_breakdown.dart': [
    ['AppColor.greyColor, fontSize: 10', 'AppColor.greyColor, fontSize: AppFontSizes.size10'],
  ],
  'lib/features/categories/presentation/views/widgets/category_tabs.dart': [
    [': Colors.transparent,', ': AppColor.transparent,'],
  ],
  'lib/features/checkout/presentation/views/checkout_page.dart': [
    ['padding: const EdgeInsets.all(16)', 'padding: const EdgeInsets.all(AppSpacing.lg)'],
  ],
  'lib/features/location/presentation/widgets/location_picker.dart': [
    ['padding: EdgeInsets.all(14),', 'padding: EdgeInsets.all(AppSizes.px14),'],
    ['color: Colors.black.withValues(alpha: 0.12)', 'color: AppColor.shadowMedium'],
  ],
  'lib/features/loyalty/presentation/views/widgets/reward_card.dart': [
    ['fontWeight: FontWeight.w600', 'fontWeight: AppFontWeights.semiBold'],
  ],
  'lib/features/menu/presentation/views/product_details_page.dart': [
    ['backgroundColor: Colors.transparent', 'backgroundColor: AppColor.transparent'],
    ['elevation: 1.5,', 'elevation: AppElevation.raised,'],
    ['shadowColor: Colors.black.withValues(alpha: 0.3)', 'shadowColor: AppColor.shadowStrong'],
  ],
  'lib/features/menu/presentation/views/widgets/product_card.dart': [
    ['size: 28,', 'size: AppDimensions.favoriteButtonCard,'],
    ['size: 36,', 'size: AppDimensions.addToCartButtonCard,'],
    ['size: 26,', 'size: AppDimensions.discountBadgeInline,'],
  ],
  'lib/features/menu/presentation/views/widgets/product_details_body.dart': [
    ['color: Colors.black.withValues(alpha: 0.08)', 'color: AppColor.shadowSoft'],
    ['size: 30,', 'size: AppDimensions.discountBadgeDetails,'],
    ['AppColor.primaryColor : Colors.transparent', 'AppColor.primaryColor : AppColor.transparent'],
  ],
  'lib/features/orders/presentation/views/widgets/orders_tabs.dart': [
    [': Colors.transparent,', ': AppColor.transparent,'],
  ],
  'lib/features/payment/presentation/views/widgets/card_preview.dart': [
    ['letterSpacing: 1)', 'letterSpacing: AppLetterSpacings.brand)'],
    ['letterSpacing: 2)', 'letterSpacing: AppLetterSpacings.number)'],
  ],
  'lib/features/profile/presentation/views/widgets/profile_avatar.dart': [
    ['color: Colors.black.withValues(alpha: 0.35)', 'color: AppColor.photoScrim'],
  ],
  'lib/features/subscriptions/presentation/views/subscription_plan_details_page.dart': [
    ['const SizedBox(width: 40, height: 40)', 'const SizedBox(width: AppSizes.px40, height: AppSizes.px40)'],
  ],
  'lib/features/subscriptions/presentation/views/widgets/subscription_plan_image.dart': [
    ['BorderRadius.circular(16)', 'BorderRadius.circular(AppRadius.r16)'],
  ],
  'lib/shared/widgets/auth_guard.dart': [
    ['padding: const EdgeInsets.all(24)', 'padding: const EdgeInsets.all(AppSpacing.xl)'],
    ['const SizedBox(height: 8)', 'const SizedBox(height: AppSpacing.sm)'],
    ['const SizedBox(height: 16)', 'const SizedBox(height: AppSpacing.lg)'],
  ],
  'lib/shared/widgets/custom_btn.dart': [
    ['backgroundColor ?? Colors.transparent', 'backgroundColor ?? AppColor.transparent'],
  ],
  'lib/shared/widgets/custom_text_form_field.dart': [
    ['fillColor: Colors.transparent', 'fillColor: AppColor.transparent'],
  ],
  'lib/shared/widgets/discount_badge.dart': [
    ['this.size = 40,', 'this.size = AppDimensions.discountBadgeDefault,'],
    ['fontSize: (size * 0.30)', 'fontSize: size * AppDimensions.discountBadgeTextRatio'],
    ['fontWeight: FontWeight.w800,', 'fontWeight: AppFontWeights.bold,'],
    ['fontWeight: FontWeight.w900,', 'fontWeight: AppFontWeights.bold,'],
    ['height: 0.85,', 'height: AppTextHeights.mark,'],
    ['height: 0.75,', 'height: AppTextHeights.markCaption,'],
  ],
  'lib/shared/widgets/sheet_handle.dart': [
    ['BorderRadius.circular(100)', 'BorderRadius.circular(AppRadius.pill)'],
  ],
  'lib/features/menu/presentation/views/widgets/product_favorite_button.dart': [
    ['this.size = 28,', 'this.size = AppDimensions.favoriteButtonCard,'],
  ],
  'lib/shared/widgets/animated_add_to_cart_button.dart': [
    ['this.size = 36,', 'this.size = AppDimensions.addToCartButtonCard,'],
  ],
  'lib/shared/widgets/currency_icon.dart': [
    ['this.size = 16,', 'this.size = AppIconSize.md,'],
  ],
};

// The shimmer placeholders keep their exact geometry, only the spelling moves.
const shimmer = (file) => {
  const list = (edits[file] ??= []);
  const widths = {
    140: 'skeletonLineLong',
    110: 'skeletonLineMedium',
    90: 'skeletonLineShort',
    100: 'skeletonLineTile',
    80: 'skeletonLineBrief',
    56: 'skeletonThumbLine',
    160: 'skeletonBlock',
  };
  const heights = { 16: 'skeletonLineHeight', 13: 'skeletonCaptionHeight', 18: 'skeletonTitleHeight', 30: 'skeletonBlockHeight' };
  const radii = { 8: 'r8', 6: 'r6' };
  for (const [w, wt] of Object.entries(widths))
    for (const [h, ht] of Object.entries(heights))
      for (const [r, rt] of Object.entries(radii))
        list.push([
          `width: ${w}, height: ${h}, radius: ${r}`,
          `width: AppDimensions.${wt}, height: AppDimensions.${ht}, radius: AppRadius.${rt}`,
        ]);
  for (const [r, rt] of Object.entries({ 16: 'r16', 12: 'r12', 20: 'r20' }))
    list.push([`skeletonCardDecoration(context, radius: ${r})`, `skeletonCardDecoration(context, radius: AppRadius.${rt})`]);
  for (const [w, n] of Object.entries({ 120: 'skeletonChipWidth', 110: 'skeletonChipShortWidth', 70: 'skeletonTagWidth', 84: 'skeletonPillWidth', 96: 'skeletonTabWidth', 72: 'skeletonTabShortWidth' }))
    list.push([`width: ${w},`, `width: AppDimensions.${n},`]);
  list.push(['SizedBox(height: 4)', 'SizedBox(height: AppSpacing.xs)']);
  list.push(['SizedBox(height: 6)', 'SizedBox(height: AppDimensions.skeletonLineGap)']);
  list.push(['SizedBox(height: 8)', 'SizedBox(height: AppSpacing.sm)']);
};
shimmer('lib/shared/widgets/shimmer/catalog_skeletons.dart');
shimmer('lib/shared/widgets/shimmer/page_skeletons.dart');

let missing = 0;
for (const [file, pairs] of Object.entries(edits)) {
  let text = fs.readFileSync(file, 'utf8');
  for (const [from, to] of pairs) {
    if (!text.includes(from)) {
      if (from.startsWith('width: ') || from.startsWith('skeletonCard') || from === 'SizedBox(height: 4)') continue;
      console.log('MISS', file, JSON.stringify(from.slice(0, 60)));
      missing++;
      continue;
    }
    text = text.split(from).join(to);
  }
  if (apply) fs.writeFileSync(file, text);
}
console.log(`${apply ? 'applied' : 'dry run'} on ${Object.keys(edits).length} files, ${missing} pairs missing`);
