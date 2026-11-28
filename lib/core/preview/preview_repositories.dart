import 'dart:typed_data';

import 'package:new_coffee/features/addresses/data/model/address_model.dart';
import 'package:new_coffee/features/addresses/data/repositories/address_repository.dart';
import 'package:new_coffee/features/auth/data/model/auth_exception.dart';
import 'package:new_coffee/features/auth/data/model/auth_user.dart';
import 'package:new_coffee/features/auth/data/repositories/auth_repository.dart';
import 'package:new_coffee/features/cart/data/model/cart_line.dart';
import 'package:new_coffee/features/cart/data/repositories/cart_repository.dart';
import 'package:new_coffee/features/branch/data/model/branch_model.dart';
import 'package:new_coffee/features/branch/data/repositories/branch_repository.dart';
import 'package:new_coffee/features/checkout/data/model/delivery_zone_model.dart';
import 'package:new_coffee/features/checkout/data/model/payment_method_model.dart';
import 'package:new_coffee/features/checkout/data/repositories/delivery_zone_repository.dart';
import 'package:new_coffee/features/checkout/data/repositories/payment_method_repository.dart';
import 'package:new_coffee/features/content/data/model/faq_model.dart';
import 'package:new_coffee/features/content/data/model/legal_document_model.dart';
import 'package:new_coffee/features/content/data/repositories/content_repository.dart';
import 'package:new_coffee/features/coupon/data/model/coupon_model.dart';
import 'package:new_coffee/features/coupon/data/repositories/coupon_repository.dart';
import 'package:new_coffee/features/design/data/design_preview_store.dart';
import 'package:new_coffee/features/design/data/model/published_design.dart';
import 'package:new_coffee/features/design/data/repositories/design_repository.dart';
import 'package:new_coffee/features/favorites/data/repositories/favorite_repository.dart';
import 'package:new_coffee/features/location/data/model/place_suggestion.dart';
import 'package:new_coffee/features/location/data/repositories/place_search_repository.dart';
import 'package:new_coffee/features/notifications/data/model/notification_model.dart';
import 'package:new_coffee/features/notifications/data/repositories/notification_repository.dart';
import 'package:new_coffee/features/payment/data/repositories/payment_repository.dart';
import 'package:new_coffee/features/profile/data/model/profile_photo_exception.dart';
import 'package:new_coffee/features/profile/data/repositories/profile_photo_repository.dart';
import 'package:new_coffee/features/weather/data/model/weather_model.dart';
import 'package:new_coffee/features/weather/data/repositories/weather_repository.dart';
import 'package:new_coffee/features/loyalty/data/repositories/loyalty_repository.dart';
import 'package:new_coffee/features/orders/data/repositories/order_repository.dart';
import 'package:new_coffee/features/subscriptions/data/model/customer_subscription.dart';
import 'package:new_coffee/features/subscriptions/data/model/subscription_plan.dart';
import 'package:new_coffee/features/subscriptions/data/model/subscription_plan_product.dart';
import 'package:new_coffee/features/subscriptions/data/model/subscription_usage.dart';
import 'package:new_coffee/features/subscriptions/data/repositories/subscription_repository.dart';

class PreviewLoyaltyRepository implements LoyaltyRepository {
  const PreviewLoyaltyRepository();
  @override
  Future<LoyaltyCatalog> loadCatalog() async => const LoyaltyCatalog();
  @override
  Future<LoyaltyWallet?> loadWallet() async => null;
  @override
  Future<int> redeemReward({
    required String rewardId,
    String? branchId,
  }) async => throw StateError('Loyalty redemption is disabled in preview.');
}

class PreviewDesignRepository implements DesignRepository {
  const PreviewDesignRepository();

  @override
  Future<PublishedDesign?> published({bool forceRefresh = false}) async =>
      PublishedDesign.fromJson(DesignPreviewStore.instance.document) ??
      PublishedDesign.none;

  @override
  Future<PublishedDesign?> lastKnown() async =>
      PublishedDesign.fromJson(DesignPreviewStore.instance.document);
}

class PreviewBranchRepository implements BranchRepository {
  const PreviewBranchRepository();
  @override
  Future<List<Branch>> activeBranches() async => const <Branch>[];
}

class PreviewCouponRepository implements CouponRepository {
  const PreviewCouponRepository();
  @override
  Future<List<CouponModel>> activeCoupons() async => const <CouponModel>[];
  @override
  Future<Map<String, CouponUsage>> usageForCustomer() async => const {};
  @override
  Future<Map<String, CouponScope>> scopeForCoupons(
    List<CouponModel> coupons,
  ) async => const {};
  @override
  Future<List<CouponLineDiscount>> lineBreakdown({
    required String code,
    required String branchId,
    required double subtotal,
    required List<PlaceOrderLine> lines,
  }) async => const [];
  @override
  Future<ValidatedCoupon> validate({
    required String code,
    required double subtotal,
    String? branchId,
  }) async => throw StateError('Coupon validation is disabled in preview.');
  @override
  Future<ValidatedCoupon> validateForCart({
    required String code,
    required double subtotal,
    required String branchId,
    required List<PlaceOrderLine> lines,
  }) async => throw StateError('Coupon validation is disabled in preview.');
}

class PreviewPaymentMethodRepository implements PaymentMethodRepository {
  const PreviewPaymentMethodRepository();
  @override
  Future<List<PaymentMethodModel>> activeMethods() async =>
      const <PaymentMethodModel>[];
}

class PreviewDeliveryZoneRepository implements DeliveryZoneRepository {
  const PreviewDeliveryZoneRepository();
  @override
  Future<List<DeliveryZone>> zonesForBranch(String branchId) async =>
      const <DeliveryZone>[];
  @override
  Future<List<DeliveryZone>> zonesForPoint({
    required String branchId,
    required double latitude,
    required double longitude,
  }) async => const <DeliveryZone>[];
}

class PreviewContentRepository implements ContentRepository {
  const PreviewContentRepository();
  @override
  Future<List<FaqModel>> faqs() async => const <FaqModel>[];
  @override
  Future<LegalDocumentModel?> legalDocument(String slug) async => null;
}

class PreviewSubscriptionRepository implements SubscriptionRepository {
  const PreviewSubscriptionRepository();
  StateError get _blocked =>
      StateError('Subscriptions are disabled in preview.');
  @override
  Future<List<SubscriptionPlan>> plans({String? branchId}) async => const [];
  @override
  Future<List<SubscriptionPlanProduct>> planProducts(String planId) async =>
      const [];
  @override
  Future<CustomerSubscription?> mySubscription() async => null;
  @override
  Future<List<CustomerSubscription>> mySubscriptions() async => const [];
  @override
  Future<CustomerSubscription> subscribe({
    required String planId,
    required String idempotencyKey,
  }) async => throw _blocked;
  @override
  Future<int> reserveForOrder({
    required String orderId,
    required String subscriptionId,
    required String branchId,
    required List<Map<String, dynamic>> lines,
    required String idempotencyKey,
  }) async => throw _blocked;
  @override
  Future<CustomerSubscription> renew({
    required String subscriptionId,
    required String paymentReference,
    required String idempotencyKey,
  }) async => throw _blocked;
  @override
  Future<void> setAutoRenew({
    required String subscriptionId,
    required bool enabled,
  }) async => throw _blocked;
  @override
  Future<void> cancel({required String subscriptionId}) async => throw _blocked;
  @override
  Future<List<SubscriptionUsage>> usageHistory({
    String? subscriptionId,
  }) async => const [];
  @override
  Future<String> generateQrToken({required String subscriptionId}) async =>
      throw _blocked;
  @override
  Future<int> consumeQr({
    required String token,
    required String branchId,
    required String productId,
    int quantity = 1,
    required String idempotencyKey,
  }) async => throw _blocked;
}

/// Explicit no-network dependencies used by the preview dependency scope.
/// Writes either stay in memory (cart) or fail closed with a preview error.
class PreviewAuthRepository implements AuthRepository {
  const PreviewAuthRepository();
  AuthException get _blocked => const AuthException('preview_auth_disabled');

  @override
  bool get lastSignUpNeedsEmailConfirmation => false;

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    // The editor's interactive preview must let the user explore screens
    // behind authentication. This identity exists only in memory; preview
    // mode never creates a Supabase session or records customer credentials.
    if (email.trim().isEmpty || password.isEmpty) {
      throw const AuthException('invalid_credentials');
    }
    return AuthUser(id: 'visual-editor-preview-user', email: email.trim());
  }

  @override
  Future<AuthUser> signUp({
    required String name,
    required String email,
    required String password,
  }) async => throw _blocked;
  @override
  Future<AuthUser> signInWithGoogle() async => throw _blocked;
  @override
  Future<AuthUser> signInWithFacebook() async => throw _blocked;
  @override
  Future<AuthUser> signInWithApple() async => throw _blocked;
  @override
  Future<void> sendPhoneCode({required String phone}) async => throw _blocked;
  @override
  Future<AuthUser> verifyPhoneCode({
    required String phone,
    required String code,
  }) async => throw _blocked;
  @override
  Future<void> sendEmailCode({required String email}) async => throw _blocked;
  @override
  Future<AuthUser> verifyEmailCode({
    required String email,
    required String code,
  }) async => throw _blocked;
  @override
  Future<void> sendPasswordResetEmail({required String email}) async =>
      throw _blocked;
  @override
  Future<void> resetPassword({required String newPassword}) async =>
      throw _blocked;
  @override
  Future<void> signOut() async => throw _blocked;
  @override
  Future<AuthUser?> currentUser() async => null;
  @override
  Future<AuthUser> updateProfile({
    required String fullName,
    String? phone,
  }) async => throw _blocked;
  @override
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async => throw _blocked;
}

class PreviewMemoryCartRepository implements CartRepository {
  List<CartLine> _lines = const <CartLine>[];
  @override
  Future<List<CartLine>?> fetchLines({String? branchId}) async =>
      List<CartLine>.unmodifiable(_lines);
  @override
  Future<void> saveLines({
    String? branchId,
    required List<CartLine> lines,
  }) async {
    _lines = List<CartLine>.of(lines);
  }
}

class PreviewMemoryFavoritesRepository implements FavoritesRepository {
  final Set<String> _ids = <String>{};
  @override
  Future<Set<String>> loadLocalIds() async => Set<String>.of(_ids);
  @override
  Future<Set<String>> loadRemoteIds() async => <String>{};
  @override
  Future<void> synchronize({
    required Set<String> localIds,
    required Set<String> remoteIds,
    required Set<String> validProductIds,
  }) async {}
  @override
  Future<void> addFavorite(String productId) async => _ids.add(productId);
  @override
  Future<void> removeFavorite(String productId) async => _ids.remove(productId);
  @override
  Future<void> migrateGuestIds() async {}
}

class PreviewAddressRepository implements AddressRepository {
  const PreviewAddressRepository();
  StateError get _blocked =>
      StateError('Address changes are disabled in preview.');
  @override
  Future<List<AddressModel>> listAddresses() async => const <AddressModel>[];
  @override
  Future<AddressModel> addAddress({
    required String label,
    required String details,
    double? latitude,
    double? longitude,
    bool isDefault = false,
  }) async => throw _blocked;
  @override
  Future<AddressModel> updateAddress({
    required String id,
    required String label,
    required String details,
    double? latitude,
    double? longitude,
  }) async => throw _blocked;
  @override
  Future<void> setDefaultAddress(String id) async => throw _blocked;
  @override
  Future<void> removeAddress(String id) async => throw _blocked;
}

class PreviewPaymentRepository implements PaymentRepository {
  const PreviewPaymentRepository();
  StateError get _blocked => StateError('Payments are disabled in preview.');
  @override
  Future<PaymentVerificationResult> verifyCharge(String chargeId) async =>
      throw _blocked;
}

class PreviewProfilePhotoRepository implements ProfilePhotoRepository {
  const PreviewProfilePhotoRepository();
  ProfilePhotoException get _blocked =>
      const ProfilePhotoException(ProfilePhotoFailure.notSignedIn);
  @override
  Future<String?> loadAvatarPath() async => null;
  @override
  Future<String> uploadAvatar(Uint8List bytes) async => throw _blocked;
  @override
  Future<Uint8List> downloadAvatar(String path) async => throw _blocked;
  @override
  Future<void> removeAvatar() async => throw _blocked;
}

class PreviewPlaceSearchRepository implements PlaceSearchRepository {
  const PreviewPlaceSearchRepository();
  @override
  Future<List<PlaceSuggestion>> search(String query, {int limit = 8}) async =>
      const <PlaceSuggestion>[];
  @override
  Future<PlaceSuggestion?> reverse({
    required double latitude,
    required double longitude,
  }) async => null;
}

class PreviewNotificationsRepository
    implements NotificationsRepository, BulkNotificationsReadRepository {
  const PreviewNotificationsRepository();
  @override
  Future<List<NotificationModel>> listNotifications({
    int limit = 50,
    int offset = 0,
  }) async => const <NotificationModel>[];
  @override
  Future<int> markRead(List<String> ids) async => 0;
  @override
  Future<int> markAllRead() async => 0;
  @override
  Future<int> deleteNotifications(List<String> ids) async => 0;
  @override
  Future<int> deleteAllNotifications() async => 0;
}

class PreviewWeatherRepository implements WeatherRepository {
  const PreviewWeatherRepository();
  @override
  Future<WeatherModel> getCurrentWeather() async =>
      const WeatherModel(temperature: 22, weatherCode: 1);
}
